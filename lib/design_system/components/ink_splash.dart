import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';

/// 墨点扩散：勾选/点亮瞬间的一次性六点爆发反馈
///
/// 手绘化的「splash」——六个小墨点自中心向 60° 均分方向飞散并淡出，
/// 画在元素墨线之上。纯装饰：不参与命中测试与布局占位。
///
/// 用法：放在 `Stack(clipBehavior: Clip.none)` 内的 [Positioned.fill]，
/// [trigger] 传会变化的状态（选中 bool / 数值），变化即重播一次：
/// ```dart
/// Stack(clipBehavior: Clip.none, children: [
///   checkbox,
///   Positioned.fill(child: DsInkSplash(trigger: value, color: theme.primary)),
/// ])
/// ```
class DsInkSplash extends StatefulWidget {
  const DsInkSplash({
    super.key,
    this.trigger,
    this.color,
    this.duration = const Duration(milliseconds: 600),
    this.distance = 34,
    this.dotSize = 4,
  });

  /// 触发源：与旧值不等即重播（null 的首次 build 不播）
  final Object? trigger;

  /// 墨点颜色（null = 透明，等于禁用）
  final Color? color;

  final Duration duration;

  /// 飞散距离（自元素中心起算，元素外的部分靠上层不裁剪）
  final double distance;

  final double dotSize;

  @override
  State<DsInkSplash> createState() => _DsInkSplashState();
}

class _DsInkSplashState extends State<DsInkSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(DsInkSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        widget.color != null &&
        !context.dsAnimationsDisabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    if (color == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _InkSplashPainter(
            color: color,
            progress: _controller.value,
            distance: widget.distance,
            dotSize: widget.dotSize,
          ),
        ),
      ),
    );
  }
}

/// 六点扩散：位置 easeOut、透明度线性淡出、点径微缩
class _InkSplashPainter extends CustomPainter {
  const _InkSplashPainter({
    required this.color,
    required this.progress,
    required this.distance,
    required this.dotSize,
  });

  final Color color;
  final double progress;
  final double distance;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final t = Curves.easeOut.transform(progress);
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 1 - progress)
      ..isAntiAlias = true;
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      final r = dotSize + t * distance;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * r,
        dotSize * (1 - 0.4 * t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_InkSplashPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.distance != distance ||
      oldDelegate.dotSize != dotSize;
}
