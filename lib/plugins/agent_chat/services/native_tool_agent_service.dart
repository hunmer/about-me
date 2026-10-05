import 'dart:convert';
import 'dart:io';

import 'package:agentlib/openai_compat.dart' as compat;
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:json_schema/json_schema.dart';

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

/// 原生 function calling 工具服务（dartantic_ai）
///
/// 替代旧「两阶段 prompt 编排」：工具 schema 由 SDK 注入请求，
/// 模型直接返回结构化 tool call（无需写 JS），工具循环（调用→执行→回传→
/// 继续生成，多轮）由 dartantic 内部完成。执行层复用 QuickJS
/// （ToolService.executeJsCode），UI 沿用 ToolCallStep 数据结构。
///
/// 注意：单会话串行使用（ChatController._isSending 互斥保证），
/// 工具进度回调是实例级临时状态，结束后清理。
class NativeToolAgentService {
  NativeToolAgentService._();

  static final NativeToolAgentService instance = NativeToolAgentService._();

  /// 是否走原生 FC 路径（openai 兼容格式 + 工具调用开启）
  bool supports(AIAgent agent, bool enableToolCalling) =>
      enableToolCalling &&
      agent.enableFunctionCalling &&
      agent.apiFormat != 'anthropic';

  List<Tool>? _toolsCache;
  Map<String, NativeToolMeta>? _toolMetaCache;

  /// 当前循环的工具步骤进度（写 message.toolCall 用）
  List<ToolCallStep>? _activeSteps;
  Function(List<ToolCallStep> steps)? _activeOnToolSteps;

  /// 当前循环已执行的工具调用次数（轮数上限保护）
  int _activeToolCallCount = 0;

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
  /// system 消息（活人感后缀等）会追加在其后
  /// [contextMessages] 上下文消息（agentlib 格式，最后一条为本轮 user 输入）
  /// [onToolSteps] 工具状态变化时回传全量步骤（写入 message.toolCall）
  Future<String> runToolLoop({
    required AIAgent agent,
    required String systemPrompt,
    required List<compat.ChatCompletionMessage> contextMessages,
    List<File> files = const [],
    required Function(String content, int count) onUpdateMessage,
    Function(List<ToolCallStep> steps)? onToolSteps,
    bool Function()? isCancelling,
    String? conversationId,
  }) async {
    final (allTools, allMeta) = _buildTools();
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

    final dartAgent = Agent(
      'openai:${agent.model}',
      apiKey: _extractApiKey(agent),
      baseUrl: _normalizeBaseUrl(agent.baseUrl),
      systemPrompt: systemExtras.isEmpty
          ? systemPrompt
          : '$systemPrompt\n\n$systemExtras',
      tools: tools,
      temperature: agent.temperature,
    );

    final history = _convertHistory(contextMessages);
    // 图片作为多模态 part 附加在最后一条消息上
    if (files.isNotEmpty) {
      final mediaParts = <MediaPart>[];
      for (final f in files) {
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final mime = f.path.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        mediaParts.add(
          MediaPart(
            contentType: mime,
            url: 'data:$mime;base64,${base64Encode(bytes)}',
          ),
        );
      }
      if (mediaParts.isNotEmpty && history.isNotEmpty) {
        final last = history.removeLast();
        history.add(
          Message(role: last.role, content: [...last.content, ...mediaParts]),
        );
      }
    }

    _activeSteps = [];
    _activeOnToolSteps = onToolSteps;
    _activeToolCallCount = 0;
    final output = StringBuffer();

    try {
      await for (final chunk in dartAgent.runStream(
        userInput,
        messages: history,
      )) {
        if (isCancelling?.call() == true) {
          throw Exception('已取消发送');
        }
        if (chunk.output.isNotEmpty) {
          output.write(chunk.output);
          onUpdateMessage(output.toString(), output.length);
        }
      }
      return output.toString();
    } finally {
      _activeSteps = null;
      _activeOnToolSteps = null;
    }
  }

  // ---------- 工具集构建 ----------

  (List<Tool>, Map<String, NativeToolMeta>) _buildTools() {
    if (_toolsCache != null && _toolMetaCache != null) {
      return (_toolsCache!, _toolMetaCache!);
    }
    final tools = <Tool>[];
    final meta = <String, NativeToolMeta>{};
    for (final (toolId, pluginId, config) in ToolConfigManager.instance
        .getEnabledToolsWithPlugin()) {
      // system_ 前缀工具不作为独立调用暴露（与旧两阶段 brief 行为一致）
      if (toolId.startsWith('system_')) continue;
      // methodName = toolId 去掉 "<pluginId>_" 前缀（json key 本身无前缀）
      final methodName = toolId.startsWith('${pluginId}_')
          ? toolId.substring(pluginId.length + 1)
          : toolId;
      meta[toolId] = NativeToolMeta(pluginId, methodName, config.title);
      tools.add(
        Tool(
          name: toolId,
          description: ToolSchemaBuilder.buildDescription(config),
          inputSchema: JsonSchema.create(
            ToolSchemaBuilder.buildSchemaMap(config.parameters),
          ),
          onCall: (args) => _dispatch(toolId, args),
        ),
      );
    }
    debugPrint('[NativeTool] 已构建 ${tools.length} 个原生工具');
    _toolsCache = tools;
    _toolMetaCache = meta;
    return (tools, meta);
  }

  /// 缓存失效（工具配置变更时调用）
  void invalidateCache() {
    _toolsCache = null;
    _toolMetaCache = null;
  }

  // ---------- 执行分发 ----------

  /// 工具调用回调：生成 JS 调用代码 → QuickJS 执行 → 结果回传 LLM
  Future<Map<String, dynamic>> _dispatch(
    String toolId,
    Map<String, dynamic> args,
  ) async {
    // 轮数上限保护：超限后向模型返回错误提示，促使其收敛直接作答
    _activeToolCallCount++;
    if (_activeToolCallCount > maxToolCallsPerLoop) {
      debugPrint('[NativeTool] ⚠️ 达到调用上限（$maxToolCallsPerLoop 次）');
      return {
        'error':
            '工具调用次数已达上限（$maxToolCallsPerLoop 次），'
            '请基于已有结果直接回答用户，不要再调用工具',
      };
    }

    final (_, metaMap) = _buildTools();
    final meta = metaMap[toolId];
    if (meta == null) return {'error': 'Tool $toolId not found'};

    final argsJson = jsonEncode(args);
    final js =
        'const r = await Aboutme.plugins.${meta.pluginId}.'
        '${meta.methodName}($argsJson);\nsetResult(r);\nreturn r;';

    final step = ToolCallStep(
      method: 'run_js',
      title: meta.title,
      desc: '参数：$argsJson',
      data: js,
      status: ToolCallStatus.running,
    );
    _activeSteps?.add(step);
    _activeOnToolSteps?.call(List.of(_activeSteps!));
    debugPrint('[NativeTool] ▶ ${meta.title} | $argsJson');

    try {
      final result = await ToolService.executeJsCode(js);
      step
        ..status = ToolCallStatus.success
        ..result = result;
      _activeOnToolSteps?.call(List.of(_activeSteps!));
      // 结果回传 LLM：JSON 字符串解析后原样传，其余包 result 字段
      final decoded = _tryDecodeJson(result);
      return (decoded is Map<String, dynamic>)
          ? decoded
          : (decoded is List ? {'result': decoded} : {'result': result});
    } catch (e) {
      step
        ..status = ToolCallStatus.failed
        ..error = e.toString();
      _activeOnToolSteps?.call(List.of(_activeSteps!));
      debugPrint('[NativeTool] ✗ ${meta.title} 失败: $e');
      // 异常以 error 形式回传，模型可自行调整参数重试
      return {'error': e.toString()};
    }
  }

  // ---------- 转换工具 ----------

  dynamic _tryDecodeJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// agentlib 消息 → dartantic 消息（system 已由 Agent 构造统一注入，跳过）
  List<Message> _convertHistory(List<compat.ChatCompletionMessage> messages) {
    final result = <Message>[];
    for (final m in messages) {
      final role = switch (m.role) {
        compat.ChatCompletionMessageRole.user => MessageRole.user,
        compat.ChatCompletionMessageRole.assistant => MessageRole.model,
        _ => MessageRole.system,
      };
      if (role == MessageRole.system) continue;

      final content = m.content;
      if (content is compat.StringContent) {
        if (content.value.trim().isNotEmpty) {
          result.add(Message(role: role, content: [TextPart(content.value)]));
        }
      } else if (content is compat.PartsContent) {
        final parts = <Part>[];
        for (final p in content.value) {
          if (p.kind == 'text' && p.text.trim().isNotEmpty) {
            parts.add(TextPart(p.text));
          } else if (p.kind == 'image_url') {
            final url = p.imageUrl.url;
            if (url.startsWith('data:image/')) {
              final mime = url.substring(5, url.indexOf(';'));
              parts.add(MediaPart(contentType: mime, url: url));
            }
          }
        }
        if (parts.isNotEmpty) {
          result.add(Message(role: role, content: parts));
        }
      } else if (content is String && content.trim().isNotEmpty) {
        result.add(Message(role: role, content: [TextPart(content)]));
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
    final auth = agent.headers['Authorization'] ?? '';
    if (auth.startsWith('Bearer ')) return auth.substring(7);
    return agent.headers['api-key'] ?? agent.headers['x-api-key'] ?? '';
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
}
