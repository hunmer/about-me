import 'package:flutter/material.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/aliveness/channels/chat_aliveness_channel.dart';
import 'package:aboutme/plugins/openai/handlers/chat_event_handler.dart'
    show submitAutoReplyThreadMessage;

/// AI 回复线程的底部 drawer 简易聊天界面：
/// 气泡消息（根消息 + 线程内多轮）+ 输入框续聊（走同一套活人感编排）。
class AiThreadDrawer extends StatefulWidget {
  final Message rootMessage;

  const AiThreadDrawer({super.key, required this.rootMessage});

  @override
  State<AiThreadDrawer> createState() => _AiThreadDrawerState();
}

class _AiThreadDrawerState extends State<AiThreadDrawer> {
  late String _subscriptionId;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _subscriptionId = EventManager.instance.subscribe(
      AiThreadService.eventUpdated,
      _handleThreadUpdated,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    EventManager.instance.unsubscribeById(_subscriptionId);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleThreadUpdated(EventArgs args) {
    if (args is! Value<String>) return;
    if (args.value != widget.rootMessage.id) return;
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    final thread = AiThreadService.instance.getThread(widget.rootMessage.id);
    if (thread == null) return;

    setState(() => _sending = true);
    _inputController.clear();
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
      Toast.error('发送失败: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = AiThreadService.instance.getThread(widget.rootMessage.id);
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    final title = _resolveTitle(thread);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        // 键盘弹出时压缩高度，保证输入行可见
        height: (mq.size.height * 0.78 - mq.viewInsets.bottom).clamp(
          300.0,
          mq.size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 拖拽条 + 标题
              Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread?.isThinking == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '正在输入…',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              // 消息列表
              Expanded(
                child:
                    thread == null
                        ? const SizedBox.shrink()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: thread.messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildBubble(
                                  content: widget.rootMessage.content,
                                  isUser: true,
                                );
                              }
                              final msg = thread.messages[index - 1];
                              return _buildBubble(
                                content: msg.content,
                                isUser: msg.role == 'user',
                                agentName: msg.agentName,
                                status: msg.status,
                                type: msg.type,
                                audioPath: msg.audioPath,
                                audioDurationSec: msg.audioDurationSec,
                              );
                            },
                          ),
              ),
              // 输入行
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 4,
                  top: 6,
                  bottom: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: '发送消息…',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor:
                              theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color:
                            _sending
                                ? theme.colorScheme.outlineVariant
                                : theme.colorScheme.primary,
                      ),
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (names.isEmpty) return 'AI 回复';
    return names.length == 1 ? names.first : 'AI 回复';
  }

  Widget _buildBubble({
    required String content,
    required bool isUser,
    String? agentName,
    String? status,
    String type = 'text',
    String? audioPath,
    int? audioDurationSec,
  }) {
    final theme = Theme.of(context);
    final isThinking = status == 'thinking';
    final isError = status == 'error';

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isUser
                ? theme.colorScheme.primary
                : isError
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isUser ? 14 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 14),
        ),
      ),
      child:
          type == 'audio' && audioPath != null
          ? AudioPlayerWidget(
              audioPath: audioPath,
              durationInSeconds: audioDurationSec ?? 0,
              primaryColor: theme.colorScheme.primary,
            )
          : isThinking
          ? Text(
              '正在想…',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            )
          : Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color:
                    isUser
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser && agentName != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                agentName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          bubble,
        ],
      ),
    );
  }
}
