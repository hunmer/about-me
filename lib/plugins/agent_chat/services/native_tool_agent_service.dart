import 'dart:convert';
import 'dart:io';

import 'package:agentlib/openai_compat.dart' as compat;
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/services/agent_file_space_service.dart';
import 'package:aboutme/core/services/image_compression_service.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_service.dart';
import 'package:aboutme/plugins/openai/controllers/model_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';
import 'package:aboutme/plugins/openai/models/service_provider.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

/// 工具调用元数据（dispatcher 用）
class NativeToolMeta {
  const NativeToolMeta(this.pluginId, this.methods);
  final String pluginId;
  final Map<String, ToolConfig> methods;
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
  _NativeToolRunContext(
    this.onToolSteps,
    this.onImageDescription, {
    required this.agentId,
    required this.conversationId,
  });

  final String agentId;
  final String? conversationId;

  final Future<void> Function(List<ToolCallStep> steps)? onToolSteps;
  final Future<void> Function(String path, String description)?
  onImageDescription;
  late final Map<String, NativeToolMeta> toolMeta;
  final List<ToolCallStep> steps = [];
  Future<void> updateChain = Future<void>.value();
  int toolCallCount = 0;
  int imageToolCallCount = 0;

  Future<void> notifySteps() {
    final callback = onToolSteps;
    if (callback == null) return Future<void>.value();

    final snapshot = steps.map((step) => step.copyWith()).toList();
    final sw = Stopwatch()..start();
    final update = updateChain.then((_) async {
      try {
        await callback(snapshot);
        debugPrint(
          '[NativeTool] 步骤已上报 UI: ${snapshot.length}步 '
          '(${sw.elapsedMilliseconds}ms)',
        );
      } catch (e, stack) {
        debugPrint('[NativeTool] 工具步骤状态更新失败: $e\n$stack');
      }
    });
    updateChain = update;
    return update;
  }
}

/// 剥离模型重复输出的上一轮文本：多轮工具调用时部分模型（如 DeepSeek）
/// 每轮会把上一轮正文重新输出一遍（A → A+B → B+C），
/// 当前轮以上一轮文本开头时剥掉前缀，得到该轮新增内容。
String stripRepeatedPrefix(String current, String? previous) {
  final prev = previous?.trim();
  if (prev == null || prev.isEmpty || current.length <= prev.length) {
    return current;
  }
  return current.startsWith(prev)
      ? current.substring(prev.length).trim()
      : current;
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
    final hasNativeApiFormat = const {
      'openai',
      'anthropic',
    }.contains(agent.apiFormat.trim().toLowerCase());
    if (!hasNativeApiFormat) return false;
    return (enableToolCalling && agent.enableFunctionCalling) ||
        agent.alivenessConfig?.enabled == true;
  }

  Map<String, Map<String, ToolConfig>>? _toolConfigCache;
  Map<String, NativeToolMeta>? _toolMetaCache;
  bool _hasImageGenerationTool = false;

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
    void Function(List<String> texts)? onTurnTexts,
    Future<void> Function(String path, String description)? onImageDescription,
    bool Function()? isCancelling,
    String? conversationId,
    bool useJsTools = false,
    bool alivenessOnlyTools = false,
    bool imageOnlyTools = false,
  }) async {
    final run = _NativeToolRunContext(
      onToolSteps,
      onImageDescription,
      agentId: agent.id,
      conversationId: conversationId,
    );
    final (allTools, allMeta) = _buildTools(run, agent);
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
    if (alivenessOnlyTools) {
      tools = tools
          .where((tool) => tool.name == 'moments' || tool.name == 'read_image')
          .toList();
    }
    if (candidates != null && allTools.length > 30) {
      tools = allTools
          .where(
            (t) =>
                t.name == 'read_image' ||
                const {
                  'list_files',
                  'read_file',
                  'write_file',
                }.contains(t.name) ||
                (allMeta[t.name] != null &&
                    candidates.contains(allMeta[t.name]!.pluginId)),
          )
          .toList();
      debugPrint(
        '[NativeTool] 预筛：${allTools.length} → ${tools.length} 个工具 '
        '（候选插件：${candidates.join(',')}）',
      );
    }

    tools = buildToolSet(
      pluginTools: tools,
      onRunJs: (args) => _dispatchJs(run, args),
      useJsTools: alivenessOnlyTools ? false : useJsTools,
    );
    if (imageOnlyTools) {
      tools = tools.where((tool) => tool.name == 'read_image').toList();
    }
    debugPrint(
      '[NativeTool] 请求配置：agent=${agent.id} format=${agent.apiFormat} '
      'functionCalling=${agent.enableFunctionCalling} '
      'imageTool=${_hasImageGenerationTool ? 'available' : 'missing'} '
      'tools=${tools.map((tool) => tool.name).join(',')}',
    );

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
    final effectiveSystem = alivenessOnlyTools
        ? '$system\n\n[生图工具规则]\n'
              '当用户要求看你的照片、自拍、合照或某个场景的图片时，必须调用 moments.generate_image 并发送图片。'
              '用户提到的具体照片不在资产列表中，也不能因此拒绝：可以把用户描述写入 prompt，'
              '并按角色需要引用已有的「三视图」或其他资产做图生图；没有合适参考图时直接文生图。'
              '不要只回复“没有这张图”“无法生成”或解释自己是 AI。'
        : system;

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

    final history = _convertHistory(contextMessages, effectiveSystem);
    // 图片作为多模态附件（随 prompt 一起发送）
    // 图片不作为 DataPart 注入主会话，避免历史和当前请求携带 Base64。
    // 将路径提供给 read_image 工具，工具会在独立的多模态请求中解析。
    final imagePaths = files
        .where((f) => f.existsSync())
        .map((f) => f.path)
        .toList();
    final promptWithImages = imagePaths.isEmpty
        ? userInput
        : '$userInput\n[待解析图片路径]\n${imagePaths.join('\n')}';

    final output = StringBuffer();
    // 已完成轮的正文（剥除模型重复的前缀后）；content 只反映当前轮流式文本，
    // 避免多轮拼接成脏数据
    final turnTexts = <String>[];

    try {
      await for (final chunk in dartAgent.sendStream(
        promptWithImages,
        history: history,
      )) {
        if (isCancelling?.call() == true) {
          throw Exception('已取消发送');
        }
        // 调试：非文本增量的 chunk（toolCall/messages/done 等）全部打印，
        // 定位工具轮次与流结束事件是否到达
        final chunkType = chunk.runtimeType.toString();
        if (!chunkType.contains('TextDelta')) {
          debugPrint(
            '[NativeTool] chunk: $chunkType '
            'thinking=${chunk.thinking?.length ?? 0} '
            'output=${chunk.output.length} messages=${chunk.messages.length}',
          );
        }
        if (chunk.thinking != null && chunk.thinking!.isNotEmpty) {
          onThinking?.call(chunk.thinking!);
        }
        if (chunk.output.isNotEmpty) {
          output.write(chunk.output);
          onUpdateMessage(output.toString(), output.length);
        }
        // messages 事件 = 一轮结束（assistant/工具结果消息落地）；
        // 冻结当前轮正文，下一轮 output 重新累计
        if (chunk.messages.isNotEmpty && output.isNotEmpty) {
          final turnText = stripRepeatedPrefix(
            output.toString(),
            turnTexts.isEmpty ? null : turnTexts.last,
          );
          if (turnText.isNotEmpty) {
            turnTexts.add(turnText);
          }
          output.clear();
          onTurnTexts?.call(List.unmodifiable(turnTexts));
        }
      }

      // 流结束：剩余未冻结文本（末轮无 messages 收尾的兜底）也计入
      if (output.isNotEmpty) {
        final turnText = stripRepeatedPrefix(
          output.toString(),
          turnTexts.isEmpty ? null : turnTexts.last,
        );
        if (turnText.isNotEmpty) turnTexts.add(turnText);
      }
      // 最终回复 = 末轮正文（已剥重复前缀），覆盖写入 content
      if (turnTexts.isNotEmpty) {
        final finalReply = turnTexts.last;
        onUpdateMessage(finalReply, finalReply.length);
        onTurnTexts?.call(List.unmodifiable(turnTexts));
        debugPrint(
          '[NativeTool] ✅ 循环完成 | 最终回复=${finalReply.length}字 '
          '过程轮次=${turnTexts.length} 工具调用=${run.toolCallCount}次',
        );
        return finalReply;
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

  /// 普通模式保留 JS 作为补充；JS 模式只注册 run_js。
  static List<Tool<Map<String, dynamic>>> buildToolSet({
    required List<Tool<Map<String, dynamic>>> pluginTools,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>)
    onRunJs,
    bool useJsTools = false,
  }) {
    final apiDocs = pluginTools
        .map(
          (tool) =>
              '${tool.name}: ${tool.description}\n参数定义：${tool.inputSchema.toJson()}',
        )
        .join('\n\n');
    final jsTool = Tool<Map<String, dynamic>>(
      name: 'run_js',
      description:
          '${useJsTools ? '' : '优先使用插件工具；仅在需要脚本组合或插件工具无法满足时使用。'}'
          '文件操作必须直接调用 list_files、read_file 或 write_file，不要用 JavaScript 拼接文件操作。'
          '执行 JavaScript，可用 await Aboutme.plugins.<插件>.<方法>(参数对象) 调用 API。'
          '用 setResult(value); return value; 返回结果。\n$apiDocs',
      inputSchema: Schema.fromMap(
        ToolSchemaBuilder.buildSchemaMap([
          ToolParameter(
            name: 'code',
            type: 'string',
            description: '要执行的 JavaScript 代码',
          ),
        ]),
      ),
      onCall: onRunJs,
    );
    return [
      ...pluginTools.where((tool) => tool.name == 'read_image'),
      if (!useJsTools)
        ...pluginTools.where((tool) => tool.name != 'read_image'),
      jsTool,
    ];
  }

  (List<Tool<Map<String, dynamic>>>, Map<String, NativeToolMeta>) _buildTools(
    _NativeToolRunContext run,
    AIAgent imageAgent,
  ) {
    if (_toolConfigCache == null || _toolMetaCache == null) {
      final configs = <String, Map<String, ToolConfig>>{};
      final meta = <String, NativeToolMeta>{};
      for (final (toolId, pluginId, config)
          in ToolConfigManager.instance.getEnabledToolsWithPlugin()) {
        if (toolId.startsWith('system_')) continue;
        final methodName = toolId.startsWith('${pluginId}_')
            ? toolId.substring(pluginId.length + 1)
            : toolId;
        if (pluginId == 'openai' &&
            const {
              'list_files',
              'read_file',
              'write_file',
            }.contains(methodName)) {
          continue;
        }
        (configs[pluginId] ??= {})[methodName] = config;
      }
      for (final entry in configs.entries) {
        meta[entry.key] = NativeToolMeta(
          entry.key,
          Map.unmodifiable(entry.value),
        );
      }
      _toolConfigCache = configs;
      _toolMetaCache = meta;
      _hasImageGenerationTool =
          configs['moments']?.containsKey('generate_image') ?? false;
    }
    run.toolMeta = Map.unmodifiable(_toolMetaCache!);

    final tools = <Tool<Map<String, dynamic>>>[];
    for (final entry in _toolConfigCache!.entries) {
      final pluginId = entry.key;
      final methods = entry.value;
      final methodNames = methods.keys.toList()..sort();
      final argsProperties = <String, Object?>{};
      final description = methods.entries
          .map((e) {
            final parameters = e.value.parameters
                .map((p) => '${p.name}${p.optional ? '?' : ''}: ${p.type}')
                .join(', ');
            final schema = ToolSchemaBuilder.buildSchemaMap(e.value.parameters);
            final properties = schema['properties'];
            if (properties is Map) {
              for (final property in properties.entries) {
                final name = property.key.toString();
                final value = property.value is Map
                    ? Map<String, Object?>.from(property.value as Map)
                    : <String, Object?>{};
                final existing = argsProperties[name];
                if (existing is Map) {
                  final existingDescription = existing['description'] ?? '';
                  final methodDescription = value['description'] ?? '';
                  existing['description'] =
                      existingDescription == methodDescription
                      ? existingDescription
                      : '$existingDescription ($methodDescription)';
                } else {
                  argsProperties[name] = value;
                }
              }
            }
            return '${e.key}($parameters): '
                '${ToolSchemaBuilder.buildDescription(e.value)}';
          })
          .join('\n');
      tools.add(
        Tool<Map<String, dynamic>>(
          name: pluginId,
          description: '插件 $pluginId 可用方法：\n$description',
          inputSchema: Schema.fromMap(<String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'method': <String, Object?>{
                'type': 'string',
                'enum': methodNames,
                'description': '要调用的插件方法名',
              },
              'args': <String, Object?>{
                'type': 'object',
                'description': '该方法的参数对象；无参数时传空对象',
                'properties': argsProperties,
              },
            },
            'required': <String>['method', 'args'],
          }),
          onCall: (args) => _dispatch(run, pluginId, args),
        ),
      );
    }
    tools.add(
      Tool<Map<String, dynamic>>(
        name: 'read_image',
        description:
            '读取并描述一张或多张本地图片。传入当前消息提供的图片文件路径。'
            '返回的图片描述仅供你参考，请基于描述自行分析并回答用户问题，不要原样复述。',
        inputSchema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'paths': <String, Object?>{
              'type': 'array',
              'items': <String, Object?>{'type': 'string'},
              'description': '图片文件路径列表',
            },
            'question': <String, Object?>{
              'type': 'string',
              'description': '希望重点识别的内容',
            },
          },
          'required': <String>['paths'],
        }),
        onCall: (args) async {
          run.imageToolCallCount++;
          if (run.imageToolCallCount > maxToolCallsPerLoop) {
            return '图片解析调用次数已达上限';
          }
          final paths = (args['paths'] as List? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList();
          if (paths.isEmpty) return '没有提供图片路径';
          final argsJson = jsonEncode(args);
          debugPrint('[NativeTool] [read_image] 工具调用: $argsJson');
          final step = ToolCallStep(
            method: 'read_image',
            title: '读取图片',
            desc: '参数：$argsJson',
            data: argsJson,
            // 返回的是识图模型的 Markdown 文本描述，非 JSON
            resultFormat: 'markdown',
            status: ToolCallStatus.running,
          );
          run.steps.add(step);
          await run.notifySteps();
          try {
            final agent = await _resolveImageAgent(imageAgent);
            if (agent == null) {
              final message = '当前模型不支持图片识别，且尚未在 OpenAI 插件设置中配置识图模型';
              step
                ..status = ToolCallStatus.failed
                ..error = message;
              await run.notifySteps();
              return message;
            }
            final descriptions = <String>[];
            for (final path in paths) {
              final file = File(path);
              if (!await file.exists()) {
                descriptions.add('$path：文件不存在');
                continue;
              }
              final question = args['question']?.toString();
              final prompt = question == null || question.isEmpty
                  ? '请准确描述这张图片中的主要内容、文字和重要细节。'
                  : question;
              final description = await RequestService.chat(
                prompt,
                agent,
                imageFile: await _compressImageIfNeeded(file),
              );
              descriptions.add('$path：$description');
              debugPrint(
                '[NativeTool] [read_image] 单图解析完成: $path '
                '(${description.length}字符, 模型=${agent.model})',
              );
              await run.onImageDescription?.call(path, description);
              debugPrint('[NativeTool] [read_image] 描述已回写附件: $path');
            }
            final result = descriptions.join('\n');
            step
              ..status = ToolCallStatus.success
              ..result = result;
            await run.notifySteps();
            debugPrint('[NativeTool] [read_image] 工具返回 (${result.length}字符)');
            return result;
          } catch (e) {
            step
              ..status = ToolCallStatus.failed
              ..error = e.toString();
            await run.notifySteps();
            return '图片解析失败: $e';
          }
        },
      ),
    );
    tools.addAll(_buildFileTools(run));
    debugPrint('[NativeTool] 已构建 ${tools.length} 个原生工具');
    return (tools, _toolMetaCache!);
  }

  List<Tool<Map<String, dynamic>>> _buildFileTools(_NativeToolRunContext run) {
    final files = AgentFileSpaceService.instance;
    Future<Object?> executeFileTool(
      String method,
      String title,
      Map<String, dynamic> args,
      Future<Object?> Function() execute,
    ) async {
      if (++run.toolCallCount > maxToolCallsPerLoop) {
        return {'error': '工具调用次数已达上限，请直接回答'};
      }
      final argsJson = jsonEncode(args);
      final step = ToolCallStep(
        method: method,
        title: title,
        desc: '参数：$argsJson',
        data: argsJson,
        status: ToolCallStatus.running,
      );
      run.steps.add(step);
      await run.notifySteps();
      try {
        final result = await execute();
        step
          ..status = ToolCallStatus.success
          ..result = result is String ? result : jsonEncode(result);
        await run.notifySteps();
        return result;
      } catch (e) {
        step
          ..status = ToolCallStatus.failed
          ..error = e.toString();
        await run.notifySteps();
        return {'error': e.toString()};
      }
    }

    final autoSpace = <String, Object?>{
      'type': 'string',
      'enum': <String>['auto', 'agent', 'channel'],
      'description': '查询范围，auto 按 Agent 空间优先并最多查询两个空间',
    };
    return [
      Tool<Map<String, dynamic>>(
        name: 'list_files',
        description: '枚举当前 Agent 和频道文件，Agent 空间优先。',
        inputSchema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'path': <String, Object?>{
              'type': 'string',
              'description': '空间内相对目录，默认为根目录',
            },
            'recursive': <String, Object?>{
              'type': 'boolean',
              'description': '是否递归枚举子目录',
            },
            'space': autoSpace,
          },
          'required': <String>[],
        }),
        onCall: (args) => executeFileTool(
          'list_files',
          '枚举文件',
          args,
          () async => {
            'files': await files.listFiles(
              agentId: run.agentId,
              conversationId: run.conversationId,
              relativePath: args['path'] as String? ?? '',
              recursive: args['recursive'] == true,
              space: args['space'] as String? ?? 'auto',
            ),
          },
        ),
      ),
      Tool<Map<String, dynamic>>(
        name: 'read_file',
        description: '读取文本文件，默认按 Agent 空间优先查找。',
        inputSchema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'path': <String, Object?>{
              'type': 'string',
              'description': '空间内相对文件路径',
            },
            'space': autoSpace,
          },
          'required': <String>['path'],
        }),
        onCall: (args) => executeFileTool('read_file', '读取文件', args, () async {
          final filePath = args['path'] as String;
          final content = await files.readFile(
            relativePath: filePath,
            agentId: run.agentId,
            conversationId: run.conversationId,
            space: args['space'] as String? ?? 'auto',
          );
          return content == null
              ? {'error': '文件不存在: $filePath'}
              : {'path': filePath, 'content': content};
        }),
      ),
      Tool<Map<String, dynamic>>(
        name: 'write_file',
        description: '写入文本文件，默认写入 Agent 独立空间。',
        inputSchema: Schema.fromMap(<String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'path': <String, Object?>{
              'type': 'string',
              'description': '空间内相对文件路径',
            },
            'content': <String, Object?>{
              'type': 'string',
              'description': '要写入的文本内容',
            },
            'space': <String, Object?>{
              'type': 'string',
              'enum': <String>['agent', 'channel'],
              'description': '写入空间，默认 agent',
            },
          },
          'required': <String>['path', 'content'],
        }),
        onCall: (args) => executeFileTool(
          'write_file',
          '写入文件',
          args,
          () => files.writeFile(
            relativePath: args['path'] as String,
            content: args['content'] as String,
            agentId: run.agentId,
            conversationId: run.conversationId,
            space: args['space'] as String? ?? 'agent',
          ),
        ),
      ),
    ];
  }

  /// 解析「默认识图能力」agent（无会话上下文的场景直接调用，
  /// 如 bill 插件拍照识别账单）：以默认厂商的默认模型为基座，
  /// 走与 read_image 相同的识图模型解析链。
  /// 返回 null 表示无可用厂商或未配置识图模型
  static Future<AIAgent?> resolveDefaultImageAgent() async {
    final List<ServiceProvider> providers;
    try {
      providers = await ProviderController().getProviders();
    } catch (_) {
      return null;
    }
    if (providers.isEmpty) return null;
    final defaultId =
        OpenAIPlugin.instance.settings['defaultProviderId'] as String?;
    final provider = providers.firstWhere(
      (p) => p.id == defaultId,
      orElse: () => providers.first,
    );
    final base = AIAgent(
      id: 'default_image_base',
      name: '默认识图',
      description: '',
      tags: const [],
      serviceProviderId: provider.id,
      baseUrl: provider.baseUrl,
      headers: provider.headers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: provider.defaultModel ?? '',
      apiFormat: provider.apiFormat,
    );
    return _resolveImageAgent(base);
  }

  /// 解析识图请求使用的 agent：
  /// 1. 当前模型支持视觉输入 → 直接用当前模型；
  /// 2. 设置中配置了识图模型（multimodalModelConfig）→ 用独立连接配置；
  /// 3. 旧版仅模型名配置（defaultMultimodalModel）→ 复用当前连接仅换模型。
  /// 返回 null 表示当前模型不支持视觉且未配置识图模型
  static Future<AIAgent?> _resolveImageAgent(AIAgent imageAgent) async {
    final supportsVision = await ModelController().supportsVision(
      imageAgent.model,
    );
    debugPrint(
      '[NativeTool] [read_image] 识图模型解析: 当前模型=${imageAgent.model} '
      'supportsVision=$supportsVision',
    );
    if (supportsVision == true) {
      debugPrint('[NativeTool] [read_image] 使用当前模型直读');
      return imageAgent;
    }
    final settings = OpenAIPlugin.instance.settings;
    final config = settings['multimodalModelConfig'] as Map<String, dynamic>?;
    final model =
        (config?['model'] as String? ??
                settings['defaultMultimodalModel'] as String?)
            ?.trim();
    if (model == null || model.isEmpty) {
      debugPrint('[NativeTool] [read_image] 未配置识图模型');
      return null;
    }
    if (config != null && model == config['model']?.trim()) {
      debugPrint(
        '[NativeTool] [read_image] 使用独立识图配置: '
        'provider=${config['providerId']} model=$model '
        'format=${config['apiFormat']}',
      );
      return AIAgent(
        id: 'multimodal_reader',
        name: '识图模型',
        description: '',
        tags: const [],
        serviceProviderId:
            (config['providerId'] as String?) ?? imageAgent.serviceProviderId,
        baseUrl: (config['baseUrl'] as String?) ?? imageAgent.baseUrl,
        headers: config['headers'] is Map
            ? Map<String, String>.from(config['headers'] as Map)
            : imageAgent.headers,
        createdAt: imageAgent.createdAt,
        updatedAt: DateTime.now(),
        model: model,
        apiFormat: (config['apiFormat'] as String?) ?? 'openai',
      );
    }
    debugPrint('[NativeTool] [read_image] 兼容旧配置: 仅替换模型为 $model');
    return imageAgent.copyWith(model: model);
  }

  /// 超过 3MB 的图片先压缩（多模态接口通常限制请求体大小），
  /// 压缩失败时回退原图
  static Future<File> _compressImageIfNeeded(File file) async {
    const maxBytes = 3 * 1024 * 1024;
    if (await file.length() <= maxBytes) return file;
    try {
      final name = file.uri.pathSegments.isEmpty
          ? 'image.jpg'
          : file.uri.pathSegments.last;
      final dir = await Directory.systemTemp.createTemp('read_image');
      final compressed = await ImageCompressionService().compressImage(
        sourcePath: file.path,
        targetPath: '${dir.path}/$name',
        quality: 80,
      );
      debugPrint(
        '[NativeTool] 大图已压缩: ${await file.length()} → '
        '${await File(compressed).length()} bytes',
      );
      return File(compressed);
    } catch (e) {
      debugPrint('[NativeTool] 图片压缩失败，使用原图: $e');
      return file;
    }
  }

  /// 缓存失效（工具配置变更时调用）
  void invalidateCache() {
    _toolConfigCache = null;
    _toolMetaCache = null;
    _hasImageGenerationTool = false;
  }

  // ---------- 执行分发 ----------

  /// 插件 Tool 直接调用注册的 Dart 接口，结果回传 LLM。
  Future<Map<String, dynamic>> _dispatch(
    _NativeToolRunContext run,
    String pluginId,
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

    final meta = run.toolMeta[pluginId];
    if (meta == null) return {'error': 'Plugin $pluginId not found'};
    final methodName = args['method'];
    if (methodName is! String || methodName.isEmpty) {
      return {'error': '参数 method 必须是非空字符串'};
    }
    final config = meta.methods[methodName];
    if (config == null) {
      return {
        'error': '插件 $pluginId 不支持方法 $methodName',
        'availableMethods': meta.methods.keys.toList(),
      };
    }
    final rawArgs = args['args'];
    if (rawArgs is! Map<String, dynamic>) {
      return {'error': 'args 必须是对象，无参数时传 {}'};
    }
    final methodArgs = rawArgs;
    if (pluginId == 'openai' &&
        const {'list_files', 'read_file', 'write_file'}.contains(methodName)) {
      methodArgs.putIfAbsent('agentId', () => run.agentId);
      if (run.conversationId != null) {
        methodArgs.putIfAbsent('conversationId', () => run.conversationId);
      }
    }
    final missing = config.parameters
        .where((p) => !p.optional && !methodArgs.containsKey(p.name))
        .map((p) => p.name)
        .toList();
    if (missing.isNotEmpty) return {'error': '缺少必填参数：${missing.join(', ')}'};

    final argsJson = jsonEncode(methodArgs);

    final step = ToolCallStep(
      method: 'plugin_tool',
      title: config.title,
      desc: '参数：$argsJson',
      data: jsonEncode({
        'pluginId': pluginId,
        'method': methodName,
        'args': methodArgs,
      }),
      status: ToolCallStatus.running,
    );
    run.steps.add(step);
    await run.notifySteps();
    debugPrint(
      '[NativeTool] ▶ #${run.toolCallCount} ${config.title} | $argsJson',
    );

    try {
      final rawResult = await JSBridgeManager.instance.pluginTools.invoke(
        pluginId,
        methodName,
        methodArgs,
      );
      final result = rawResult is String ? rawResult : jsonEncode(rawResult);
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
      debugPrint('[NativeTool] ✗ ${config.title} 失败: $e');
      // 异常以 error 形式回传，模型可自行调整参数重试
      return {'error': e.toString()};
    }
  }

  // ---------- 转换工具 ----------

  Future<Map<String, dynamic>> _dispatchJs(
    _NativeToolRunContext run,
    Map<String, dynamic> args,
  ) async {
    if (++run.toolCallCount > maxToolCallsPerLoop) {
      return {'error': '工具调用次数已达上限，请直接回答'};
    }
    final code = args['code'];
    if (code is! String || code.trim().isEmpty) {
      return {'error': 'code 必须是非空字符串'};
    }
    final step = ToolCallStep(
      method: 'run_js',
      title: '执行 JS API',
      desc: '执行 JavaScript',
      data: code,
      status: ToolCallStatus.running,
    );
    run.steps.add(step);
    await run.notifySteps();
    try {
      final result = await ToolService.executeJsCode(code);
      step
        ..status = ToolCallStatus.success
        ..result = result;
      await run.notifySteps();
      final decoded = _tryDecodeJson(result);
      return decoded is Map<String, dynamic>
          ? decoded
          : {'result': decoded ?? result};
    } catch (e) {
      step
        ..status = ToolCallStatus.failed
        ..error = e.toString();
      await run.notifySteps();
      return {'error': e.toString()};
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
              parts.add(TextPart('[历史图片已省略；请使用其保存的文字描述]'));
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
