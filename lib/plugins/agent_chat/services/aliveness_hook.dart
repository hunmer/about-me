import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/aliveness/aliveness_orchestrator.dart';
import 'package:aboutme/plugins/openai/aliveness/channels/agent_chat_aliveness_channel.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

export 'package:aboutme/plugins/openai/aliveness/channels/agent_chat_aliveness_channel.dart'
    show FlushCallback, AgentChatGenerationResult;

/// agent_chat（AI 对话插件）的活人感接入薄壳：
/// 只负责接管条件判断、已读标记与互动会话记录，
/// 缓冲/决策/生成/发布全流程统一走 [AlivenessOrchestrator]。
/// 由 ChatController.sendMessage 在普通路径前调用，返回 false 表示未接管（走原路径）。
class AgentChatAlivenessHook {
  AgentChatAlivenessHook._();
  static final AgentChatAlivenessHook instance = AgentChatAlivenessHook._();

  final _store = AlivenessStore.instance;

  /// [onIdle] 本轮无回复（已读不回/空内容/出错）时复位"正在输入中"标题态
  Future<bool> onUserMessage({
    required Conversation conversation,
    required ChatMessage userMessage,
    required MessageService messageService,
    required FlushCallback onFlushGenerate,
    required void Function() onCancelGenerate,
    required void Function() onReveal,
    void Function()? onIdle,
  }) async {
    // 仅单 agent 会话支持（链式模式走原路径）
    final agentId = conversation.agentId;
    if (agentId == null || conversation.isChainMode) return false;

    final agent = await OpenAIPlugin.instance.controller.getAgent(agentId);
    final config = agent?.alivenessConfig;
    if (agent == null || config == null || !config.enabled) return false;

    // 1) 已读标记
    userMessage.metadata ??= {};
    userMessage.metadata!['readAt'] = DateTime.now().millisecondsSinceEpoch;
    await messageService.updateMessage(userMessage);
    debugPrint('[Aliveness][已读] ${agent.name} 已读 agent_chat 消息');

    // 2) 记录互动会话（主动消息目标沿用 agent_chat 体系时定位会话）
    unawaited(_recordConversation(agentId, conversation.id));

    // 3) 进入通用缓冲编排
    return AlivenessOrchestrator.instance.submit(
      agent: agent,
      targetId: conversation.id,
      text: userMessage.content,
      createSession: () => AgentChatAlivenessSession(
        agent: agent,
        conversation: conversation,
        messageService: messageService,
        onFlushGenerate: onFlushGenerate,
        onCancelGenerate: onCancelGenerate,
        onReveal: onReveal,
        onIdle: onIdle,
      ),
    );
  }

  Future<void> _recordConversation(
    String agentId,
    String conversationId,
  ) async {
    try {
      final stats = await _store.loadStats(agentId);
      stats['lastAgentChatConversationId'] = conversationId;
      await _store.saveStats(agentId, stats);
    } catch (_) {}
  }
}
