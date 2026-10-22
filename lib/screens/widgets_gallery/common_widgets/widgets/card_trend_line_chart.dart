/// 体重趋势图表小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 数值（翻牌计数器）/ 时间范围筛选标签（墨线圆底）/
/// 折线图（数据色平直折线 + 斜纹面积填充 + 淡墨虚线网格 + 纸底圆点）。
/// 折线描画与数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 体重趋势图表小组件
///
/// 用于显示带动画的趋势折线图，支持时间范围筛选和交互式工具提示。
/// 适用于体重趋势、温度变化、价格波动等带有时间趋势的数据展示。
///
/// 特性：
/// - 数值滚动动画
/// - 时间范围筛选标签
/// - 交互式图表工具提示
/// - 可配置颜色和尺寸
class CardTrendLineChart extends StatefulWidget {
  /// 卡片标题
  final String? title;

  /// 图标
  final IconData? icon;

  /// 当前数值
  final double currentValue;

  /// 数值单位
  final String valueUnit;

  /// 数据点列表
  final List<TrendDataPoint> dataPoints;

  /// 时间筛选器标签
  final List<String>? timeFilters;

  /// 时间筛选器变更回调
  final ValueChanged<int>? onTimeFilterChanged;

  /// 初始选中的筛选器索引
  final int initialFilterIndex;

  /// 主色调
  final Color? primaryColor;

  /// 是否显示图表背景网格
  final bool showGrid;

  /// 是否显示数据点
  final bool showDots;

  /// 是否显示面积填充
  final bool showGradient;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const CardTrendLineChart({
    super.key,
    this.title,
    this.icon,
    required this.currentValue,
    required this.valueUnit,
    required this.dataPoints,
    this.timeFilters,
    this.onTimeFilterChanged,
    this.initialFilterIndex = 4,
    this.primaryColor,
    this.showGrid = true,
    this.showDots = true,
    this.showGradient = true,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CardTrendLineChart.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return CardTrendLineChart(
      title: props['title'] as String?,
      icon: props['icon'] as IconData?,
      currentValue: (props['currentValue'] as num?)?.toDouble() ?? 0.0,
      valueUnit: props['valueUnit'] as String? ?? '',
      dataPoints:
          (props['dataPoints'] as List?)
              ?.map(
                (e) => TrendDataPoint(
                  label: e['label'] as String,
                  value: (e['value'] as num).toDouble(),
                ),
              )
              .toList() ??
          [],
      timeFilters: props['timeFilters'] as List<String>?,
      initialFilterIndex: props['initialFilterIndex'] as int? ?? 4,
      primaryColor:
          props['primaryColor'] != null
              ? Color(props['primaryColor'] as int)
              : null,
      showGrid: props['showGrid'] as bool? ?? true,
      showDots: props['showDots'] as bool? ?? true,
      showGradient: props['showGradient'] as bool? ?? true,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CardTrendLineChart> createState() => _CardTrendLineChartState();
}

class _CardTrendLineChartState extends State<CardTrendLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialFilterIndex;
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
    final primaryColor = widget.primaryColor ?? theme.primary;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding().copyWith(bottom: 0),
        child: Column(
          children: [
            SizedBox(height: widget.size.getSmallSpacing()),

            // 数值显示区
            _buildValueDisplay(theme, primaryColor),

            SizedBox(height: widget.size.getSmallSpacing()),

            // 时间范围筛选标签
            if (widget.timeFilters != null &&
                widget.timeFilters!.isNotEmpty) ...[
              _buildTimeFilterTabs(theme),
              SizedBox(height: widget.size.getSmallSpacing()),
            ],

            // 图表区域
            Expanded(child: _buildChart(theme, primaryColor)),
          ],
        ),
      ),
    );
  }

  /// 数值显示区
  Widget _buildValueDisplay(AppThemeData theme, Color primaryColor) {
    // 根据尺寸计算图标容器大小
    final iconContainerSize = widget.size.getIconSize() * 1.6;
    final iconRadius = iconContainerSize * 0.3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 图标徽章（墨线圆底）
        if (widget.icon != null) ...[
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(iconRadius),
              fillColor: theme.surfaceAlt,
            ),
            child: Center(
              child: WiredIcon(
                icon: widget.icon!,
                size: widget.size.getIconSize() * 0.8,
                color: primaryColor,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
          SizedBox(width: widget.size.getSmallSpacing()),
        ],

        // 数值
        SizedBox(
          height: widget.size.getLargeFontSize() * 1.4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: widget.size.getLargeFontSize(),
                child: AnimatedFlipCounter(
                  value: widget.currentValue * _animation.value,
                  fractionDigits: 1,
                  textStyle: TextStyle(
                    fontSize: widget.size.getLargeFontSize() * 0.8,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(width: widget.size.getSmallSpacing()),
              SizedBox(
                height: widget.size.getSubtitleFontSize(),
                child: Text(
                  widget.valueUnit,
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 时间范围筛选标签（墨线圆底胶囊）
  Widget _buildTimeFilterTabs(AppThemeData theme) {
    return Container(
      padding: EdgeInsets.all(widget.size.getSmallSpacing()),
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(widget.size.getSmallSpacing() * 3),
        fillColor: theme.surfaceAlt,
      ),
      child: Row(
        children: List.generate(widget.timeFilters!.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
                widget.onTimeFilterChanged?.call(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: widget.size.getSmallSpacing() * 1.5,
                ),
                decoration:
                    isSelected
                        ? dsSketchDecoration(
                          // 选中态：纸底墨线实块（无柔影）
                          theme: theme,
                          radius: BorderRadius.circular(
                            widget.size.getSmallSpacing() * 2.5,
                          ),
                          fillColor: theme.surface,
                        )
                        : null,
                child: Text(
                  widget.timeFilters![index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: isSelected ? theme.text : theme.textSub,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 图表区域
  Widget _buildChart(AppThemeData theme, Color primaryColor) {
    // 计算最小和最大值以设置 Y 轴范围
    final values = widget.dataPoints.map((p) => p.value).toList();
    if (values.isEmpty) {
      return Center(
        child: Text('无数据', style: TextStyle(color: theme.textSub)),
      );
    }

    final minValue = values.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxValue = values.reduce((a, b) => a > b ? a : b) + 0.5;
    // 基础 X 轴间距根据尺寸调整
    final baseWidth =
        widget.size is WideSize || widget.size is Wide2Size ? 400.0 : 280.0;
    final xInterval =
        baseWidth /
        (widget.dataPoints.length > 1 ? widget.dataPoints.length - 1 : 1);

    return Padding(
      padding: EdgeInsets.only(bottom: widget.size.getItemSpacing()),
      child: CustomPaint(
        size: Size.infinite,
        painter: _TrendLineChartPainter(
          dataPoints: widget.dataPoints,
          animation: _animation,
          primaryColor: primaryColor,
          gridColor: theme.ink.withValues(alpha: 0.18),
          labelColor: theme.textSub,
          dotFillColor: theme.surface,
          minValue: minValue,
          maxValue: maxValue,
          xInterval: xInterval,
          showGrid: widget.showGrid,
          showDots: widget.showDots,
          showGradient: widget.showGradient,
          size: widget.size,
        ),
      ),
    );
  }
}

/// 趋势折线图画笔
///
/// 淡墨虚线网格，数据色平直折线（无 rough 抖动），线下面积用数据色
/// 浅底 + 淡斜纹填充（§9.5，替代原渐变），数据点为数据色实心圆 +
/// 纸底内圈。
class _TrendLineChartPainter extends CustomPainter {
  final List<TrendDataPoint> dataPoints;
  final Animation<double> animation;
  final Color primaryColor;
  final Color gridColor;
  final Color labelColor;
  final Color dotFillColor;
  final double minValue;
  final double maxValue;
  final double xInterval;
  final bool showGrid;
  final bool showDots;
  final bool showGradient;
  final HomeWidgetSize size;

  _TrendLineChartPainter({
    required this.dataPoints,
    required this.animation,
    required this.primaryColor,
    required this.gridColor,
    required this.labelColor,
    required this.dotFillColor,
    required this.minValue,
    required this.maxValue,
    required this.xInterval,
    required this.showGrid,
    required this.showDots,
    required this.showGradient,
    required this.size,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (dataPoints.isEmpty) return;

    final scale = size.scale;
    final padding = size.getPadding().left;
    final chartWidth = canvasSize.width - padding * 2;
    final chartHeight = canvasSize.height - padding * 2;

    // 绘制网格线
    if (showGrid) {
      _drawGrid(canvas, canvasSize, padding, scale);
    }

    // 计算点的位置
    final points = <Offset>[];
    final baseWidth = size is WideSize || size is Wide2Size ? 400.0 : 280.0;
    for (int i = 0; i < dataPoints.length; i++) {
      final x = padding + (i * xInterval / baseWidth) * chartWidth;
      final normalizedValue =
          (dataPoints[i].value - minValue) / (maxValue - minValue);
      final y = padding + chartHeight - (normalizedValue * chartHeight);
      points.add(Offset(x, y));
    }

    // 绘制斜纹面积填充
    if (showGradient) {
      _drawStripedFill(canvas, points, canvasSize, scale);
    }

    // 绘制折线
    _drawLine(canvas, points);

    // 绘制数据点
    if (showDots) {
      _drawDots(canvas, points);
    }

    // 绘制X轴标签（小尺寸不显示）
    if (size is! SmallSize) {
      _drawXLabels(canvas, points, canvasSize);
    }
  }

  /// 绘制网格线（淡墨虚线）
  void _drawGrid(Canvas canvas, Size canvasSize, double padding, double scale) {
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = size.getStrokeWidth() * 0.1;

    // 水平网格线
    for (int i = 0; i <= 4; i++) {
      final y = padding + (canvasSize.height - padding * 2) * (i / 4);
      for (var x = padding; x < canvasSize.width - padding; x += 10 * scale) {
        final endX = x + 5 * scale;
        canvas.drawLine(
          Offset(x, y),
          Offset(
            endX < canvasSize.width - padding ? endX : canvasSize.width - padding,
            y,
          ),
          gridPaint,
        );
      }
    }
  }

  /// 绘制斜纹面积填充（数据色浅底 + 淡斜纹）
  void _drawStripedFill(
    Canvas canvas,
    List<Offset> points,
    Size canvasSize,
    double scale,
  ) {
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.lineTo(points.last.dx, canvasSize.height);
    path.lineTo(points.first.dx, canvasSize.height);
    path.close();

    canvas.drawPath(path, Paint()..color = primaryColor.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      path,
      path.getBounds(),
      color: primaryColor.withValues(alpha: 0.45),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
  }

  /// 绘制折线（平直干净的数据色描边）
  void _drawLine(Canvas canvas, List<Offset> points) {
    if (points.isEmpty) return;

    final linePaint =
        Paint()
          ..color = primaryColor
          ..strokeWidth = size.getStrokeWidth() * 0.3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);
  }

  /// 绘制数据点（数据色实心圆 + 纸底内圈）
  void _drawDots(Canvas canvas, List<Offset> points) {
    final dotRadius = size.getSmallSpacing() * animation.value;
    final dotStrokeWidth = size.getSmallSpacing() * 0.5;

    for (final point in points) {
      // 外圈
      final dotPaint =
          Paint()
            ..color = primaryColor
            ..style = PaintingStyle.fill;
      canvas.drawCircle(point, dotRadius, dotPaint);

      // 内圈
      final innerDotPaint =
          Paint()
            ..color = dotFillColor
            ..style = PaintingStyle.fill;
      canvas.drawCircle(point, dotRadius - dotStrokeWidth / 2, innerDotPaint);
    }
  }

  /// 绘制X轴标签
  void _drawXLabels(Canvas canvas, List<Offset> points, Size canvasSize) {
    final textStyle = TextStyle(
      color: labelColor,
      fontSize: size.getLegendFontSize(),
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < dataPoints.length; i++) {
      final point = points[i];
      final textPainter = TextPainter(
        text: TextSpan(text: dataPoints[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          point.dx - textPainter.width / 2,
          canvasSize.height - size.getPadding().bottom,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLineChartPainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.dotFillColor != dotFillColor;
  }
}

/// 趋势数据点模型
///
/// 表示趋势图上的单个数据点。
class TrendDataPoint {
  /// X轴标签
  final String label;

  /// 数值
  final double value;

  const TrendDataPoint({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendDataPoint &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => label.hashCode ^ value.hashCode;
}
