import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 分隔线风格
enum DsDividerStyle {
  /// 五段不等宽墨点（默认，一顿一顿的手绘断线）
  dots,

  /// 虚线（画 7 空 5）
  dashed,

  /// rough 实线（skribble 手绘直线）
  plain,
}

/// 手绘分隔线：内容分组之间的墨线
///
/// 横向默认，[vertical] 为 true 时竖向；[label] 显示在中间
/// （两侧各留一段墨线）；[color] 覆写墨线色（默认主题墨线低透明度）。
///
/// ```dart
/// Column(children: [
///   const Text('今日记录'),
///   const DSDivider(), // dots
///   ...
///   const DSDivider(style: DsDividerStyle.dashed, label: '共 12 条'),
///   ...
///   const DSDivider(vertical: true), // Row 内当竖线用
/// ])
/// ```
class DSDivider extends StatelessWidget {
  const DSDivider({
    super.key,
    this.style = DsDividerStyle.dots,
    this.vertical = false,
    this.label,
    this.color,
  });

  final DsDividerStyle style;

  /// 竖向分隔线（在 Row 中使用）
  final bool vertical;

  /// 中间文字：两侧各留一段墨线（null 时整条贯通）
  final String? label;

  /// 墨线颜色覆写（默认 theme.ink @ 0.35）
  final Color? color;

  /// 组件主轴厚度：约等于墨点直径，保证横竖两个方向排版稳定
  static const double _thickness = 9;

  /// dots 风格的五段不等宽墨点（与菜单分组分隔线同一节奏）
  static const List<double> _dotSegments = [14.0, 10.0, 16.0, 8.0, 12.0];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final ink = color ?? theme.ink.withValues(alpha: 0.35);

    final Widget line = switch (style) {
      DsDividerStyle.dots => _buildDots(ink),
      DsDividerStyle.dashed => CustomPaint(
        size: vertical
            ? const Size(1, double.infinity)
            : const Size(double.infinity, 1),
        painter: _DashedLinePainter(color: ink, vertical: vertical),
      ),
      DsDividerStyle.plain => CustomPaint(
        size: vertical
            ? const Size(1, double.infinity)
            : const Size(double.infinity, 1),
        painter: _RoughLinePainter(
          color: ink,
          vertical: vertical,
          strokeWidth: theme.wired.strokeWidth,
          drawConfig: theme.wired.drawConfig,
        ),
      ),
    };

    if (label == null) {
      // 无文字：整条线贯通（撑满给到的空间）
      return SizedBox(
        width: vertical ? _thickness : double.infinity,
        height: vertical ? double.infinity : _thickness,
        child: SizedBox.expand(child: line),
      );
    }

    // 带文字：两侧（上下）各一段线，中间留出间隙；
    // 线段经 Expanded 撑满主轴，交叉轴居中对齐（不能用 stretch——
    // 在无界交叉轴约束下会把 infinite 高度强塞给子节点）
    final gap = SizedBox(
      width: vertical ? 0 : theme.spacing.sm,
      height: vertical ? theme.spacing.sm : 0,
    );
    final labelWidget = Text(
      label!,
      style: DsTypography.caption.copyWith(color: theme.textSub),
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Center(child: line)),
          gap,
          labelWidget,
          gap,
          Expanded(child: Center(child: line)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Center(child: line)),
        gap,
        labelWidget,
        gap,
        Expanded(child: Center(child: line)),
      ],
    );
  }

  /// dots：五段不等宽墨点，在可用空间内散布（spaceBetween）
  Widget _buildDots(Color ink) {
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final w in _dotSegments)
          vertical
              ? Container(width: 2, height: w, decoration: _dot(ink))
              : Container(width: w, height: 2, decoration: _dot(ink)),
      ],
    );
  }

  BoxDecoration _dot(Color ink) => BoxDecoration(
    color: ink,
    borderRadius: BorderRadius.circular(1),
  );
}

/// 「画 7 空 5」虚线（横/竖），线宽 1.6、round cap
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color, required this.vertical});

  final Color color;
  final bool vertical;

  static const double _strokeWidth = 1.6;
  static const double _dashLength = 7;
  static const double _gapLength = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..color = color;
    final total = vertical ? size.height : size.width;
    final cross = _strokeWidth / 2;
    var distance = 0.0;
    var drawing = true;
    while (distance < total) {
      final segment = drawing ? _dashLength : _gapLength;
      final next = math.min(distance + segment, total);
      if (drawing) {
        final start = vertical
            ? Offset(cross, distance)
            : Offset(distance, size.height / 2);
        final end = vertical
            ? Offset(cross, next)
            : Offset(next, size.height / 2);
        canvas.drawLine(start, end, paint);
      }
      distance = next;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.vertical != vertical;
}

/// rough 实线：Generator.line 生成，随全局墨线风格（笔宽/粗糙度/笔型）
///
/// 固定 seed + randomizer.reset()：rebuild 时墨迹不抖变；
/// 尺寸变化才重新生成。
class _RoughLinePainter extends CustomPainter {
  _RoughLinePainter({
    required this.color,
    required this.vertical,
    required this.strokeWidth,
    required this.drawConfig,
  });

  final Color color;
  final bool vertical;
  final double strokeWidth;
  final DrawConfig drawConfig;

  Size? _size;
  RoughDrawing? _drawing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size || _drawing == null) {
      drawConfig.randomizer.reset();
      final generator = Generator(drawConfig, NoFiller());
      final drawable = vertical
          ? generator.line(size.width / 2, 0, size.width / 2, size.height)
          : generator.line(
              0,
              size.height / 2,
              size.width,
              size.height / 2,
            );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = color;
      _drawing = RoughDrawing(drawable, paint, paint);
      _size = size;
    }
    _drawing!.paint(canvas);
  }

  @override
  bool shouldRepaint(_RoughLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.vertical != vertical ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.drawConfig != drawConfig;
}
