import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:agentlib/openai_compat.dart';
import '../../models/conversation.dart';
import '../../models/tool_call_step.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import '../../services/tool_service.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'shared/manager_context.dart';

/// 工具调用编排器 - 公共组件
///
/// 优先执行 schema 化 function calling；不可用时回退到旧两阶段 run_js 流程。
/// 这个类被 AIRequestHandler 和 AgentChainExecutor 共用
class ToolOrchestrator {
  /// json_schema 强约束仅被部分 provider 支持（DeepSeek 返回 HTTP 400
  /// "This response_format type is unavailable"），按 baseUrl 判断降级
  static bool _supportsJsonSchema(AIAgent agent) =>
      !agent.baseUrl.toLowerCase().contains('deepseek');

  /// 第一阶段（工具识别）的响应格式：支持则 json_schema 强约束，
  /// 否则降级 json_object（结构约束由提示词承担）
  static ResponseFormat? _toolPhaseResponseFormat(
    AIAgent agent,
    bool enableToolCalling,
  ) {
    if (!enableToolCalling || !agent.enableFunctionCalling) return null;
    if (_supportsJsonSchema(agent)) {
      return ResponseFormat.jsonSchema(
        jsonSchema: JsonSchemaObject(
          name: 'ToolRequest',
          description: '工具需求请求',
          strict: true,
          schema: ToolService.toolRequestSchema,
        ),
      );
    }
    return ResponseFormat.jsonObject();
  }

  final ManagerContext context;
  final Conversation conversation;

  /// 获取工具专用 Agent
  final Future<AIAgent?> Function(
    ToolAgentConfig?, {
    bool enableFunctionCalling,
  })?
  getToolAgent;

  /// 是否正在取消
  final bool Function() isCancelling;

  ToolOrchestrator({
    required this.context,
    required this.conversation,
    this.getToolAgent,
    required this.isCancelling,
  });

  /// 处理两阶段工具调用
  /// 返回 true 表示需要执行工具调用，false 表示正常回复
  Future<bool> processTwoPhaseToolCall({
    required AIAgent agent,
    required String aiMessageId,
    required List<ChatCompletionMessage> contextMessages,
    required List<File> files,
    required String userInput,
    required bool enableToolCalling,
    required StringBuffer buffer,
    required int tokenCount,
    required bool isCollectingToolCall,
    required Function(String content, int count) onUpdateMessage,
    required Function(String error) onError,
    required Function(String firstResponse) onFirstPhaseComplete,
    Function(String)? onThinking,
  }) async {
    // SDK 支持的 provider 优先使用 schema 化 function calling；失败时再走
    // 旧的两阶段 run_js 编排。
    if (NativeToolAgentService.instance.supports(agent, enableToolCalling)) {
      try {
        final systemPrompt = await RequestService.getEffectiveSystemPrompt(
          agent,
        );
        await NativeToolAgentService.instance.runToolLoop(
          agent: agent,
          systemPrompt: systemPrompt,
          contextMessages: contextMessages,
          files: files,
          conversationId: context.conversationId,
          onUpdateMessage: onUpdateMessage,
          onToolSteps: (steps) async {
            final message = context.messageService.getMessage(
              context.conversationId,
              aiMessageId,
            );
            if (message != null) {
              await context.messageService.updateMessage(
                message.copyWith(toolCall: ToolCallResponse(steps: steps)),
              );
            }
          },
          isCancelling: isCancelling,
        );
        return false;
      } catch (e, stack) {
        debugPrint('❌ [NativeTool] 标准工具调用失败: $e\n$stack');
        if (isCancelling() || e.toString().contains('已取消发送')) {
          onError('已取消发送');
          return false;
        }
        if (e is NativeToolExecutionException && e.toolCallsStarted > 0) {
          onError(
            '标准工具调用已发起 ${e.toolCallsStarted} 次，但后续生成失败；为避免重复执行，已停止回退：${e.cause}',
          );
          return false;
        }
        debugPrint('⚠️ [NativeTool] 尚未执行工具，回退旧两阶段 run_js 编排');
        onUpdateMessage('', 0);
      }
    }

    // 第一阶段：工具需求识别
    final toolRequest = await _executeFirstPhase(
      agent: agent,
      contextMessages: contextMessages,
      files: files,
      enableToolCalling: enableToolCalling,
      buffer: buffer,
      tokenCount: tokenCount,
      isCollectingToolCall: isCollectingToolCall,
      onUpdateMessage: onUpdateMessage,
      onError: onError,
      onThinking: onThinking,
    );

    // ⚠️ 关键修复：检查第一阶段是否直接返回了工具调用代码（steps格式）
    final firstResponse = buffer.toString();
    if (ToolService.containsToolCall(firstResponse)) {
      debugPrint('✅ 第一阶段直接返回了工具调用代码，跳过第二阶段');
      onFirstPhaseComplete(firstResponse);
      return true;
    }

    // 模型输出了合法的工具 JSON 但不需要工具：
    // JSON 格式约束（json_object/json_schema）下模型无法同时输出对话内容，
    // 必须丢弃 JSON 并无格式约束地重新生成正常回复，否则半截 JSON 会泄漏进聊天
    if (toolRequest != null && toolRequest.isEmpty) {
      debugPrint('✅ [第一阶段] 无工具需求，丢弃 JSON 重新生成正常回复');
      final plain = await _executePlainResponse(
        agent: agent,
        contextMessages: contextMessages,
        files: files,
        onUpdateMessage: onUpdateMessage,
        onError: onError,
        onThinking: onThinking,
      );
      if (plain != null) {
        buffer
          ..clear()
          ..write(plain);
      }
      return false;
    }

    // 第一阶段输出不是工具 JSON（解析失败或出错），维持原有内容直接返回
    if (toolRequest == null || toolRequest.isEmpty) {
      return false;
    }

    debugPrint('🔍 识别到工具需求: ${toolRequest.join(", ")}');

    // 第二阶段：生成工具调用代码
    final toolCallCode = await _executeSecondPhase(
      agent: agent,
      toolRequest: toolRequest,
      userInput: userInput,
      firstResponse: buffer.toString(),
      aiMessageId: aiMessageId,
      files: files,
      onUpdateMessage: onUpdateMessage,
      onError: onError,
      onThinking: onThinking,
    );

    // 如果第二阶段成功生成工具调用代码，通知调用者
    if (toolCallCode != null && toolCallCode.isNotEmpty) {
      onFirstPhaseComplete(toolCallCode);
      return true;
    }

    return false;
  }

  /// 执行第一阶段：工具需求识别
  Future<List<String>?> _executeFirstPhase({
    required AIAgent agent,
    required List<ChatCompletionMessage> contextMessages,
    required List<File> files,
    required bool enableToolCalling,
    required StringBuffer buffer,
    required int tokenCount,
    required bool isCollectingToolCall,
    required Function(String content, int count) onUpdateMessage,
    required Function(String error) onError,
    Function(String)? onThinking,
  }) async {
    // 处理图片文件
    final imageFiles =
        files.where((f) => f.path != null && f.path.isNotEmpty).toList();

    // 获取工具识别agent配置
    final toolDetectionConfig = conversation.toolDetectionConfig;

    AIAgent effectiveAgent = agent;
    Map<String, String>? additionalPrompts;

    if (enableToolCalling && agent.enableFunctionCalling) {
      // 准备工具简要列表（用于占位符替换）
      final toolBriefPrompt = ToolService.getToolBriefPrompt();
      if (toolBriefPrompt.isNotEmpty) {
        additionalPrompts = {'tool_brief': toolBriefPrompt};
        // 不支持 json_schema 的 provider 降级为 json_object 时，
        // 输出结构约束改由提示词承担（json_object 要求提示中含 json 说明）
        if (!_supportsJsonSchema(agent)) {
          additionalPrompts['tool_brief'] =
              '$toolBriefPrompt\n'
              '你必须只输出一个 json 对象，格式为 '
              '{"needed_tools": ["工具ID1", "工具ID2"]}；'
              '不需要任何工具时输出 {"needed_tools": []}。不要输出其他任何内容。';
        }
      }

      if (toolDetectionConfig != null && getToolAgent != null) {
        // 使用专用工具识别agent（启用工具调用，返回JSON格式的工具需求）
        final toolAgent = await getToolAgent!(
          toolDetectionConfig,
          enableFunctionCalling: true,
        );
        if (toolAgent != null) {
          effectiveAgent = toolAgent;
          debugPrint(
            '🔧 [第一阶段] 使用专用工具识别Agent: ${toolDetectionConfig.providerId}/${toolDetectionConfig.modelId}',
          );
        } else {
          debugPrint('⚠️ [第一阶段] 创建工具识别Agent失败，使用原agent');
        }
      } else {
        // 未配置专用agent，使用当前agent + 工具提示词（通过占位符传递）
        debugPrint('🔧 [第一阶段] 未配置专用agent，使用原agent + 工具提示词');
      }
    }

    // 使用 Completer 等待第一阶段完成
    final firstPhaseCompleter = Completer<List<String>?>();

    // 流式请求 AI 回复（第一阶段：工具需求识别，带重试机制，最多10次重试）
    await RequestService.streamResponseWithRetry(
      agent: effectiveAgent,
      prompt: null,
      contextMessages: contextMessages,
      vision: imageFiles.isNotEmpty,
      filePath: imageFiles.isNotEmpty ? imageFiles.first.path : null,
      additionalPrompts: additionalPrompts,
      // 如果启用工具调用，强制返回工具请求 JSON 格式：
      // - 默认用 json_schema 强约束（Structred Outputs）
      // - DeepSeek 等 provider 不支持 json_schema（HTTP 400
      //   "This response_format type is unavailable"），降级为 json_object，
      //   结构约束由提示词承担
      responseFormat: _toolPhaseResponseFormat(agent, enableToolCalling),
      shouldCancel: isCancelling,
      onToken: (token) {
        buffer.write(token);
        final currentTokenCount = buffer.length; // 使用 buffer 长度作为 token 计数
        final content = buffer.toString();

        // 检查是否是工具需求的 JSON 格式
        final isToolRequestJson = RegExp(
          r'''^\s*\{\s*["']?needed_tools["']?\s*:''',
        ).hasMatch(content);

        if (isToolRequestJson && content.isNotEmpty) {
          // 尝试解析已获取到的工具列表
          final toolRequest = ToolService.parseToolRequest(content);
          if (toolRequest != null && toolRequest.isNotEmpty) {
            // 顶栏显示"正在查看工具用法..."
            final toolsText = toolRequest.join('、');
            context.onTypingStatus?.call('🔍 正在查看 $toolsText 工具的用法...');
          } else {
            // 还在生成 JSON，顶栏显示通用提示
            context.onTypingStatus?.call('🔍 正在识别需要的工具...');
          }
        } else if (content.isNotEmpty) {
          if (content.trimLeft().startsWith('{')) {
            // 可能是尚未流到冒号的工具 JSON 前缀，先不显示，防半截 JSON 泄漏
            context.onTypingStatus?.call('🔍 正在识别需要的工具...');
          } else {
            // 不是工具需求 JSON，直接显示（比如 markdown 格式的工具调用）
            context.onTypingStatus?.call(null);
            onUpdateMessage(content, currentTokenCount);
          }
        }
      },
      onComplete: () {
        // 解析第一阶段响应
        final firstResponse = buffer.toString();
        final toolRequest = ToolService.parseToolRequest(firstResponse);

        firstPhaseCompleter.complete(toolRequest);
      },
      onThinking: onThinking,
      onError: (error) {
        debugPrint('❌ 第一阶段 Agent 响应错误: $error');

        if (error == '已取消发送') {
          onUpdateMessage('🛑 用户已取消操作', 0);
        } else {
          onUpdateMessage('❌ 错误: $error', 0);
        }

        firstPhaseCompleter.complete(null);
      },
      maxRetries: 10,
      retryDelay: 1000,
    );

    return firstPhaseCompleter.future;
  }

  /// 无格式约束地重新生成正常回复（第一阶段输出空工具 JSON 时的兜底）
  ///
  /// 用原始上下文再请求一次（responseFormat=null、不注入工具提示词），
  /// 流式结果经 onUpdateMessage 直接写入消息，返回 null 表示失败
  Future<String?> _executePlainResponse({
    required AIAgent agent,
    required List<ChatCompletionMessage> contextMessages,
    required List<File> files,
    required Function(String content, int count) onUpdateMessage,
    required Function(String error) onError,
    Function(String)? onThinking,
  }) async {
    final imageFiles =
        files.where((f) => f.path != null && f.path.isNotEmpty).toList();

    final buffer = StringBuffer();
    final completer = Completer<String?>();

    await RequestService.streamResponseWithRetry(
      agent: agent,
      prompt: null,
      contextMessages: contextMessages,
      vision: imageFiles.isNotEmpty,
      filePath: imageFiles.isNotEmpty ? imageFiles.first.path : null,
      responseFormat: null,
      shouldCancel: isCancelling,
      onToken: (token) {
        buffer.write(token);
        context.onTypingStatus?.call(null);
        onUpdateMessage(buffer.toString(), buffer.length);
      },
      onComplete: () => completer.complete(buffer.toString()),
      onThinking: onThinking,
      onError: (error) {
        debugPrint('❌ 重新生成正常回复失败: $error');
        if (error == '已取消发送') {
          onUpdateMessage('🛑 用户已取消操作', 0);
        } else {
          onUpdateMessage('❌ 错误: $error', 0);
        }
        completer.complete(null);
      },
      maxRetries: 10,
      retryDelay: 1000,
    );

    return completer.future;
  }

  /// 执行第二阶段：生成工具调用代码
  Future<String?> _executeSecondPhase({
    required AIAgent agent,
    required List<String> toolRequest,
    required String userInput,
    required String firstResponse,
    required String aiMessageId,
    required List<File> files,
    required Function(String content, int count) onUpdateMessage,
    required Function(String error) onError,
    Function(String)? onThinking,
  }) async {
    // 从最新会话中获取工具执行agent配置
    final toolExecutionConfig = conversation.toolExecutionConfig;

    AIAgent executionAgent = agent;

    // 获取用户输入
    final effectiveUserInput = userInput;

    // 准备工具详细文档（用于占位符替换）
    final detailPrompt = await ToolService.getToolDetailPrompt(toolRequest);
    Map<String, String>? secondAdditionalPrompts;
    if (detailPrompt.isNotEmpty) {
      secondAdditionalPrompts = {'tool_detail': detailPrompt};
    }

    if (toolExecutionConfig != null && getToolAgent != null) {
      // 使用专用工具执行agent（不启用工具调用，只返回JSON格式的代码）
      final toolAgent = await getToolAgent!(
        toolExecutionConfig,
        enableFunctionCalling: false,
      );
      if (toolAgent != null) {
        executionAgent = toolAgent;
        debugPrint(
          '🔧 [第二阶段] 使用专用工具执行Agent: ${toolExecutionConfig.providerId}/${toolExecutionConfig.modelId}',
        );
      } else {
        debugPrint('⚠️ [第二阶段] 创建工具执行Agent失败，使用原agent');
      }
    } else {
      // 未配置专用agent，使用当前agent + 工具详细文档（通过占位符传递）
      debugPrint('🔧 [第二阶段] 未配置专用agent，使用原agent + 工具详细文档');
    }

    // 构建第二阶段的 context messages（用户输入）
    // ⚠️ 关键修复：如果有图片，需要使用 parts 格式传递图片和文字
    final imageFiles =
        files.where((f) => f.path != null && f.path.isNotEmpty).toList();

    final ChatCompletionMessage userMessage;
    if (imageFiles.isNotEmpty) {
      // 包含图片：使用 parts 格式
      final parts = <ChatCompletionMessageContentPart>[
        ChatCompletionMessageContentPart.text(
          text:
              '原始用户输入：\n$effectiveUserInput\n\n第一阶段识别的工具：${toolRequest.join(", ")}\n\n请根据文档生成工具调用代码。',
        ),
      ];

      // 添加图片
      for (var file in imageFiles) {
        try {
          final fileObj = File(file.path);
          if (fileObj.existsSync()) {
            final bytes = fileObj.readAsBytesSync();
            final base64Image = base64Encode(bytes);
            parts.add(
              ChatCompletionMessageContentPart.image(
                imageUrl: ChatCompletionMessageImageUrl(
                  url: 'data:image/jpeg;base64,$base64Image',
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('读取图片文件失败: ${file.path}, 错误: $e');
        }
      }

      userMessage = ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.parts(parts),
      );
    } else {
      // 不包含图片：使用字符串格式
      userMessage = ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(
          '原始用户输入：\n$effectiveUserInput\n\n第一阶段识别的工具：${toolRequest.join(", ")}\n\n请根据文档生成工具调用代码。',
        ),
      );
    }

    final toolExecutionMessages = [userMessage];

    // 用于第二阶段的 buffer
    final secondBuffer = StringBuffer();
    int secondTokenCount = 0;

    // 使用 Completer 等待第二阶段完成
    final secondPhaseCompleter = Completer<String?>();

    // 第二阶段：请求生成工具调用代码（带重试机制，最多10次重试）
    await RequestService.streamResponseWithRetry(
      agent: executionAgent,
      prompt: null,
      contextMessages: toolExecutionMessages,
      additionalPrompts: secondAdditionalPrompts,
      // 移除 JSON Schema 限制，改为文本格式，让 AI 返回 Markdown 格式的工具调用
      responseFormat: null,
      shouldCancel: isCancelling,
      onToken: (token) {
        secondBuffer.write(token);
        secondTokenCount++;

        final content = secondBuffer.toString();
        // 实时更新内容，让 markdown 能够渲染
        if (content.isNotEmpty) {
          context.onTypingStatus?.call(null);
          onUpdateMessage(content, secondTokenCount);
        }
      },
      onError: (error) {
        debugPrint('❌ [第二阶段] Agent 响应错误: $error');
        final errorMessage =
            error == '已取消发送' ? '🛑 用户已取消操作' : '❌ 生成工具调用时出错: $error';
        onUpdateMessage(errorMessage, 0);
        secondPhaseCompleter.complete(null);
      },
      onComplete: () {
        // 返回第二阶段响应
        secondPhaseCompleter.complete(secondBuffer.toString());
      },
      onThinking: onThinking,
      maxRetries: 10,
      retryDelay: 1000,
    );

    return secondPhaseCompleter.future;
  }
}
