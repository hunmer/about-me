import 'package:flutter/material.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/ai_thread_drawer.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 用户消息时间戳行内的 AI 评论入口（MessageTimestamp 左侧）：
/// 生成中显示「[agent] 正在评论…」，完成后仅显示图标 + 回复条数，
/// 点击弹出底部 drawer 查看与续聊。
class AiThreadEntry extends StatefulWidget {
  final Message message;

  const AiThreadEntry({super.key, required this.message});

  @override
  State<AiThreadEntry> createState() => _AiThreadEntryState();
}

class _AiThreadEntryState extends State<AiThreadEntry> {
  late String _subscriptionId;
  int _version = 0;

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
    if (args.value != widget.message.id) return;
    if (mounted) {
      setState(() => _version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = AiThreadService.instance.getThread(widget.message.id);
    if (thread == null) return const SizedBox.shrink();

    final replyCount = thread.replyCount;
    final isThinking = thread.isThinking;
    if (replyCount == 0 && !isThinking) return const SizedBox.shrink();

    final agentName =
        thread.messages
            .map((m) => m.agentName)
            .whereType<String>()
            .firstOrNull ??
        'AI';
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: replyCount > 0 ? () => _openDrawer(context, thread) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isThinking ? Icons.more_horiz : Icons.chat_bubble_outline,
              size: 13,
              color: primary,
            ),
            const SizedBox(width: 3),
            if (isThinking) ...[
              Text(
                '[$agentName] 正在评论',
                style: TextStyle(
                  fontSize: 11,
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              _TypingText(color: primary),
            ] else
              Text(
                '$replyCount',
                style: TextStyle(
                  fontSize: 11,
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openDrawer(BuildContext context, AiThread thread) {
    // AiThreadDrawer 自带表面/高度/拖拽条，外壳保持透明并关闭默认拖拽条
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (_) => AiThreadDrawer(rootMessage: widget.message),
    );
  }
}

/// "正在输入…"三点呼吸动画
class _TypingText extends StatefulWidget {
  final Color color;

  const _TypingText({required this.color});

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * 3;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = (phase - i).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: 0.3 + 0.7 * active,
                child: Icon(Icons.circle, size: 5, color: widget.color),
              ),
            );
          }),
        );
      },
    );
  }
}
