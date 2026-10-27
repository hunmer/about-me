import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Value;

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/aliveness/channels/chat_aliveness_channel.dart';
import 'package:aboutme/plugins/openai/handlers/chat_event_handler.dart'
    show submitAutoReplyThreadMessage;
import 'package:aboutme/widgets/chat_thread_sheet.dart';

/// AI 回复线程的底部 drawer 简易聊天界面：
/// 根消息 + 线程内多轮气泡 + 输入框续聊（走同一套活人感编排）。
///
/// 线程数据与发送逻辑在此维护，面板 UI 复用通用 [ChatThreadSheet]。
class AiThreadDrawer extends StatefulWidget {
  final Message rootMessage;

  const AiThreadDrawer({super.key, required this.rootMessage});

  @override
  State<AiThreadDrawer> createState() => _AiThreadDrawerState();
}

class _AiThreadDrawerState extends State<AiThreadDrawer> {
  late String _subscriptionId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subscriptionId = EventManager.instance.subscribe(
      AiThreadService.eventUpdated,
      _handleThreadUpdated,
    );
  }

  @override
  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    EventManager.instance.unsubscribeById(_subscriptionId);
    super.dispose();
  }

  void _handleThreadUpdated(EventArgs args) {
    if (args is! Value<String>) return;
    if (args.value != widget.rootMessage.id) return;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _send(String text) async {
    if (text.isEmpty || _sending) return;
    final thread = AiThreadService.instance.getThread(widget.rootMessage.id);
    if (thread == null) return;

    setState(() => _sending = true);
    try {
      await AiThreadService.instance.appendMessage(
        widget.rootMessage.id,
        AiThreadMessage(
          id: 'user_followup_${DateTime.now().millisecondsSinceEpoch}',
          role: 'user',
          content: text,
          date: DateTime.now(),
        ),
      );

      // 发给线程关联的所有 agent（与频道内 @ 多 agent 的行为一致）
      final openaiPlugin =
          PluginManager.instance.getPlugin('openai') as OpenAIPlugin;
      for (final agentId in thread.agentIds) {
        final agent = await openaiPlugin.controller.getAgent(agentId);
        if (agent == null) continue;
        // 活人感 agent 走编排；未开启活人感（频道自动回复线程）走直接生成
        final handled = await submitAiThreadMessage(
          agent: agent,
          channelId: thread.channelId,
          rootMessageId: thread.rootMessageId,
          text: text,
        );
        if (!handled) {
          await submitAutoReplyThreadMessage(
            agent: agent,
            channelId: thread.channelId,
            rootMessageId: thread.rootMessageId,
            text: text,
          );
        }
      }
    } catch (e) {
      Toast.error('chat_threadSendFailed'.trParams({'error': '$e'}));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = AiThreadService.instance.getThread(widget.rootMessage.id);

    return ChatThreadSheet(
      title: _resolveTitle(thread),
      bubbles: [
        ChatThreadBubbleData(
          id: widget.rootMessage.id,
          content: widget.rootMessage.content,
          isUser: true,
        ),
        ...?thread?.messages.map(
          (msg) => ChatThreadBubbleData(
            id: msg.id,
            content: msg.content,
            isUser: msg.role == 'user',
            agentName: msg.agentName,
            status: msg.status,
            type: msg.type,
            audioPath: msg.audioPath,
            audioDurationSec: msg.audioDurationSec,
          ),
        ),
      ],
      showTyping: thread?.isThinking == true,
      inputHint: 'chat_threadInputHint'.tr,
      onSend: _send,
      sending: _sending,
    );
  }

  String _resolveTitle(AiThread? thread) {
    final names =
        thread?.messages
            .map((m) => m.agentName)
            .whereType<String>()
            .toSet()
            .toList() ??
        <String>[];
    if (names.isEmpty) return 'chat_threadTitle'.tr;
    return names.length == 1 ? names.first : 'chat_threadTitle'.tr;
  }
}
