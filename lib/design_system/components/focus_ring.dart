import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';

/// 手绘焦点环：键盘聚焦（focus-visible 语义）时的虚线墨环
///
/// [Pressable] 已把 focused 收集进 states，本组件负责视觉——
/// 在子元素外圈 [gap] 处画一圈「画 5 空 4」虚线（宽 1.6，
/// 与 [DsSketchPanel.dashedStroke] 同款笔触），色默认主题墨线。
///
/// 纯装饰层：IgnorePointer、不参与布局（Stack 溢出绘制，
/// 上层不能有裁剪）。典型用法：
/// ```dart
/// Pressable(builder: (context, states) => DsFocusRing(
///   show: states.contains(WidgetState.focused),
///   child: ...,
/// ))
/// ```
class DsFocusRing extends StatelessWidget {
  const DsFocusRing({
    super.key,
    required this.child,
    this.show = false,
    this.radius,
    this.gap = 3,
    this.color,
  });

  final Widget child;

  /// 是否显示焦点环（false 时淡出，不参与命中测试）
  final bool show;

  /// 子元素圆角（环的圆角自动补上 [gap]）
  final BorderRadiusGeometry? radius;

  /// 环到子元素边缘的间距
  final double gap;

  /// 环色（null = 主题墨线）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final r = (radius ?? theme.radii.sm)
        .resolve(Directionality.maybeOf(context));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: show ? 1 : 0,
              duration: DsMotion.fast,
              curve: DsMotion.curve,
              child: CustomPaint(
                painter: _FocusRingPainter(
                  color: color ?? theme.ink,
                  radius: r,
                  gap: gap,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 沿子元素边界外扩 [gap] 画虚线圆角框
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.color,
    required this.radius,
    required this.gap,
  });

  final Color color;
  final BorderRadius radius;
  final double gap;

  static const double _strokeWidth = 1.6;
  static const double _dashLength = 5;
  static const double _gapLength = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = _strokeWidth / 2 + gap;
    final rect = (Offset.zero & size).inflate(gap).deflate(0);
    final rrect = BorderRadius.only(
      topLeft: Radius.circular(radius.topLeft.x + gap - half / 2),
      topRight: Radius.circular(radius.topRight.x + gap - half / 2),
      bottomRight: Radius.circular(radius.bottomRight.x + gap - half / 2),
      bottomLeft: Radius.circular(radius.bottomLeft.x + gap - half / 2),
    ).toRRect(rect.deflate(half));

    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final segment = drawing ? _dashLength : _gapLength;
        final next = math.min(distance + segment, metric.length);
        if (drawing) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        drawing = !drawing;
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..color = color.withValues(alpha: 0.9);
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.gap != gap;
}
