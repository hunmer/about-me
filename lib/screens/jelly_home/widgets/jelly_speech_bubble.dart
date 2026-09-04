import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 角色头顶的对话气泡：白色胶囊 + 下垂小尾巴
///
/// 胶囊与尾巴合并为同一路径一次填充/描边（Path union），
/// 不会有「底边描边穿过尾巴根部」的接缝横线。
///
/// 文本带打字机效果（逐字浮现），全部浮现后回调 [onTypingComplete]，
/// 由宿主决定何时收起气泡。
class JellySpeechBubble extends StatelessWidget {
  const JellySpeechBubble({
    super.key,
    required this.text,
    this.onTap,
    this.onTypingComplete,
    this.typingInterval = const Duration(milliseconds: 110),
  });

  final String text;
  final VoidCallback? onTap;

  /// 打字效果完成后回调一次（用于延迟隐藏气泡）
  final VoidCallback? onTypingComplete;

  /// 每个字的浮现间隔
  final Duration typingInterval;

  /// 尾巴高度（画在胶囊边界之外，下方 Padding 负责占位）
  static const double tailHeight = 13;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final bubble = Padding(
      padding: const EdgeInsets.only(bottom: tailHeight + 2),
      child: CustomPaint(
        painter: _BubblePainter(
          fill: theme.surface,
          line: theme.primary.withValues(alpha: 0.30),
          shadows: theme.shadows.soft,
          tailHeight: tailHeight,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xl,
            vertical: theme.spacing.md,
          ),
          child: TypewriterText(
            text,
            interval: typingInterval,
            onComplete: onTypingComplete,
            style: DsTypography.button.copyWith(
              fontSize: 15,
              color: theme.primaryText,
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return bubble;
    return Pressable(
      onPressed: onTap,
      builder:
          (context, states) =>
              states.contains(WidgetState.pressed)
                  ? Opacity(opacity: 0.85, child: bubble)
                  : bubble,
    );
  }
}

/// 胶囊 + 尾巴一体绘制：
/// 先 Path.union 合并两个子路径，再依次画阴影、填充、描边——
/// 描边沿合并后的外轮廓走一圈，尾巴与胶囊天然无缝。
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.fill,
    required this.line,
    required this.shadows,
    required this.tailHeight,
  });

  final Color fill;
  final Color line;
  final List<BoxShadow> shadows;
  final double tailHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );

    // 尾巴根部往胶囊里压 2px，保证 union 后完全一体
    final baseY = size.height - 2;
    final tipX = size.width * 0.44;
    final tipY = size.height + tailHeight;
    const halfTail = 13.0;
    final tail =
        Path()
          ..moveTo(size.width / 2 - halfTail, baseY)
          ..quadraticBezierTo(
            tipX - 4,
            baseY + tailHeight * 0.6,
            tipX,
            tipY,
          )
          ..quadraticBezierTo(
            tipX + 8,
            baseY + tailHeight * 0.5,
            size.width / 2 + halfTail,
            baseY,
          )
          ..close();

    final shape = Path.combine(PathOperation.union, capsule, tail);

    for (final shadow in shadows) {
      canvas.drawPath(
        shape.shift(shadow.offset),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.line != line ||
      oldDelegate.tailHeight != tailHeight;
}

/// 逐字浮现的文本（打字机效果）
class TypewriterText extends StatefulWidget {
  const TypewriterText(
    this.text, {
    super.key,
    this.style,
    this.interval = const Duration(milliseconds: 110),
    this.onComplete,
  });

  final String text;
  final TextStyle? style;
  final Duration interval;

  /// 全部字符浮现完毕后回调一次
  final VoidCallback? onComplete;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(_restart);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _shown = 0;
    if (widget.text.isEmpty) {
      widget.onComplete?.call();
      return;
    }
    _timer = Timer.periodic(widget.interval, _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    setState(() => _shown++);
    if (_shown >= widget.text.length) {
      timer.cancel();
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(
      0,
      _shown.clamp(0, widget.text.length),
    );
    return Text(visible, style: widget.style);
  }
}
