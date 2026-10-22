/// 支出趋势折线图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 日期栏（手绘日历图标）/ 内容区（小控件档墨线卡底）：标题 + 图例 /
/// 当月折线（数据色平直折线 + 斜纹面积）+ 上月淡色虚线 + 预算线 /
/// X/Y 轴标签。折线描画与当前点动画保留。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 支出趋势折线图小组件
///
/// 用于显示支出趋势对比的卡片组件，支持：
/// - 当前月与上月对比
/// - 预算线显示
/// - 折线描画动画
/// - 斜纹填充效果
class SpendingTrendChartWidget extends StatefulWidget {
  /// 日期范围文本
  final String dateRange;

  /// 标题
  final String title;

  /// 当前月标签
  final String currentMonthLabel;

  /// 上月标签
  final String previousMonthLabel;

  /// 预算金额
  final double budgetAmount;

  /// 预算标签
  final String budgetLabel;

  /// X轴开始标签
  final String startLabel;

  /// X轴中间标签
  final String middleLabel;

  /// X轴结束标签
  final String endLabel;

  /// 当前月数据点
  final List<double> currentMonthData;

  /// 上月数据点
  final List<double> previousMonthData;

  /// 当前点值
  final double currentPoint;

  /// 最大金额（用于Y轴缩放）
  final double maxAmount;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const SpendingTrendChartWidget({
    super.key,
    required this.dateRange,
    required this.title,
    required this.currentMonthLabel,
    required this.previousMonthLabel,
    required this.budgetAmount,
    required this.budgetLabel,
    required this.startLabel,
    required this.middleLabel,
    required this.endLabel,
    required this.currentMonthData,
    required this.previousMonthData,
    required this.currentPoint,
    required this.maxAmount,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于小组件系统）
  factory SpendingTrendChartWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return SpendingTrendChartWidget(
      dateRange: props['dateRange'] as String? ?? '1-31 October 2025',
      title: props['title'] as String? ?? 'Spending trends',
      currentMonthLabel: props['currentMonthLabel'] as String? ?? 'Oct 2025',
      previousMonthLabel: props['previousMonthLabel'] as String? ?? 'Sep 2025',
      budgetAmount: (props['budgetAmount'] as num?)?.toDouble() ?? 3200,
      budgetLabel: props['budgetLabel'] as String? ?? 'Budget',
      startLabel: props['startLabel'] as String? ?? 'Oct 1',
      middleLabel: props['middleLabel'] as String? ?? 'Today',
      endLabel: props['endLabel'] as String? ?? 'Oct 31',
      currentMonthData:
          (props['currentMonthData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [3200, 2800, 2400, 2000, 1600],
      previousMonthData:
          (props['previousMonthData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [2800, 2400, 2000, 1600, 1200],
      currentPoint: (props['currentPoint'] as num?)?.toDouble() ?? 1600,
      maxAmount: (props['maxAmount'] as num?)?.toDouble() ?? 4000,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SpendingTrendChartWidget> createState() =>
      _SpendingTrendChartWidgetState();
}

class _SpendingTrendChartWidgetState extends State<SpendingTrendChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _pointAnimationController;
  late Animation<double> _pointAnimation;

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

    // 当前点放大动画
    _pointAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pointAnimation = CurvedAnimation(
      parent: _pointAnimationController,
      curve: Curves.easeOutBack,
    );

    // 主动画完成后启动点动画
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pointAnimationController.forward();
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pointAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    final primaryColor = theme.primary;
    final mutedColor = theme.textSub;
    final textColor = theme.text;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 320,
        height: widget.inline ? double.maxFinite : 320,
        radius: BorderRadius.circular(24 * scale),
        child: Column(
          children: [
            // 顶部标题栏
            Padding(
              padding: widget.size.getPadding().copyWith(
                bottom:
                    (widget.size.getPadding().bottom * 0.75).roundToDouble(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.dateRange,
                    style: TextStyle(
                      fontSize: widget.size.getSubtitleFontSize(),
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  DsIcon(
                    DsIconKind.calendar,
                    size: widget.size.getIconSize(),
                    color: textColor,
                  ),
                ],
              ),
            ),
            // 内容区域（小控件档墨线卡底）
            Expanded(
              child: Container(
                decoration: dsSketchDecoration(
                  theme: theme,
                  radius: BorderRadius.circular(12 * scale),
                  fillColor: theme.surfaceAlt,
                ),
                padding: widget.size.getPadding(),
                child: Column(
                  children: [
                    // 标题和图例
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: widget.size.getTitleFontSize(),
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: widget.size.getItemSpacing()),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _LegendItem(
                              color: primaryColor,
                              label: widget.currentMonthLabel,
                              isDashed: false,
                              size: widget.size,
                            ),
                            SizedBox(
                              height: widget.size.getItemSpacing(),
                            ),
                            _LegendItem(
                              color: mutedColor,
                              label: widget.previousMonthLabel,
                              isDashed: true,
                              size: widget.size,
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: widget.size.getTitleSpacing()),
                    // 图表区域
                    Expanded(
                      child: _TrendLineChart(
                        currentMonthData: widget.currentMonthData,
                        previousMonthData: widget.previousMonthData,
                        currentPoint: widget.currentPoint,
                        budgetAmount: widget.budgetAmount,
                        maxAmount: widget.maxAmount,
                        primaryColor: primaryColor,
                        mutedColor: mutedColor,
                        animation: _animation,
                        pointAnimation: _pointAnimation,
                        budgetLabel: widget.budgetLabel,
                        textColor: textColor,
                        startLabel: widget.startLabel,
                        middleLabel: widget.middleLabel,
                        endLabel: widget.endLabel,
                        size: widget.size,
                      ),
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

/// 图例项（实心为墨线圆底色块，虚线为淡色虚线圈）
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;
  final HomeWidgetSize size;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDashed,
    this.size = const MediumSize(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final indicatorWidth = size.getLegendIndicatorWidth() / 2;
    final indicatorHeight = size.getLegendIndicatorHeight() / 2;

    return Row(
      children: [
        SizedBox(
          width: indicatorWidth,
          height: indicatorHeight,
          child:
              isDashed
                  ? CustomPaint(painter: _DashedCirclePainter(color: color))
                  : Container(
                    // 大圆角被 rough 引擎自动钳制成圆
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(indicatorWidth / 2),
                      fillColor: color,
                    ),
                  ),
        ),
        SizedBox(width: size.getSmallSpacing()),
        Text(
          label,
          style: TextStyle(
            fontSize: size.getLegendFontSize(),
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// 虚线圆圈绘制器
class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    const dashCount = 8;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * 2 * math.pi / dashCount);
      final sweepAngle = (math.pi / dashCount) * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 趋势折线图组件
class _TrendLineChart extends StatelessWidget {
  final List<double> currentMonthData;
  final List<double> previousMonthData;
  final double currentPoint;
  final double budgetAmount;
  final double maxAmount;
  final Color primaryColor;
  final Color mutedColor;
  final Animation<double> animation;
  final Animation<double> pointAnimation;
  final String budgetLabel;
  final Color textColor;
  final String startLabel;
  final String middleLabel;
  final String endLabel;
  final HomeWidgetSize size;

  const _TrendLineChart({
    required this.currentMonthData,
    required this.previousMonthData,
    required this.currentPoint,
    required this.budgetAmount,
    required this.maxAmount,
    required this.primaryColor,
    required this.mutedColor,
    required this.animation,
    required this.pointAnimation,
    required this.budgetLabel,
    required this.textColor,
    required this.startLabel,
    required this.middleLabel,
    required this.endLabel,
    this.size = const MediumSize(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 计算Y轴标签
    final yLabels = [
      '${(maxAmount / 1000).toInt()}k',
      '${((maxAmount * 0.75) / 1000).toInt()}k',
      '${((maxAmount * 0.5) / 1000).toInt()}k',
      '${((maxAmount * 0.25) / 1000).toInt()}k',
    ];

    return Stack(
      children: [
        // Y轴标签 - 使用自绘
        Positioned(
          left: 0,
          top: 0,
          bottom: 30,
          child: CustomPaint(
            size: Size(size.getPadding().left, double.infinity),
            painter: _YAxisLabelPainter(
              labels: yLabels,
              fontSize: size.getLegendFontSize(),
              color: mutedColor,
              padding: size.getItemSpacing() / 2,
            ),
          ),
        ),
        // 预算线标签 - 使用自绘
        Positioned(
          left: size.getPadding().left,
          top: 30 * (1 - budgetAmount / maxAmount),
          child: CustomPaint(
            size: Size(300, size.getLegendFontSize() * 2),
            painter: _BudgetLabelPainter(
              budgetAmount: budgetAmount,
              budgetLabel: budgetLabel,
              fontSize: size.getLegendFontSize(),
              textColor: theme.text,
              fillColor: theme.surfaceAlt,
              strokeColor: theme.ink.withValues(alpha: 0.45),
              lineColor: theme.ink.withValues(alpha: 0.18),
              itemSpacing: size.getItemSpacing(),
              lineWidth: 200,
            ),
          ),
        ),
        // 图表
        Positioned.fill(
          left: size.getPadding().left,
          bottom: 30,
          child: _LineChartPainterWidget(
            currentMonthData: currentMonthData,
            previousMonthData: previousMonthData,
            currentPoint: currentPoint,
            budgetAmount: budgetAmount,
            maxAmount: maxAmount,
            primaryColor: primaryColor,
            mutedColor: mutedColor,
            gridColor: theme.ink.withValues(alpha: 0.18),
            animation: animation,
            pointAnimation: pointAnimation,
            size: size,
          ),
        ),
        // X轴标签 - 使用自绘
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.getPadding().left),
            child: CustomPaint(
              size: Size(double.infinity, size.getLegendFontSize() * 2),
              painter: _XAxisLabelPainter(
                startLabel: startLabel,
                middleLabel: middleLabel,
                endLabel: endLabel,
                fontSize: size.getLegendFontSize(),
                mutedColor: mutedColor,
                textColor: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Y轴标签绘制器
class _YAxisLabelPainter extends CustomPainter {
  final List<String> labels;
  final double fontSize;
  final Color color;
  final double padding;

  _YAxisLabelPainter({
    required this.labels,
    required this.fontSize,
    required this.color,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    final stepHeight = size.height / (labels.length);
    for (int i = 0; i < labels.length; i++) {
      final y = i * stepHeight + stepHeight / 2 - fontSize / 2;

      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y.clamp(0, size.height - fontSize)));
    }
  }

  @override
  bool shouldRepaint(covariant _YAxisLabelPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.color != color ||
        oldDelegate.padding != padding;
  }
}

/// 预算标签绘制器（纸底圆角小签 + 淡墨虚线基线）
class _BudgetLabelPainter extends CustomPainter {
  final double budgetAmount;
  final String budgetLabel;
  final double fontSize;
  final Color textColor;
  final Color fillColor;
  final Color strokeColor;
  final Color lineColor;
  final double itemSpacing;
  final double lineWidth;

  _BudgetLabelPainter({
    required this.budgetAmount,
    required this.budgetLabel,
    required this.fontSize,
    required this.textColor,
    required this.fillColor,
    required this.strokeColor,
    required this.lineColor,
    required this.itemSpacing,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制标签背景
    final text = '\$${budgetAmount.toInt()} $budgetLabel';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final bgWidth = textPainter.width + itemSpacing * 2;
    final bgHeight = textPainter.height + itemSpacing / 2;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bgWidth, bgHeight),
      const Radius.circular(10),
    );

    final bgPaint = Paint()..color = fillColor;
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint =
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    canvas.drawRRect(bgRect, borderPaint);

    // 绘制文本
    textPainter.paint(canvas, Offset(itemSpacing, itemSpacing / 4));

    // 绘制线条（淡墨基线）
    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(bgWidth + itemSpacing, bgHeight / 2),
      Offset(bgWidth + itemSpacing + lineWidth, bgHeight / 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BudgetLabelPainter oldDelegate) {
    return oldDelegate.budgetAmount != budgetAmount ||
        oldDelegate.budgetLabel != budgetLabel ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.textColor != textColor ||
        oldDelegate.fillColor != fillColor;
  }
}

/// X轴标签绘制器
class _XAxisLabelPainter extends CustomPainter {
  final String startLabel;
  final String middleLabel;
  final String endLabel;
  final double fontSize;
  final Color mutedColor;
  final Color textColor;

  _XAxisLabelPainter({
    required this.startLabel,
    required this.middleLabel,
    required this.endLabel,
    required this.fontSize,
    required this.mutedColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 绘制开始标签
    textPainter.text = TextSpan(
      text: startLabel,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    // 绘制中间标签
    textPainter.text = TextSpan(
      text: middleLabel,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, 0));

    // 绘制结束标签
    textPainter.text = TextSpan(
      text: endLabel,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: mutedColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width, 0));
  }

  @override
  bool shouldRepaint(covariant _XAxisLabelPainter oldDelegate) {
    return oldDelegate.startLabel != startLabel ||
        oldDelegate.middleLabel != middleLabel ||
        oldDelegate.endLabel != endLabel ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.textColor != textColor;
  }
}

/// 折线图绘制组件
class _LineChartPainterWidget extends StatelessWidget {
  final List<double> currentMonthData;
  final List<double> previousMonthData;
  final double currentPoint;
  final double budgetAmount;
  final double maxAmount;
  final Color primaryColor;
  final Color mutedColor;
  final Color gridColor;
  final Animation<double> animation;
  final Animation<double> pointAnimation;
  final HomeWidgetSize size;

  const _LineChartPainterWidget({
    required this.currentMonthData,
    required this.previousMonthData,
    required this.currentPoint,
    required this.budgetAmount,
    required this.maxAmount,
    required this.primaryColor,
    required this.mutedColor,
    required this.gridColor,
    required this.animation,
    required this.pointAnimation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: pointAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _LineChartPainter(
                currentMonthData: currentMonthData,
                previousMonthData: previousMonthData,
                currentPoint: currentPoint,
                budgetAmount: budgetAmount,
                maxAmount: maxAmount,
                primaryColor: primaryColor,
                mutedColor: mutedColor,
                gridColor: gridColor,
                animation: animation.value,
                pointAnimation: pointAnimation.value,
                size: size,
              ),
            );
          },
        );
      },
    );
  }
}

/// 折线图绘制器
///
/// 当月：数据色平直折线（无 rough 抖动）+ 斜纹面积（§9.5，替代原渐变）；
/// 上月：淡色虚线；底线为淡墨虚线网格色。
class _LineChartPainter extends CustomPainter {
  final List<double> currentMonthData;
  final List<double> previousMonthData;
  final double currentPoint;
  final double budgetAmount;
  final double maxAmount;
  final Color primaryColor;
  final Color mutedColor;
  final Color gridColor;
  final double animation;
  final double pointAnimation;
  final HomeWidgetSize size;

  _LineChartPainter({
    required this.currentMonthData,
    required this.previousMonthData,
    required this.currentPoint,
    required this.budgetAmount,
    required this.maxAmount,
    required this.primaryColor,
    required this.mutedColor,
    required this.gridColor,
    required this.animation,
    required this.pointAnimation,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final padding = size.getPadding().left.toDouble();
    final chartWidth = canvasSize.width - padding * 2;
    final chartHeight = canvasSize.height - size.getPadding().bottom;

    // 绘制上个月虚线
    _drawDashedLine(
      canvas,
      previousMonthData,
      chartWidth,
      chartHeight,
      padding,
      mutedColor,
      canvasSize,
    );

    // 绘制当前月份斜纹填充
    _drawStripedFill(
      canvas,
      currentMonthData,
      chartWidth,
      chartHeight,
      padding,
      primaryColor,
      canvasSize,
    );

    // 绘制当前月份实线
    _drawSolidLine(
      canvas,
      currentMonthData,
      chartWidth,
      chartHeight,
      padding,
      primaryColor,
      canvasSize,
    );

    // 绘制当前点
    _drawCurrentPoint(
      canvas,
      currentMonthData,
      chartWidth,
      chartHeight,
      padding,
      primaryColor,
      canvasSize,
    );

    // 绘制底线（淡墨）
    final linePaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = size.getStrokeWidth() * 0.1;

    canvas.drawLine(
      Offset(padding, canvasSize.height - 8),
      Offset(canvasSize.width - padding, canvasSize.height - 8),
      linePaint,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    List<double> data,
    double width,
    double height,
    double padding,
    Color color,
    Size canvasSize,
  ) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = size.getStrokeWidth() * 0.15
          ..style = PaintingStyle.stroke;

    final path = _createPath(data, width, height, padding, canvasSize);
    final dashPath = _createDashedPath(path);

    canvas.drawPath(dashPath, paint);
  }

  void _drawStripedFill(
    Canvas canvas,
    List<double> data,
    double width,
    double height,
    double padding,
    Color color,
    Size canvasSize,
  ) {
    final path = _createPath(data, width, height, padding, canvasSize);

    // 创建闭合路径用于填充
    final fillPath = Path();
    final pathMetrics = path.computeMetrics();
    final metric = pathMetrics.first;

    final extractPath = metric.extractPath(0, metric.length * animation);
    fillPath.addPath(extractPath, Offset.zero);

    // 添加底部闭合
    final firstPoint = _getPointAtIndex(
      data,
      0,
      width,
      height,
      padding,
      canvasSize,
    );
    final lastPoint = _getPointAtIndex(
      data,
      (data.length - 1 * animation).floor().clamp(0, data.length - 1),
      width,
      height,
      padding,
      canvasSize,
    );

    fillPath.lineTo(lastPoint.dx, canvasSize.height - 8);
    fillPath.lineTo(firstPoint.dx, canvasSize.height - 8);
    fillPath.close();

    // 数据色浅底 + 淡斜纹（§9.5，替代原渐变）
    canvas.drawPath(fillPath, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      fillPath,
      fillPath.getBounds(),
      color: color.withValues(alpha: 0.45),
      strokeWidth: 1.5 * size.scale,
      spacing: 6.5 * size.scale,
    );
  }

  void _drawSolidLine(
    Canvas canvas,
    List<double> data,
    double width,
    double height,
    double padding,
    Color color,
    Size canvasSize,
  ) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = size.getStrokeWidth() * 0.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final path = _createPath(data, width, height, padding, canvasSize);
    final pathMetrics = path.computeMetrics();
    final metric = pathMetrics.first;

    final extractPath = metric.extractPath(0, metric.length * animation);
    canvas.drawPath(extractPath, paint);
  }

  void _drawCurrentPoint(
    Canvas canvas,
    List<double> data,
    double width,
    double height,
    double padding,
    Color color,
    Size canvasSize,
  ) {
    // 只在主动画接近完成时才开始绘制当前点
    if (animation < 0.9) return;

    final pointIndex = data.length - 1;
    final point = _getPointAtIndex(
      data,
      pointIndex,
      width,
      height,
      padding,
      canvasSize,
    );

    // 计算缩放比例：基于点动画值
    final scale = pointAnimation.clamp(0.0, 1.0);

    // 基于尺寸的圆点半径
    final haloRadius = size.getStrokeWidth() * scale;
    final dotRadius = size.getStrokeWidth() * 0.6 * scale;

    // 外圈平涂光环（无柔影）
    final haloPaint =
        Paint()
          ..color = color.withValues(alpha: 0.28 * scale)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(point, haloRadius, haloPaint);

    // 内圈实心点
    final dotPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(point, dotRadius, dotPaint);
  }

  /// 平直折线路径（无 rough 抖动，§9.5 数据几何保持平直干净）
  Path _createPath(
    List<double> data,
    double width,
    double height,
    double padding,
    Size canvasSize,
  ) {
    final path = Path();
    if (data.isEmpty) return path;

    final firstPoint = _getPointAtIndex(
      data,
      0,
      width,
      height,
      padding,
      canvasSize,
    );
    path.moveTo(firstPoint.dx, firstPoint.dy);

    for (int i = 1; i < data.length; i++) {
      final point = _getPointAtIndex(
        data,
        i,
        width,
        height,
        padding,
        canvasSize,
      );
      path.lineTo(point.dx, point.dy);
    }

    return path;
  }

  Offset _getPointAtIndex(
    List<double> data,
    int index,
    double width,
    double height,
    double padding,
    Size canvasSize,
  ) {
    if (index >= data.length) index = data.length - 1;
    if (index < 0) index = 0;

    final x = padding + (width / (data.length - 1)) * index;
    final y = (canvasSize.height - 8) - (data[index] / maxAmount) * height;
    return Offset(x, y);
  }

  Path _createDashedPath(Path source) {
    final dashPath = Path();
    const dashWidth = 3.0;
    const dashSpace = 3.0;

    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;

      while (distance < metric.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }

    return dashPath;
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.pointAnimation != pointAnimation ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.mutedColor != mutedColor;
  }
}
