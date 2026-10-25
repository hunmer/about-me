import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Value;
import 'package:skribble/skribble.dart' show WiredDraw, WiredDrawTransition;

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/markdown_content.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
import 'package:aboutme/plugins/chat/widgets/audio_player_widget.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/aliveness/channels/chat_aliveness_channel.dart';
import 'package:aboutme/plugins/openai/handlers/chat_event_handler.dart'
    show submitAutoReplyThreadMessage;
import 'package:aboutme/widgets/message_input/message_input.dart';

/// AI 回复线程的底部 drawer 简易聊天界面：
/// 气泡消息（根消息 + 线程内多轮）+ 输入框续聊（走同一套活人感编排）。
///
/// 手绘纸墨风（design.md §9）：面板走 DsSketchPanel（纸底 + 排线 +
/// 墨线框），气泡走 dsSketchDecoration 实底墨线描边。
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
      Toast.error('chat_threadSendFailed'.trParams({'error': '$e'}));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = AiThreadService.instance.getThread(widget.rootMessage.id);
    final theme = DSThemeBridge.resolve(context);
    final mq = MediaQuery.of(context);

    final title = _resolveTitle(thread);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: DSThemeBridge(
        // 打开 drawer 时墨线描画入场（design.md §10）
        child: WiredDraw(
          child: DsSketchPanel(
            theme: theme,
            // 键盘弹出时压缩高度，保证输入行可见
            height: (mq.size.height * 0.78 - mq.viewInsets.bottom).clamp(
              300.0,
              mq.size.height * 0.85,
            ),
            radius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          color: theme.ink.withValues(alpha: 0.35),
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
                                style: DsTypography.title.copyWith(
                                  color: theme.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (thread?.isThinking == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  'chat_threadTyping'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.primary,
                                  ),
                                ),
                              ),
                            DSIconButton(
                              icon: DsIconKind.close,
                              size: 36,
                              color: theme.surface,
                              iconColor: theme.text,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _SketchDivider(color: theme.ink.withValues(alpha: 0.35)),
                  // 消息列表（聊天流不套便签化，design.md §11.4）
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
                                    seedId: widget.rootMessage.id,
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
                                  seedId: msg.id,
                                );
                              },
                            ),
                  ),
                  // 输入行（复用通用 MessageInput：手绘面板 + 底部安全区）
                  MessageInput(
                    controller: _inputController,
                    hintText: 'chat_threadInputHint'.tr,
                    onSend: _sending ? null : _send,
                    useSketchPanel: true,
                  ),
                ],
              ),
            ),
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
    if (names.isEmpty) return 'chat_threadTitle'.tr;
    return names.length == 1 ? names.first : 'chat_threadTitle'.tr;
  }

  Widget _buildBubble({
    required String content,
    required bool isUser,
    required String seedId,
    String? agentName,
    String? status,
    String type = 'text',
    String? audioPath,
    int? audioDurationSec,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final isThinking = status == 'thinking';
    final isError = status == 'error';

    // 自己的消息实底主色，AI 消息次级纸面，出错淡红底（design.md §9.1）
    final bgColor =
        isUser
            ? theme.primary
            : isError
            ? theme.danger.mixWhite(0.82)
            : theme.surfaceAlt;
    final fgColor = isUser ? theme.onPrimary : isError ? theme.danger : theme.text;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: bgColor,
        radius: BorderRadius.circular(16),
        seed: seedId.hashCode & 0x7fffffff,
        progress: WiredDrawTransition.progressOf(context),
      ),
      child:
          type == 'audio' && audioPath != null
          ? AudioPlayerWidget(
              audioPath: audioPath,
              durationInSeconds: audioDurationSec ?? 0,
              primaryColor: theme.primary,
            )
          : isThinking
          ? Text(
              'chat_threadThinking'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            )
          : isUser
          ? Text(
              content,
              style: DsTypography.body.copyWith(color: fgColor),
            )
          // AI 回复可能含 markdown（代码块/列表等），与 agent_chat 消息渲染保持一致
          : MarkdownContent(content: content, textColor: fgColor),
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
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ),
          bubble,
        ],
      ),
    );
  }
}

/// 手绘虚线分隔线：断续墨线段替代 Material Divider（design.md §9.3）
class _SketchDivider extends StatelessWidget {
  const _SketchDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final w in const [22.0, 14.0, 30.0, 18.0, 24.0, 12.0])
            Container(
              width: w,
              height: 2,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
