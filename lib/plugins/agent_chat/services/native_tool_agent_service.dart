import 'dart:convert';
import 'dart:io';

import 'package:agentlib/openai_compat.dart' as compat;
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

/// 工具调用元数据（dispatcher 用）
class NativeToolMeta {
  const NativeToolMeta(this.pluginId, this.methodName, this.title);
  final String pluginId;
  final String methodName;
  final String title;
}

/// 标准工具调用发起后发生错误，调用方不得再回退重放旧流程。
class NativeToolExecutionException implements Exception {
  const NativeToolExecutionException({
    required this.cause,
    required this.toolCallsStarted,
  });

  final Object cause;
  final int toolCallsStarted;

  @override
  String toString() => cause.toString();
}

class _NativeToolRunContext {
  _NativeToolRunContext(this.onToolSteps);

  final Future<void> Function(List<ToolCallStep> steps)? onToolSteps;
  late final Map<String, NativeToolMeta> toolMeta;
  final List<ToolCallStep> steps = [];
  Future<void> updateChain = Future<void>.value();
  int toolCallCount = 0;

  Future<void> notifySteps() {
    final callback = onToolSteps;
    if (callback == null) return Future<void>.value();

    final snapshot = steps.map((step) => step.copyWith()).toList();
    final update = updateChain.then((_) async {
      try {
        await callback(snapshot);
      } catch (e, stack) {
        debugPrint('[NativeTool] 工具步骤状态更新失败: $e\n$stack');
      }
    });
    updateChain = update;
    return update;
  }
}

/// DeepSeek thinking 模型兼容：请求体注入 `thinking: {"type": "disabled"}`。
///
/// DeepSeek 思考模型的多轮工具调用要求把 reasoning_content 传回，
/// dartantic 不回传会 400；FC 工具场景无需 reasoning，直接关闭思考模式
/// （还省 token）。仅对 DeepSeek 域名生效，其他端点透传不注入。
class DeepSeekCompatClient extends http.BaseClient {
  DeepSeekCompatClient(this._inner, {required this.disableThinking});

  final http.Client _inner;
  final bool disableThinking;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!disableThinking ||
        request is! http.Request ||
        request.method != 'POST' ||
        !request.url.path.contains('chat/completions')) {
      return _inner.send(request);
    }
    try {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (!body.containsKey('thinking') && !body.containsKey('reasoning')) {
        body['thinking'] = {'type': 'disabled'};
        final patched = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..body = jsonEncode(body);
        return await _inner.send(patched);
      }
    } catch (_) {}
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// OpenAI Provider 子类：为 ChatModel 注入 [DeepSeekCompatClient]。
///
/// dartantic 的 Provider 未暴露 httpClient，重写 createChatModel 补传。
class AppOpenAIProvider extends OpenAIProvider {
  AppOpenAIProvider({
    required String apiKey,
    required Uri baseUrl,
    super.headers = const {},
  }) : _disableThinking = baseUrl.host.contains('deepseek'),
       super(apiKey: apiKey, baseUrl: baseUrl);

  final bool _disableThinking;

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OpenAIChatOptions? options,
  }) {
    if (_disableThinking) {
      debugPrint('[NativeTool] DeepSeek 兼容：关闭 thinking 模式');
    }
    return OpenAIChatModel(
      name: name ?? defaultModelNames[ModelKind.chat]!,
      tools: tools,
      temperature: temperature,
      apiKey: apiKey,
      baseUrl: baseUrl,
      headers: headers,
      client: DeepSeekCompatClient(
        http.Client(),
        disableThinking: _disableThinking,
      ),
      defaultOptions: OpenAIChatOptions(
        temperature: temperature ?? options?.temperature,
        streamOptions:
            options?.streamOptions ?? const StreamOptions(includeUsage: true),
      ),
    );
  }
}

/// 原生 function calling 工具服务（dartantic_ai）
///
/// 替代旧「两阶段 prompt 编排」：工具 schema 由 SDK 注入请求，
/// 模型直接返回结构化 tool call（无需写 JS），工具循环（调用→执行→回传→
/// 继续生成，多轮）由 dartantic 内部完成。执行层复用 QuickJS
/// （ToolService.executeJsCode），UI 沿用 ToolCallStep 数据结构。
///
/// 每次工具循环的步骤、计数与回调都绑定到独立执行上下文，支持不同会话并行请求。
class NativeToolAgentService {
  NativeToolAgentService._();

  static final NativeToolAgentService instance = NativeToolAgentService._();

  bool supports(AIAgent agent, bool enableToolCalling) {
    if (!enableToolCalling || !agent.enableFunctionCalling) return false;
    return true;
  }

  List<(String, ToolConfig)>? _toolConfigCache;
  Map<String, NativeToolMeta>? _toolMetaCache;

  /// 单次循环工具调用上限：防止模型陷入无限调用
  static const maxToolCallsPerLoop = 12;

  /// 预筛时始终注入的插件（模糊请求也不丢失生图/记忆等核心能力）
  static const _alwaysIncludePlugins = {'moments', 'openai', 'memory'};

  /// 按用户消息匹配候选插件（别名关键词包含匹配）
  ///
  /// 返回 null 表示无任何匹配（全量注入保底）；命中时返回
  /// 候选插件集 ∪ 常驻插件集，用于压缩 FC 注入的 schema token
  static Set<String>? matchPluginCandidates(String userText) {
    if (userText.trim().isEmpty) return null;
    final matched = <String>{};
    ToolConfigManager.getPluginAliases().forEach((pluginId, keywords) {
      for (final kw in keywords) {
        if (userText.contains(kw)) {
          matched.add(pluginId);
          break;
        }
      }
    });
    if (matched.isEmpty) return null;
    return {...matched, ..._alwaysIncludePlugins};
  }

  /// 运行原生 FC 工具循环，返回最终文本
  ///
  /// [systemPrompt] agent 的有效 system prompt；contextMessages 里的
  /// system 消息（活人感后缀等）会合并为首条 system 消息。
  /// [contextMessages] 上下文消息（agentlib 格式，最后一条为本轮 user 输入）
  /// [onToolSteps] 工具状态变化时回传全量步骤（写入 message.toolCall）
  Future<String> runToolLoop({
    required AIAgent agent,
    required String systemPrompt,
    required List<compat.ChatCompletionMessage> contextMessages,
    List<File> files = const [],
    required Function(String content, int count) onUpdateMessage,
    Future<void> Function(List<ToolCallStep> steps)? onToolSteps,
    Function(String thinking)? onThinking,
    bool Function()? isCancelling,
    String? conversationId,
  }) async {
    final run = _NativeToolRunContext(onToolSteps);
    final (allTools, allMeta) = _buildTools(run);
    if (allTools.isEmpty) {
      throw StateError('标准工具集为空（ToolConfigManager 未初始化或没有启用的工具）');
    }
    // 生图等工具依赖会话上下文
    MomentsService.instance.currentAgentId = agent.id;
    if (conversationId != null) {
      MomentsService.instance.currentConversationId = conversationId;
    }

    // 工具预筛：按本轮用户输入匹配候选插件，无匹配时全量注入保底
    final userInput = _extractLastUserText(contextMessages);
    final candidates = matchPluginCandidates(userInput);
    var tools = allTools;
    if (candidates != null && allTools.length > 30) {
      tools = allTools
          .where((t) => candidates.contains(allMeta[t.name]!.pluginId))
          .toList();
      debugPrint(
        '[NativeTool] 预筛：${allTools.length} → ${tools.length} 个工具 '
        '（候选插件：${candidates.join(',')}）',
      );
    }

    // contextMessages 中的 system 消息（活人感后缀等）拼接到 system prompt
    final systemExtras = contextMessages
        .where((m) => m.role == compat.ChatCompletionMessageRole.system)
        .map((m) => m.content is String ? m.content as String : '')
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');
    // 原生 tools 已由 Agent 构造函数注入；旧 prompt 占位符不能泄漏到模型。
    String withoutLegacyToolPlaceholders(String value) => value
        .replaceAll('{agent_prompt}', '')
        .replaceAll('{tool_templates}', '')
        .replaceAll('{tool_brief}', '')
        .replaceAll('{tool_detail}', '')
        .trim();

    final cleanSystemPrompt = withoutLegacyToolPlaceholders(systemPrompt);
    final cleanSystemExtras = withoutLegacyToolPlaceholders(systemExtras);
    final system = cleanSystemExtras.isEmpty
        ? cleanSystemPrompt
        : '$cleanSystemPrompt\n\n$cleanSystemExtras';

    final isAnthropic = agent.apiFormat.toLowerCase() == 'anthropic';
    final Agent dartAgent;
    if (isAnthropic) {
      dartAgent = Agent.forProvider(
        AnthropicProvider(
          apiKey: _extractApiKey(agent),
          baseUrl: _normalizeAnthropicBaseUrl(agent.baseUrl),
          headers: agent.headers,
        ),
        chatModelName: agent.model,
        tools: tools,
        temperature: agent.temperature,
        chatModelOptions: AnthropicChatOptions(
          maxTokens: agent.maxLength > 0 ? agent.maxLength : 4096,
          temperature: agent.temperature > 0 ? agent.temperature : null,
          topP: agent.topP > 0 ? agent.topP : null,
          stopSequences: agent.stop,
        ),
      );
    } else {
      final configuredBaseUrl = _normalizeBaseUrl(agent.baseUrl);
      final baseUrl =
          configuredBaseUrl ?? Uri.parse('https://api.openai.com/v1');
      final provider = baseUrl.host.contains('deepseek')
          ? AppOpenAIProvider(
              apiKey: _extractApiKey(agent),
              baseUrl: baseUrl,
              headers: agent.headers,
            )
          : OpenAIProvider(
              apiKey: _extractApiKey(agent),
              baseUrl: baseUrl,
              headers: agent.headers,
            );
      dartAgent = Agent.forProvider(
        provider,
        chatModelName: agent.model,
        tools: tools,
        temperature: agent.temperature,
      );
    }

    final history = _convertHistory(contextMessages, system);
    // 图片作为多模态附件（随 prompt 一起发送）
    final attachments = <DataPart>[];
    for (final f in files) {
      if (!f.existsSync()) continue;
      final bytes = f.readAsBytesSync();
      final mime = f.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      attachments.add(
        DataPart(bytes, mimeType: mime, name: f.path.split('/').last),
      );
    }

    final output = StringBuffer();

    try {
      await for (final chunk in dartAgent.sendStream(
        userInput,
        history: history,
        attachments: attachments,
      )) {
        if (isCancelling?.call() == true) {
          throw Exception('已取消发送');
        }
        if (chunk.thinking != null && chunk.thinking!.isNotEmpty) {
          onThinking?.call(chunk.thinking!);
        }
        if (chunk.output.isNotEmpty) {
          output.write(chunk.output);
          onUpdateMessage(output.toString(), output.length);
        }
      }
      debugPrint(
        '[NativeTool] ✅ 循环完成 | 输出=${output.length}字 '
        '工具调用=${run.toolCallCount}次',
      );
      return output.toString();
    } catch (e, stack) {
      if (run.toolCallCount > 0 && !e.toString().contains('已取消发送')) {
        throw NativeToolExecutionException(
          cause: e,
          toolCallsStarted: run.toolCallCount,
        );
      }
      Error.throwWithStackTrace(e, stack);
    }
  }

  // ---------- 工具集构建 ----------

  (List<Tool<Map<String, dynamic>>>, Map<String, NativeToolMeta>) _buildTools(
    _NativeToolRunContext run,
  ) {
    if (_toolConfigCache == null || _toolMetaCache == null) {
      final configs = <(String, ToolConfig)>[];
      final meta = <String, NativeToolMeta>{};
      for (final (toolId, pluginId, config)
          in ToolConfigManager.instance.getEnabledToolsWithPlugin()) {
        if (toolId.startsWith('system_')) continue;
        final methodName = toolId.startsWith('${pluginId}_')
            ? toolId.substring(pluginId.length + 1)
            : toolId;
        configs.add((toolId, config));
        meta[toolId] = NativeToolMeta(pluginId, methodName, config.title);
      }
      _toolConfigCache = configs;
      _toolMetaCache = meta;
    }
    run.toolMeta = Map.unmodifiable(_toolMetaCache!);

    final tools = <Tool<Map<String, dynamic>>>[];
    for (final (toolId, config) in _toolConfigCache!) {
      tools.add(
        Tool<Map<String, dynamic>>(
          name: toolId,
          description: ToolSchemaBuilder.buildDescription(config),
          inputSchema: Schema.fromMap(
            ToolSchemaBuilder.buildSchemaMap(config.parameters),
          ),
          onCall: (args) => _dispatch(run, toolId, args),
        ),
      );
    }
    debugPrint('[NativeTool] 已构建 ${tools.length} 个原生工具');
    return (tools, _toolMetaCache!);
  }

  /// 缓存失效（工具配置变更时调用）
  void invalidateCache() {
    _toolConfigCache = null;
    _toolMetaCache = null;
  }

  // ---------- 执行分发 ----------

  /// 工具调用回调：生成 JS 调用代码 → QuickJS 执行 → 结果回传 LLM
  Future<Map<String, dynamic>> _dispatch(
    _NativeToolRunContext run,
    String toolId,
    Map<String, dynamic> args,
  ) async {
    // 轮数上限保护：超限后向模型返回错误提示，促使其收敛直接作答
    run.toolCallCount++;
    if (run.toolCallCount > maxToolCallsPerLoop) {
      debugPrint('[NativeTool] ⚠️ 达到调用上限（$maxToolCallsPerLoop 次）');
      return {
        'error':
            '工具调用次数已达上限（$maxToolCallsPerLoop 次），'
            '请基于已有结果直接回答用户，不要再调用工具',
      };
    }

    final meta = run.toolMeta[toolId];
    if (meta == null) return {'error': 'Tool $toolId not found'};

    final argsJson = jsonEncode(args);

    // 工具描述文件的 pluginId 可能与 JS API 实际注册插件不一致
    // （moments/memory 的方法挂在 openai 命名空间），运行时解析真实路由；
    // 解析异常（如热重载后注册表为 null）降级回原插件，不中断 FC 循环
    final resolved = _resolveRoute(meta);

    final js =
        'const r = await Aboutme.plugins.${resolved.$1}.'
        '${resolved.$2}($argsJson);\nsetResult(r);\nreturn r;';

    final step = ToolCallStep(
      method: 'run_js',
      title: meta.title,
      desc: '参数：$argsJson',
      data: js,
      status: ToolCallStatus.running,
    );
    run.steps.add(step);
    await run.notifySteps();
    debugPrint(
      '[NativeTool] ▶ #${run.toolCallCount} ${meta.title} | $argsJson',
    );

    try {
      final result = await ToolService.executeJsCode(js);
      step
        ..status = ToolCallStatus.success
        ..result = result;
      await run.notifySteps();
      // 结果回传 LLM：JSON 字符串解析后原样传，其余包 result 字段
      final decoded = _tryDecodeJson(result);
      return (decoded is Map<String, dynamic>)
          ? decoded
          : (decoded is List ? {'result': decoded} : {'result': result});
    } catch (e) {
      step
        ..status = ToolCallStatus.failed
        ..error = e.toString();
      await run.notifySteps();
      debugPrint('[NativeTool] ✗ ${meta.title} 失败: $e');
      // 异常以 error 形式回传，模型可自行调整参数重试
      return {'error': e.toString()};
    }
  }

  // ---------- 转换工具 ----------

  /// 解析工具的 JS 调用路由（异常时回退原插件）
  (String, String) _resolveRoute(NativeToolMeta meta) {
    try {
      return JSBridgeManager.instance.resolvePluginApi(
            meta.pluginId,
            meta.methodName,
          ) ??
          (meta.pluginId, meta.methodName);
    } catch (e) {
      debugPrint('[NativeTool] 路由解析失败，回退原插件: $e');
      return (meta.pluginId, meta.methodName);
    }
  }

  dynamic _tryDecodeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// agentlib 消息 → dartantic ChatMessage（system 置于首条）
  List<ChatMessage> _convertHistory(
    List<compat.ChatCompletionMessage> messages,
    String systemPrompt,
  ) {
    final result = <ChatMessage>[
      if (systemPrompt.trim().isNotEmpty)
        ChatMessage(
          role: ChatMessageRole.system,
          parts: [TextPart(systemPrompt)],
        ),
    ];
    // Agent.sendStream 会把 prompt 追加为新的 user message；上下文中最后
    // 一个 user 已经是本轮 prompt 时不能再次放入 history，否则会重复提问。
    var lastUserIndex = -1;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == compat.ChatCompletionMessageRole.system) {
        continue;
      }
      if (messages[i].role == compat.ChatCompletionMessageRole.user) {
        lastUserIndex = i;
      }
      break;
    }

    for (var i = 0; i < messages.length; i++) {
      if (i == lastUserIndex) continue;
      final m = messages[i];
      final role = switch (m.role) {
        compat.ChatCompletionMessageRole.user => ChatMessageRole.user,
        compat.ChatCompletionMessageRole.assistant => ChatMessageRole.model,
        _ => ChatMessageRole.system,
      };
      if (role == ChatMessageRole.system) continue; // 已合并为首条

      final content = m.content;
      if (content is compat.StringContent) {
        if (content.value.trim().isNotEmpty) {
          result.add(ChatMessage(role: role, parts: [TextPart(content.value)]));
        }
      } else if (content is compat.PartsContent) {
        final parts = <Part>[];
        for (final p in content.value) {
          if (p.kind == 'text' && p.text.trim().isNotEmpty) {
            parts.add(TextPart(p.text));
          } else if (p.kind == 'image_url') {
            final url = p.imageUrl.url;
            if (url.startsWith('data:image/')) {
              final comma = url.indexOf(',');
              parts.add(
                DataPart(
                  base64Decode(url.substring(comma + 1)),
                  mimeType: url.substring(5, url.indexOf(';')),
                ),
              );
            }
          }
        }
        if (parts.isNotEmpty) {
          result.add(ChatMessage(role: role, parts: parts));
        }
      } else if (content is String && content.trim().isNotEmpty) {
        result.add(ChatMessage(role: role, parts: [TextPart(content)]));
      }
    }
    return result;
  }

  String _extractLastUserText(List<compat.ChatCompletionMessage> messages) {
    for (final m in messages.reversed) {
      if (m.role != compat.ChatCompletionMessageRole.user) continue;
      final c = m.content;
      if (c is compat.StringContent) return c.value;
      if (c is compat.PartsContent) {
        final text = c.value
            .where((p) => p.kind == 'text')
            .map((p) => p.text)
            .join('\n');
        if (text.trim().isNotEmpty) return text;
      }
      if (c is String) return c;
    }
    return '';
  }

  String _extractApiKey(AIAgent agent) {
    final headers = {
      for (final entry in agent.headers.entries)
        entry.key.toLowerCase(): entry.value.trim(),
    };
    final authorization = headers['authorization'] ?? '';
    final bearer = RegExp(
      r'^Bearer\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(authorization);
    if (bearer != null) return bearer.group(1)!.trim();

    for (final name in ['x-api-key', 'api-key']) {
      final value = headers[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  Uri? _normalizeBaseUrl(String baseUrl) {
    var s = baseUrl.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'/+$'), '');
    // agentlib 兼容过全路径 baseUrl，openai_dart 期望 base（到 /v1 级）
    if (s.endsWith('/chat/completions')) {
      s = s.substring(0, s.length - '/chat/completions'.length);
    }
    return Uri.tryParse(s);
  }

  /// Anthropic SDK appends `/v1/...` to its configured base URL.
  Uri? _normalizeAnthropicBaseUrl(String baseUrl) {
    final value = baseUrl.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw FormatException('无效的 Anthropic baseUrl: $baseUrl');
    }
    return uri;
  }
}
