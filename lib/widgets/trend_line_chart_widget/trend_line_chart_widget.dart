/// 趋势折线图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题 / 翻牌计数器 / 折线图（数据色平直折线 +
/// 线下数据色浅底斜纹面积填充 + 淡墨虚线网格）/ 时间轴标签。
/// 折线描画与数值动画保留。
library;

import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 趋势折线图小组件
///
/// 一个带有动画效果的折线图组件，支持显示标题、图标、数值和时间轴标签。
/// 适用于展示温度、价格、指标等带有时间趋势的数据。
///
/// 示例用法：
/// ```dart
/// TrendLineChartWidget(
///   title: 'Temperature',
///   icon: Icons.thermostat,
///   value: 4.875,
///   dataPoints: [
///     Offset(5, 90),
///     Offset(15, 85),
///     // ... 更多数据点
///   ],
///   timeLabels: ['8:00am', '10:00am', '12:00am', '1:00pm', '3:00pm'],
///   primaryColor: Color(0xFF0284C7),
///   valueColor: Color(0xFF2563EB),
/// )
/// ```
class TrendLineChartWidget extends StatefulWidget {
  /// 标题
  final String title;

  /// 图标
  final IconData icon;

  /// 显示的数值
  final double value;

  /// 数据点坐标（相对坐标，0-320范围）
  ///
  /// X 轴范围：0-320，Y 轴范围：0-120
  /// 数据点会根据容器大小自动缩放
  final List<Offset> dataPoints;

  /// 时间轴标签
  ///
  /// 显示在折线图下方的标签列表
  final List<String> timeLabels;

  /// 主色调
  ///
  /// 用于折线图的渐变色起始和结束
  final Color primaryColor;

  /// 数值颜色（用于渐变中间色）
  ///
  /// 如果为 null，则使用 primaryColor
  final Color? valueColor;

  /// 菜单按钮点击回调
  final VoidCallback? onMenuPressed;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const TrendLineChartWidget({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.dataPoints,
    required this.timeLabels,
    required this.primaryColor,
    this.valueColor,
    this.onMenuPressed,
    this.size = const MediumSize(),
  });

  @override
  State<TrendLineChartWidget> createState() => _TrendLineChartWidgetState();
}

class _TrendLineChartWidgetState extends State<TrendLineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 根据 size 计算尺寸
    final iconSize = widget.size.getIconSize();
    final iconContainerSize = iconSize * widget.size.iconContainerScale;
    final titleFontSize = widget.size.getTitleFontSize();
    final valueFontSize = widget.size.getLargeFontSize() * 0.35;
    final titleSpacing = widget.size.getTitleSpacing();
    final timeLabelFontSize = widget.size.getLegendFontSize();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                // 手绘圆形图标徽章
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(iconContainerSize / 2),
                    fillColor: theme.surfaceAlt,
                  ),
                  child: Center(
                    child: WiredIcon(
                      icon: widget.icon,
                      size: iconSize,
                      color: theme.primary,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  ),
                ),
                SizedBox(width: widget.size.getSmallSpacing() * 2),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                _MenuButton(
                  theme: theme,
                  size: widget.size,
                  onPressed: widget.onMenuPressed,
                ),
              ],
            ),
            SizedBox(height: widget.size.getSmallSpacing() * 2),
            // 数值显示
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => AnimatedFlipCounter(
                value: widget.value * _animation.value,
                fractionDigits: widget.value % 1 != 0 ? 3 : 0,
                textStyle: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  letterSpacing: -2,
                ),
              ),
            ),
            SizedBox(height: titleSpacing),
            // 折线图 - 使用 Expanded 自动填充剩余高度
            Expanded(
              child: _LineChart(
                dataPoints: widget.dataPoints,
                primaryColor: widget.primaryColor,
                animation: _animation,
                theme: theme,
                size: widget.size,
              ),
            ),
            SizedBox(height: widget.size.getSmallSpacing()),
            // 时间轴标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: widget.timeLabels.map((label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: timeLabelFontSize,
                        fontWeight: FontWeight.w500,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单按钮（手绘圆形徽章 + 手绘竖三点图标）
class _MenuButton extends StatelessWidget {
  final AppThemeData theme;
  final VoidCallback? onPressed;
  final HomeWidgetSize size;

  const _MenuButton({required this.theme, this.onPressed, required this.size});

  @override
  Widget build(BuildContext context) {
    final iconSize = size.getIconSize();
    final containerSize = iconSize * size.iconContainerScale * 0.5;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(containerSize / 2),
        fillColor: theme.surfaceAlt,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: DsIcon(
              DsIconKind.dots,
              color: theme.textSub,
              size: iconSize * 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// 折线图组件（数据色平直折线 + 线下斜纹面积 + 淡墨虚线网格）
class _LineChart extends StatelessWidget {
  final List<Offset> dataPoints;
  final Color primaryColor;
  final Animation<double> animation;
  final AppThemeData theme;
  final HomeWidgetSize size;

  const _LineChart({
    required this.dataPoints,
    required this.primaryColor,
    required this.animation,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _LineChartPainter(
                dataPoints: dataPoints,
                progress: animation.value,
                primaryColor: primaryColor,
                strokeWidth: size.getStrokeWidth() * 0.5,
                gridStrokeWidth: size.getStrokeWidth() * 0.1875,
                gridColor: theme.ink.withValues(alpha: 0.18),
                graphWidth: 320,
                graphHeight: 120,
                scale: size.scale,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 折线图画笔
///
/// 淡墨虚线网格 + 数据色平直折线（原渐变描边 → 平直数据色），
/// 线下面积用数据色浅底 + 淡斜纹填充（§9.5，样板手法）。
class _LineChartPainter extends CustomPainter {
  final List<Offset> dataPoints;
  final double progress;
  final Color primaryColor;
  final double strokeWidth;
  final double gridStrokeWidth;
  final Color gridColor;
  final double graphWidth;
  final double graphHeight;
  final double scale;

  _LineChartPainter({
    required this.dataPoints,
    required this.progress,
    required this.primaryColor,
    required this.strokeWidth,
    required this.gridStrokeWidth,
    required this.gridColor,
    required this.graphWidth,
    required this.graphHeight,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    // 绘制水平网格线（淡墨虚线）
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = gridStrokeWidth;

    const gridLines = 4;
    for (int i = 1; i <= gridLines; i++) {
      final y = (size.height / gridLines) * i;
      for (var x = 8.0; x < size.width; x += 10 * scale) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5 * scale, size.width), y),
          gridPaint,
        );
      }
    }

    // 计算点的位置
    final scaleX = size.width / graphWidth;
    final scaleY = size.height / graphHeight;
    final points = [
      for (final point in dataPoints) Offset(point.dx * scaleX, point.dy * scaleY),
    ];

    // 计算当前动画应该绘制到第几个点
    final totalSegments = points.length - 1;
    final currentSegment = (totalSegments * progress).floor();
    final segmentProgress = (totalSegments * progress) - currentSegment;

    // 折线到当前进度位置的终点（含线段内插值）
    Offset endPoint(int index) => points[index.clamp(0, points.length - 1)];
    Offset partialEnd() {
      if (currentSegment >= totalSegments) return points.last;
      final start = points[currentSegment];
      final next = points[currentSegment + 1];
      return Offset(
        start.dx + (next.dx - start.dx) * segmentProgress,
        start.dy + (next.dy - start.dy) * segmentProgress,
      );
    }
    final lineEnd = currentSegment >= totalSegments
        ? points.last
        : partialEnd();

    // 线下斜纹面积填充（数据色浅底 + 数据色淡斜纹）
    if (points.isNotEmpty) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i <= currentSegment && i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.lineTo(lineEnd.dx, lineEnd.dy);
      fillPath.lineTo(endPoint(currentSegment).dx, size.height);
      fillPath.lineTo(points.first.dx, size.height);
      fillPath.close();

      canvas.drawPath(
        fillPath,
        Paint()..color = primaryColor.withValues(alpha: 0.28),
      );
      paintDiagonalStripes(
        canvas,
        fillPath,
        fillPath.getBounds(),
        color: primaryColor.withValues(alpha: 0.5),
        strokeWidth: 1.5 * scale,
        spacing: 6.5 * scale,
      );
    }

    // 绘制折线（平直干净的数据色描边，随进度生长）
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i <= currentSegment && i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(lineEnd.dx, lineEnd.dy);

    final paint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.scale != scale;
  }
}
