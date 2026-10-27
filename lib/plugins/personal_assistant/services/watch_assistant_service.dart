import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/chat_controller.dart';
import 'package:aboutme/plugins/agent_chat/services/message_detail_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';

/// 将手表转写文本交给个人助手，最终结果写回 iPhone 原生请求缓存。
class WatchAssistantService {
  WatchAssistantService(this._channel);

  final MethodChannel _channel;
  final Set<String> _acceptedRequests = {};
  Future<void> _queue = Future<void>.value();

  Map<String, dynamic> accept(dynamic arguments) {
    if (arguments is! Map) {
      throw ArgumentError('缺少手表语音请求参数');
    }
    final requestId = arguments['requestId'] as String?;
    final sessionId = arguments['sessionId'] as String?;
    final text = (arguments['transcription'] as String?)?.trim();
    if (requestId == null ||
        requestId.isEmpty ||
        sessionId == null ||
        sessionId.isEmpty ||
        text == null ||
        text.isEmpty) {
      throw ArgumentError('手表请求编号、会话编号或转写内容为空');
    }
    if (_acceptedRequests.add(requestId)) {
      // 所有手表请求串行处理，避免同一会话的上下文和工具执行交错。
      _queue = _queue.then((_) => _process(requestId, sessionId, text));
    }
    return {'accepted': true};
  }

  Future<void> _process(String requestId, String sessionId, String text) async {
    ChatController? controller;
    MessageService? messages;
    var initialized = false;
    final moments = MomentsService.instance;
    final previousConversationId = moments.currentConversationId;
    final previousAgentId = moments.currentAgentId;
    final previousMessageService = moments.currentMessageService;
    try {
      await _update(requestId, 'processing', transcription: text);
      await ChatAssistantService.ensureBuiltinAgent();
      final plugin = AgentChatPlugin.instance;
      final conversations = plugin.conversationController?.conversationService;
      if (conversations == null) {
        throw StateError('个人助手尚未初始化，请在 iPhone 打开 aboutme');
      }
      final route =
          '${ChatAssistantService.conversationRoute}_watch_$sessionId';
      final conversation =
          conversations.getTemporaryConversationForRoute(route) ??
          await conversations.createTemporaryConversation(
            title: '手表个人助手',
            routeName: route,
            agentId: ChatAssistantService.builtinAgentId,
          );
      messages = MessageService(storage: plugin.storage);
      controller = ChatController(
        conversation: conversation,
        messageService: messages,
        conversationService: conversations,
        messageDetailService: MessageDetailService(storage: plugin.storage),
        templateService: ToolTemplateService(plugin.storage),
        getSettings: () => plugin.settings,
      );
      await controller.initialize();
      initialized = true;
      final previousIds = messages.currentMessages.map((m) => m.id).toSet();
      controller.setInputText(text);
      // 跳过活人感的延迟生成，等待完整工具循环后再回传最终结果。
      await controller.sendMessage(bypassAliveness: true);
      final replies = messages.currentMessages
          .where(
            (message) =>
                !previousIds.contains(message.id) &&
                !message.isUser &&
                !message.isSessionDivider,
          )
          .toList();
      for (final message in replies) {
        final error = message.metadata?['requestError'];
        if (error != null) throw StateError(error.toString());
      }
      final completed = replies
          .where(
            (message) =>
                !message.isGenerating &&
                message.parentId == null &&
                message.content.trim().isNotEmpty,
          )
          .toList();
      if (completed.isEmpty) {
        throw StateError('助手未返回文字回复，请检查 iPhone 的 AI 服务商和模型配置');
      }
      final reply = completed.last.splitThinkContent().$2.trim();
      if (reply.isEmpty) throw StateError('助手返回了空回复');
      await _update(requestId, 'completed', text: reply, transcription: text);
    } catch (error, stack) {
      debugPrint('[WatchAssistant] 请求失败 id=$requestId: $error\n$stack');
      try {
        await _update(
          requestId,
          'failed',
          transcription: text,
          error: '$error',
        );
      } catch (bridgeError) {
        debugPrint('[WatchAssistant] 无法回传错误 id=$requestId: $bridgeError');
      }
    } finally {
      if (messages != null &&
          identical(moments.currentMessageService, messages)) {
        moments.currentConversationId = previousConversationId;
        moments.currentAgentId = previousAgentId;
        moments.currentMessageService = previousMessageService;
      }
      if (initialized) controller?.dispose();
      messages?.dispose();
      if (_acceptedRequests.length > 30) {
        _acceptedRequests.remove(_acceptedRequests.first);
      }
    }
  }

  Future<void> _update(
    String requestId,
    String status, {
    String? text,
    String? transcription,
    String? error,
  }) async {
    await _channel.invokeMethod<void>('updateAssistantResponse', {
      'requestId': requestId,
      'status': status,
      if (text != null) 'text': text,
      if (transcription != null) 'transcription': transcription,
      if (error != null) 'error': error,
    });
  }
}
