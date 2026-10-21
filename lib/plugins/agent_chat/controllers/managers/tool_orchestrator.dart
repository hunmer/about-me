import 'dart:async';
import 'dart:io';
import 'package:agentlib/openai_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'shared/manager_context.dart';

/// 使用 dartantic_ai 原生 function calling 执行 Agent 工具循环。
class ToolOrchestrator {
  ToolOrchestrator({
    required this.context,
    required this.conversation,
    this.getToolAgent,
    required this.isCancelling,
  });
  final ManagerContext context;
  final Conversation conversation;
  final Future<AIAgent?> Function(
    ToolAgentConfig?, {
    bool enableFunctionCalling,
  })?
  getToolAgent;
  final bool Function() isCancelling;

  /// 工具定义通过 Agent 构造函数传入；dartantic_ai 负责工具调用、执行和多轮回传。
  Future<bool> processToolCall({
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
    if (files.isEmpty &&
        !NativeToolAgentService.instance.supports(agent, enableToolCalling)) {
      await _executePlainResponse(
        agent: agent,
        contextMessages: contextMessages,
        files: files,
        onUpdateMessage: onUpdateMessage,
        onError: onError,
        onThinking: onThinking,
      );
      return false;
    }
    try {
      final systemPrompt = await RequestService.getEffectiveSystemPrompt(agent);
      await NativeToolAgentService.instance.runToolLoop(
        agent: agent,
        systemPrompt: systemPrompt,
        contextMessages: contextMessages,
        files: files,
        conversationId: context.conversationId,
        questionsInChat: true,
        useJsTools: context.useJsTools?.call() ?? false,
        alivenessOnlyTools: !(enableToolCalling && agent.enableFunctionCalling),
        onUpdateMessage: onUpdateMessage,
        onImageDescription: (path, description) async {
          // 以附件路径定位原始消息，避免重新生成或并发回复时写错消息。
          final messages = await context.messageService.getMessages(
            context.conversationId,
          );
          for (final message in messages.where((m) => m.isUser)) {
            if (!message.attachments.any(
              (a) => a.isImage && a.filePath == path,
            )) {
              continue;
            }
            final descriptions = Map<String, dynamic>.from(
              message.metadata?['imageDescriptions'] as Map? ?? const {},
            );
            descriptions[path] = description;
            await context.messageService.updateMessage(
              message.copyWith(
                metadata: {
                  ...?message.metadata,
                  'imageDescriptions': descriptions,
                },
              ),
            );
          }
        },
        onToolSteps: (steps) async {
          final message = context.messageService.getMessage(
            context.conversationId,
            aiMessageId,
          );
          if (message == null &&
              steps.any((s) => s.method == 'askuserquestions')) {
            throw StateError('聊天消息已不存在，无法展示提问');
          }
          if (message != null) {
            await context.messageService.updateMessage(
              message.copyWith(toolCall: ToolCallResponse(steps: steps)),
            );
          }
        },
        onThinking: onThinking,
        // 已完成的轮次正文存入 metadata，供「查看执行过程」展开显示
        onTurnTexts: (texts) {
          final message = context.messageService.getMessage(
            context.conversationId,
            aiMessageId,
          );
          if (message != null) {
            context.messageService.updateMessage(
              message.copyWith(
                metadata: {...?message.metadata, 'processTexts': texts},
              ),
            );
          }
        },
        isCancelling: isCancelling,
      );
    } catch (e, stack) {
      debugPrint('[NativeTool] Agent 工具循环失败: $e\n$stack');
      onError(
        isCancelling() || e.toString().contains('已取消发送')
            ? '已取消发送'
            : e.toString(),
      );
    }
    return false;
  }

  Future<String?> _executePlainResponse({
    required AIAgent agent,
    required List<ChatCompletionMessage> contextMessages,
    required List<File> files,
    required Function(String content, int count) onUpdateMessage,
    required Function(String error) onError,
    Function(String)? onThinking,
  }) async {
    final output = StringBuffer();
    final completer = Completer<String?>();
    await RequestService.streamResponseWithRetry(
      agent: agent,
      prompt: null,
      contextMessages: contextMessages,
      vision: false,
      responseFormat: null,
      shouldCancel: isCancelling,
      onToken: (token) {
        output.write(token);
        context.onTypingStatus?.call(null);
        onUpdateMessage(output.toString(), output.length);
      },
      onComplete: () => completer.complete(output.toString()),
      onThinking: onThinking,
      onError: (error) {
        debugPrint('[Request] 普通响应失败: $error');
        onError(isCancelling() ? '已取消发送' : error);
        completer.complete(null);
      },
      maxRetries: 10,
      retryDelay: 1000,
    );
    return completer.future;
  }
}
