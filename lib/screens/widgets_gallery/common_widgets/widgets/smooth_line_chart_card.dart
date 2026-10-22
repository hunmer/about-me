/// 平滑曲线图表小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题区 / Day-Week-Month 切换（墨线圆底胶囊）/ 折线图
/// （数据色平直折线 + 斜纹面积填充 + 淡墨虚线网格）/ 时间标签。
/// 折线描画动画保留。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 数据点模型
class DataPoint {
  final double x;
  final double y;

  const DataPoint({required this.x, required this.y});

  /// 从 JSON 创建
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

/// 平滑曲线图表小组件
class SmoothLineChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String date;
  final List<DataPoint> dataPoints;
  final double maxValue;
  final List<String> timeLabels;
  final Color primaryColor;
  final double totalDistance;
  final String distanceUnit;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const SmoothLineChartCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.dataPoints,
    required this.maxValue,
    required this.timeLabels,
    required this.primaryColor,
    this.totalDistance = 0,
    this.distanceUnit = '',
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory SmoothLineChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final pointsList =
        (props['dataPoints'] as List<dynamic>?)
            ?.map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    final labelsList =
        (props['timeLabels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    return SmoothLineChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      date: props['date'] as String? ?? '',
      dataPoints: pointsList,
      maxValue: (props['maxValue'] as num?)?.toDouble() ?? 100.0,
      timeLabels: labelsList,
      primaryColor:
          props.containsKey('primaryColor')
              ? Color(props['primaryColor'] as int)
              : const Color(0xFFFF7F56),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<SmoothLineChartCardWidget> createState() =>
      _SmoothLineChartCardWidgetState();
}

class _SmoothLineChartCardWidgetState extends State<SmoothLineChartCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _selectedPeriod = 0; // 0: Day, 1: Week, 2: Month

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
        padding: widget.size.getPadding(),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: widget.size.getTitleSpacing()),
            _buildPeriodToggle(),
            SizedBox(height: widget.size.getTitleSpacing()),
            _buildChartWithLabels(),
          ],
        ),
      ),
    );
  }

  /// 构建标题区域
  Widget _buildHeader() {
    final theme = AppTheme.of(context);
    final titleFontSize = widget.size.getTitleFontSize();
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: theme.text,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            SizedBox(width: widget.size.getItemSpacing()),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w400,
                color: theme.text,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        Text(
          widget.date,
          style: TextStyle(
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.w500,
            color: theme.textSub,
            height: 1.0,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  /// 构建时间段切换按钮（墨线圆底胶囊）
  Widget _buildPeriodToggle() {
    final theme = AppTheme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.all(widget.size.getSmallSpacing()),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: BorderRadius.circular(20),
          fillColor: theme.surfaceAlt,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodButton('Day', 0),
              _buildPeriodButton('Week', 1),
              _buildPeriodButton('Month', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, int index) {
    final theme = AppTheme.of(context);
    final isSelected = _selectedPeriod == index;
    final fontSize = widget.size.getLegendFontSize();
    final buttonPadding = widget.size.getSmallSpacing() * 4;
    final borderRadius = buttonPadding * 1.5;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: buttonPadding,
          vertical: widget.size.getSmallSpacing(),
        ),
        decoration:
            isSelected
                ? dsSketchDecoration(
                  // 选中态：数据色墨线实底（无柔影）
                  theme: theme,
                  radius: BorderRadius.circular(borderRadius),
                  fillColor: widget.primaryColor,
                )
                : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.onPrimary : theme.textSub,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// 构建图表和时间标签区域（带横向滚动）
  Widget _buildChartWithLabels() {
    final theme = AppTheme.of(context);
    // 时间标签高度基于字体大小
    final labelsHeight = widget.size.getLegendFontSize() * 1.5;

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 计算最小宽度，确保足够显示所有数据点
          final minContentWidth = widget.dataPoints.length * 50.0;
          final chartWidth =
              constraints.maxWidth > minContentWidth
                  ? constraints.maxWidth
                  : minContentWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: Column(
                children: [
                  // 图表（使用 Expanded 占据剩余空间）；
                  // AnimatedBuilder 驱动描线进度 rebuild，否则 progress 恒为首帧 0
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) => _SmoothLineChart(
                        dataPoints: widget.dataPoints,
                        maxValue: widget.maxValue,
                        primaryColor: widget.primaryColor,
                        animation: _animation,
                        widgetSize: widget.size,
                        chartWidth: chartWidth,
                      ),
                    ),
                  ),
                  SizedBox(height: widget.size.getItemSpacing()),
                  // 时间标签（使用 CustomPaint 绘制）
                  SizedBox(
                    width: chartWidth,
                    height: labelsHeight,
                    child: _TimeLabels(
                      labels: widget.timeLabels,
                      textColor: theme.textSub,
                      fontSize: widget.size.getLegendFontSize(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 折线图绘制组件
class _SmoothLineChart extends StatelessWidget {
  final List<DataPoint> dataPoints;
  final double maxValue;
  final Color primaryColor;
  final Animation<double> animation;
  final HomeWidgetSize widgetSize;
  final double chartWidth;

  const _SmoothLineChart({
    required this.dataPoints,
    required this.maxValue,
    required this.primaryColor,
    required this.animation,
    required this.widgetSize,
    required this.chartWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(chartWidth, constraints.maxHeight),
          painter: _SmoothLineChartPainter(
            dataPoints: dataPoints,
            maxValue: maxValue,
            primaryColor: primaryColor,
            progress: animation.value,
            gridColor: theme.ink.withValues(alpha: 0.18),
            dotBorderColor: theme.surface,
            widgetSize: widgetSize,
          ),
        );
      },
    );
  }
}

/// 折线图画笔
///
/// 淡墨虚线垂直网格，数据色平直折线（无 rough 抖动），
/// 线下面积用数据色浅底 + 淡斜纹填充（§9.5，替代原渐变），
/// 末端为数据色实心圆点 + 纸底描边。
class _SmoothLineChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double maxValue;
  final Color primaryColor;
  final double progress;
  final Color gridColor;
  final Color dotBorderColor;
  final HomeWidgetSize widgetSize;

  _SmoothLineChartPainter({
    required this.dataPoints,
    required this.maxValue,
    required this.primaryColor,
    required this.progress,
    required this.gridColor,
    required this.dotBorderColor,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = widgetSize.scale;

    // 绘制垂直网格线（淡墨虚线）
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;

    final gridSpacing = size.width / (dataPoints.length - 1);
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * gridSpacing;
      for (var y = 4.0; y < size.height; y += 10 * scale) {
        final endY = y + 5 * scale;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, endY < size.height ? endY : size.height),
          gridPaint,
        );
      }
    }

    // 计算缩放后的点
    final scaledPoints =
        dataPoints.map((point) {
          return Offset(
            point.x / dataPoints.last.x * size.width,
            size.height - (point.y / maxValue * size.height * progress),
          );
        }).toList();

    if (scaledPoints.isEmpty) return;

    // 绘制斜纹面积填充（数据色浅底 + 数据色淡斜纹）
    final fillPath = Path();
    fillPath.moveTo(scaledPoints.first.dx, size.height);
    for (final point in scaledPoints) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(scaledPoints.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = primaryColor.withValues(alpha: 0.28),
    );
    paintDiagonalStripes(
      canvas,
      fillPath,
      fillPath.getBounds(),
      color: primaryColor.withValues(alpha: 0.45),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );

    // 绘制折线（平直干净的数据色描边）
    final linePath = Path();
    linePath.moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    for (int i = 1; i < scaledPoints.length; i++) {
      linePath.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }

    final linePaint =
        Paint()
          ..color = primaryColor
          ..strokeWidth = widgetSize.getStrokeWidth() * 0.25
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 绘制末端圆点（数据色实心 + 纸底描边）
    final endPoint = scaledPoints.last;
    final dotRadius = widgetSize.getStrokeWidth() * 0.375;
    final dotPaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(endPoint, dotRadius, dotPaint);

    final dotBorderPaint =
        Paint()
          ..color = dotBorderColor
          ..strokeWidth = widgetSize.getStrokeWidth() * 0.25
          ..style = PaintingStyle.stroke;
    canvas.drawCircle(endPoint, dotRadius, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _SmoothLineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dotBorderColor != dotBorderColor ||
        oldDelegate.widgetSize != widgetSize;
  }
}

/// 时间标签绘制组件
class _TimeLabels extends StatelessWidget {
  final List<String> labels;
  final Color textColor;
  final double fontSize;

  const _TimeLabels({
    required this.labels,
    required this.textColor,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TimeLabelsPainter(
        labels: labels,
        textColor: textColor,
        fontSize: fontSize,
      ),
    );
  }
}

/// 时间标签画笔
class _TimeLabelsPainter extends CustomPainter {
  final List<String> labels;
  final Color textColor;
  final double fontSize;

  _TimeLabelsPainter({
    required this.labels,
    required this.textColor,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final gridSpacing = size.width / (labels.length - 1);

    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final x = i * gridSpacing;

      // 计算文本对齐位置
      double textX;
      TextAlign textAlign;
      if (i == 0) {
        textX = 0;
        textAlign = TextAlign.left;
      } else if (i == labels.length - 1) {
        textX = size.width;
        textAlign = TextAlign.right;
      } else {
        textX = x;
        textAlign = TextAlign.center;
      }

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
      textPainter.textAlign = textAlign;
      textPainter.layout();

      // 根据对齐方式计算绘制位置
      double offsetX;
      switch (textAlign) {
        case TextAlign.left:
          offsetX = textX;
          break;
        case TextAlign.right:
          offsetX = textX - textPainter.width;
          break;
        default:
          offsetX = textX - textPainter.width / 2;
      }

      // 垂直居中
      final offsetY = (size.height - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeLabelsPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.textColor != textColor ||
        oldDelegate.fontSize != fontSize;
  }
}
