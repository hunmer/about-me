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
    if (!NativeToolAgentService.instance.supports(agent, enableToolCalling)) {
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
        onThinking: onThinking,
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
    final imageFiles = files.where((f) => f.path.isNotEmpty).toList();
    final output = StringBuffer();
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
        output.write(token);
        context.onTypingStatus?.call(null);
        onUpdateMessage(output.toString(), output.length);
      },
      onComplete: () => completer.complete(output.toString()),
      onThinking: onThinking,
      onError: (error) {
        debugPrint('[Request] 普通响应失败: $error');
        onUpdateMessage(error == '已取消发送' ? '🛑 用户已取消操作' : '❌ 错误: $error', 0);
        completer.complete(null);
      },
      maxRetries: 10,
      retryDelay: 1000,
    );
    return completer.future;
  }
}
