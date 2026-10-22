/// 收入趋势小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 周期筛选 / 金额（翻牌计数器）/ 折线图（数据色平直折线 + 斜纹面积
/// 填充 + 高亮纸底圆点）/ 日期标签。折线描画与数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 收入趋势小组件
class RevenueTrendCardWidget extends StatefulWidget {
  /// 主要数值
  final double value;

  /// 货币符号
  final String currency;

  /// 百分比变化
  final int percentage;

  /// 时间周期文本
  final String period;

  /// 图表数据点（Y坐标值，0-120范围）
  final List<double> chartData;

  /// 日期标签
  final List<int> dates;

  /// 高亮点的索引
  final int highlightIndex;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const RevenueTrendCardWidget({
    super.key,
    required this.value,
    required this.currency,
    required this.percentage,
    required this.period,
    required this.chartData,
    required this.dates,
    required this.highlightIndex,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory RevenueTrendCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return RevenueTrendCardWidget(
      value: (props['value'] as num?)?.toDouble() ?? 0.0,
      currency: props['currency'] as String? ?? '\$',
      percentage: props['percentage'] as int? ?? 0,
      period: props['period'] as String? ?? 'Weekly',
      chartData:
          (props['chartData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [0, 0, 0, 0, 0],
      dates:
          (props['dates'] as List<dynamic>?)?.map((e) => e as int).toList() ??
          [1, 2, 3, 4, 5],
      highlightIndex: props['highlightIndex'] as int? ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<RevenueTrendCardWidget> createState() => _RevenueTrendCardWidgetState();
}

class _RevenueTrendCardWidgetState extends State<RevenueTrendCardWidget>
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
        height: widget.inline ? double.maxFinite : 400,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          children: [
            // 时间筛选按钮
            _PeriodSelector(period: widget.period, size: widget.size),

            // 金额和百分比
            _ValueSection(
              currency: widget.currency,
              value: widget.value,
              percentage: widget.percentage,
              animation: _animation,
              size: widget.size,
            ),

            // 曲线图和日期标签（支持横向滚动）
            _ScrollableChartSection(
              chartData: widget.chartData,
              dates: widget.dates,
              highlightIndex: widget.highlightIndex,
              animation: _animation,
              size: widget.size,
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间周期选择器
class _PeriodSelector extends StatelessWidget {
  final String period;
  final HomeWidgetSize size;

  const _PeriodSelector({required this.period, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.getItemSpacing(),
            vertical: size.getItemSpacing() / 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                period,
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: size.getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: size.getItemSpacing() / 2),
              DsIcon(
                DsIconKind.chevronDown,
                size: size.getIconSize() * 0.7,
                color: theme.textSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数值显示区域
class _ValueSection extends StatelessWidget {
  final String currency;
  final double value;
  final int percentage;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _ValueSection({
    required this.currency,
    required this.value,
    required this.percentage,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final valueAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
    );

    final valueSectionHeight = size.getLargeFontSize() * 0.9;
    final currencyHeight = size.getLargeFontSize() * 0.8;

    return AnimatedBuilder(
      animation: valueAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // 金额显示
            SizedBox(
              height: valueSectionHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: currencyHeight,
                    child: Text(
                      currency,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: size.getLargeFontSize() * 0.6,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: valueSectionHeight,
                    child: AnimatedFlipCounter(
                      value: value * valueAnimation.value,
                      fractionDigits: 2,
                      textStyle: TextStyle(
                        color: theme.text,
                        fontSize: size.getLargeFontSize() * 0.8,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 折线图表（含日期标签）
class _CurveChart extends StatelessWidget {
  final List<double> data;
  final List<int> dates;
  final Animation<double> animation;
  final int highlightIndex;
  final HomeWidgetSize size;
  final bool isScrollable;
  final double contentWidth;
  final double height;

  const _CurveChart({
    required this.data,
    required this.dates,
    required this.animation,
    required this.highlightIndex,
    required this.size,
    this.isScrollable = false,
    this.contentWidth = double.infinity,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final chartAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
    );
    final labelsAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(isScrollable ? contentWidth : double.infinity, height),
          painter: _CurveChartPainter(
            data: data,
            dates: dates,
            progress: chartAnimation.value,
            labelsProgress: labelsAnimation.value,
            lineColor: theme.primary,
            labelColor: theme.textSub,
            surfaceColor: theme.surface,
            highlightIndex: highlightIndex,
            strokeWidth: size.getStrokeWidth() * size.progressStrokeScale,
            haloRadius: size.getIconSize(),
            highlightRadius: size.getIconSize() * 0.35,
            legendFontSize: size.getLegendFontSize(),
            scale: size.scale,
          ),
        );
      },
    );
  }
}

/// 折线图绘制器（含日期标签）
///
/// 数据色平直折线（无 rough 抖动），线下面积用数据色浅底 + 淡斜纹填充
/// （§9.5，替代原渐变），高亮点为淡色平涂光环 + 纸底圆 + 数据色描边圈。
class _CurveChartPainter extends CustomPainter {
  final List<double> data;
  final List<int> dates;
  final double progress;
  final double labelsProgress;
  final Color lineColor;
  final Color labelColor;
  final Color surfaceColor;
  final int highlightIndex;
  final double strokeWidth;
  final double haloRadius;
  final double highlightRadius;
  final double legendFontSize;
  final double scale;

  _CurveChartPainter({
    required this.data,
    required this.dates,
    required this.progress,
    required this.labelsProgress,
    required this.lineColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.highlightIndex,
    required this.strokeWidth,
    required this.haloRadius,
    required this.highlightRadius,
    required this.legendFontSize,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 日期标签区域高度
    final labelsHeight = legendFontSize + 8;
    final padding = 10.0;
    final chartWidth = size.width;
    final chartHeight = size.height - labelsHeight - padding;
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
    for (int i = 0; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    linePath.lineTo(size.width + 10, points.last.dy);

    // 线下斜纹面积（数据色浅底 + 淡斜纹，底部止于标签行上沿）
    final chartBottom = size.height - labelsHeight;
    final fillPath = Path.from(linePath);
    fillPath.lineTo(size.width + 10, chartBottom);
    fillPath.lineTo(-10, chartBottom);
    fillPath.close();

    // 描线动画：按进度裁剪
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

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
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 绘制高亮点：淡色平涂光环 + 纸底圆 + 数据色描边圈
    if (highlightIndex >= 0 && highlightIndex < points.length) {
      final highlightPoint = points[highlightIndex];

      canvas.drawCircle(
        highlightPoint,
        haloRadius,
        Paint()..color = lineColor.withValues(alpha: 0.28),
      );
      canvas.drawCircle(highlightPoint, highlightRadius, Paint()..color = surfaceColor);
      canvas.drawCircle(
        highlightPoint,
        highlightRadius,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.8,
      );
    }

    canvas.restore();

    // 绘制日期标签
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < dates.length && i < points.length; i++) {
      final isHighlighted = i == highlightIndex;
      final textSpan = TextSpan(
        text: dates[i].toString(),
        style: TextStyle(
          color: isHighlighted ? lineColor : labelColor,
          fontSize: legendFontSize,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.text = textSpan;
      textPainter.layout();

      final x = points[i].dx - textPainter.width / 2;
      final y = size.height - labelsHeight + (labelsHeight - textPainter.height) / 2;

      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _CurveChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.labelsProgress != labelsProgress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.haloRadius != haloRadius ||
        oldDelegate.highlightRadius != highlightRadius ||
        oldDelegate.legendFontSize != legendFontSize ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.scale != scale;
  }
}

/// 可滚动的图表区域（折线图 + 日期标签）
class _ScrollableChartSection extends StatelessWidget {
  final List<double> chartData;
  final List<int> dates;
  final int highlightIndex;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _ScrollableChartSection({
    required this.chartData,
    required this.dates,
    required this.highlightIndex,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 计算每个数据点的宽度
    final itemWidth = size.getIconSize() * 1.6;
    // 计算总宽度（至少为当前可用宽度）
    final contentWidth = (itemWidth * dates.length).clamp(
      200.0,
      double.infinity,
    );

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 使用全部可用高度
          final totalHeight = constraints.maxHeight.clamp(60.0, 160.0);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: size.getItemSpacing()),
            child: SizedBox(
              width: contentWidth,
              height: totalHeight,
              child: _CurveChart(
                data: chartData,
                dates: dates,
                animation: animation,
                highlightIndex: highlightIndex,
                size: size,
                isScrollable: true,
                contentWidth: contentWidth,
                height: totalHeight,
              ),
            ),
          );
        },
      ),
    );
  }
}
