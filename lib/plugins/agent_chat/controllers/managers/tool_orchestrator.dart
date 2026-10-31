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
    required FutureOr<void> Function(String content, int count) onUpdateMessage,
    required FutureOr<void> Function(String error) onError,
    required FutureOr<void> Function(String firstResponse) onFirstPhaseComplete,
    FutureOr<void> Function(String)? onThinking,
  }) async {
    Future<void> pendingWrites = Future<void>.value();
    Object? writeError;
    void enqueue(FutureOr<void> Function() write) {
      pendingWrites = pendingWrites.then((_) async {
        try {
          await write();
        } catch (error) {
          writeError ??= error;
        }
      });
    }

    try {
      if (isCancelling()) throw StateError('已取消发送');
      if (files.isEmpty &&
          context.extraToolsProvider == null &&
          !NativeToolAgentService.instance.supports(agent, enableToolCalling)) {
        await _executePlainResponse(
          agent: agent,
          contextMessages: contextMessages,
          files: files,
          onUpdateMessage: (content, count) =>
              enqueue(() => onUpdateMessage(content, count)),
          onThinking: (thinking) => enqueue(() => onThinking?.call(thinking)),
        );
      } else {
        final systemPrompt = await RequestService.getEffectiveSystemPrompt(
          agent,
        );
        final response = await NativeToolAgentService.instance.runToolLoop(
          agent: agent,
          systemPrompt: systemPrompt,
          contextMessages: contextMessages,
          files: files,
          conversationId: context.conversationId,
          questionsInChat: true,
          useJsTools: context.useJsTools?.call() ?? false,
          alivenessOnlyTools:
              !(enableToolCalling && agent.enableFunctionCalling),
          onUpdateMessage: (content, count) =>
              enqueue(() => onUpdateMessage(content, count)),
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
            await pendingWrites;
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
          onThinking: (thinking) => enqueue(() => onThinking?.call(thinking)),
          // 已完成的轮次正文存入 metadata，供「查看执行过程」展开显示
          onTurnTexts: (texts) => enqueue(() async {
            final message = context.messageService.getMessage(
              context.conversationId,
              aiMessageId,
            );
            if (message != null) {
              await context.messageService.updateMessage(
                message.copyWith(
                  metadata: {...?message.metadata, 'processTexts': texts},
                ),
              );
            }
          }),
          isCancelling: isCancelling,
          extraTools: context.extraToolsProvider?.call() ?? const [],
        );
        if (response.trim().isEmpty && !isCancelling()) {
          throw StateError('AI响应为空');
        }
      }
      await pendingWrites;
      if (writeError != null) throw writeError!;
      if (isCancelling()) throw StateError('已取消发送');
    } catch (e, stack) {
      await pendingWrites;
      debugPrint('[NativeTool] Agent 响应失败: $e\n$stack');
      await onError(
        isCancelling() || e.toString().contains('已取消发送')
            ? '已取消发送'
            : e.toString(),
      );
      rethrow;
    }
    return false;
  }

  Future<String?> _executePlainResponse({
    required AIAgent agent,
    required List<ChatCompletionMessage> contextMessages,
    required List<File> files,
    required Function(String content, int count) onUpdateMessage,
    Function(String)? onThinking,
  }) async {
    final output = StringBuffer();
    final completer = Completer<String?>();
    String? requestError;
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
      onComplete: () {
        if (!completer.isCompleted) completer.complete(output.toString());
      },
      onThinking: onThinking,
      onError: (error) {
        debugPrint('[Request] 普通响应失败: $error');
        requestError ??= isCancelling() ? '已取消发送' : error;
        if (!completer.isCompleted) completer.complete(null);
      },
      maxRetries: 10,
      retryDelay: 1000,
    );
    if (!completer.isCompleted) {
      requestError ??= isCancelling() ? '已取消发送' : 'AI响应未正常结束';
      completer.complete(null);
    }
    final response = await completer.future;
    if (requestError != null) throw StateError(requestError!);
    return response;
  }
}
