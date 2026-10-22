/// 收益趋势卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 + 金额（翻牌计数器）/ 涨幅徽章（墨线圆底）/ 底部水印折线图
/// （数据色平直折线 + 斜纹面积填充）。折线描画与数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 收益趋势卡片小组件
///
/// 用于显示收益趋势的卡片组件，支持：
/// - 货币数值显示（带动画计数）
/// - 百分比变化徽章
/// - 折线图（带斜纹面积填充）
class EarningsTrendCardWidget extends StatefulWidget {
  /// 标题文本
  final String title;

  /// 主要数值
  final double value;

  /// 货币符号
  final String currency;

  /// 百分比变化
  final double percentage;

  /// 图表数据点（Y坐标值，0-120范围）
  final List<double> chartData;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const EarningsTrendCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.currency,
    required this.percentage,
    required this.chartData,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于小组件系统）
  factory EarningsTrendCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return EarningsTrendCardWidget(
      title: props['title'] as String? ?? 'Earnings',
      value: (props['value'] as num?)?.toDouble() ?? 0.0,
      currency: props['currency'] as String? ?? '\$',
      percentage: (props['percentage'] as num?)?.toDouble() ?? 0.0,
      chartData: (props['chartData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0, 0, 0, 0, 0],
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<EarningsTrendCardWidget> createState() =>
      _EarningsTrendCardWidgetState();
}

class _EarningsTrendCardWidgetState extends State<EarningsTrendCardWidget>
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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 340,
        height: widget.inline ? double.maxFinite : 280,
        radius: BorderRadius.circular(24 * scale),
        child: Stack(
          children: [
            // Chart section - 固定在底部作为背景
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.4,
                child: SizedBox(
                  height: widget.size.getStrokeWidth() * 25,
                  width: double.infinity,
                  child: _LineChart(
                    data: widget.chartData,
                    animation: _animation,
                    size: widget.size,
                  ),
                ),
              ),
            ),

            // Title and value section - 显示在图表上方
            Padding(
              padding: EdgeInsets.only(
                top: widget.size.getTitleSpacing() * 0.6,
              ),
              child: Padding(
                padding: widget.size.getPadding(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: theme.textSub,
                        fontSize: widget.size.getSubtitleFontSize() * 0.9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: widget.size.getItemSpacing() * 0.75),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedFlipCounter(
                          value: widget.value * _animation.value,
                          fractionDigits: 1,
                          textStyle: TextStyle(
                            color: theme.text,
                            fontSize: widget.size.getLargeFontSize() * 0.7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          widget.currency,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: widget.size.getLargeFontSize() * 0.6,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.size.getItemSpacing() * 1.5),
                    _PercentageBadge(
                      percentage: widget.percentage,
                      animation: _animation,
                      size: widget.size,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 百分比徽章（墨线圆底 + 手绘箭头，主题语义色）
class _PercentageBadge extends StatelessWidget {
  final double percentage;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _PercentageBadge({
    required this.percentage,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final badgeAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: badgeAnimation,
      builder: (context, child) {
        return Transform.scale(scale: badgeAnimation.value, child: child);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.getItemSpacing() * 1.5,
          vertical: size.getItemSpacing() * 0.75,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(20),
          fillColor: theme.surfaceAlt,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WiredIcon(
              icon: Icons.arrow_upward,
              size: size.getIconSize() * 0.8,
              color: theme.success,
              drawConfig: theme.wired.drawConfig,
            ),
            SizedBox(width: size.getItemSpacing() * 0.5),
            Text(
              '+${percentage.toStringAsFixed(2)}%',
              style: TextStyle(
                color: theme.success,
                fontSize: size.getLegendFontSize() * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 折线图
class _LineChart extends StatelessWidget {
  final List<double> data;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _LineChart({
    required this.data,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final chartAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: chartAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _LineChartPainter(
            data: data,
            progress: chartAnimation.value,
            lineColor: theme.primary,
            strokeWidth: size.getStrokeWidth() * 0.4,
            scale: size.scale,
          ),
        );
      },
    );
  }
}

/// 折线图画笔
///
/// 数据色平直折线（无 rough 抖动），线下面积用数据色浅底 + 淡斜纹填充
/// （§9.5，替代原渐变）。
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final double progress;
  final Color lineColor;
  final double strokeWidth;
  final double scale;

  _LineChartPainter({
    required this.data,
    required this.progress,
    required this.lineColor,
    required this.strokeWidth,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = 10.0;
    final chartWidth = size.width;
    final chartHeight = size.height - padding * 2;
    final denom = data.length > 1 ? data.length - 1 : 1;
    final stepX = chartWidth / denom;

    // 计算数据点位置
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = 1 - (data[i] / 120); // 归一化到 0-1
      final y = normalizedY * chartHeight + padding;
      points.add(Offset(x, y));
    }

    // 平直折线（数据色，两侧向外出血）
    final linePath = Path();
    linePath.moveTo(-10, points[0].dy);
    for (final point in points) {
      linePath.lineTo(point.dx, point.dy);
    }
    linePath.lineTo(size.width + 10, points.last.dy);

    // 线下斜纹面积（数据色浅底 + 淡斜纹）
    final fillPath = Path.from(linePath);
    fillPath.lineTo(size.width + 10, size.height);
    fillPath.lineTo(-10, size.height);
    fillPath.close();

    // 描线动画：按进度裁剪
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
    );

    canvas.drawPath(
      fillPath,
      Paint()..color = lineColor.withValues(alpha: 0.28),
    );
    paintDiagonalStripes(
      canvas,
      fillPath,
      fillPath.getBounds(),
      color: lineColor.withValues(alpha: 0.45),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );

    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.scale != scale;
  }
}
