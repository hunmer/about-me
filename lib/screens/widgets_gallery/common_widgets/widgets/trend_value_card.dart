/// 趋势数值卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 折线图（数据色平直折线 + 斜纹面积填充 + 纸底圆点）/
/// 数值（翻牌计数器）+ 单位 + 手绘箭头。数值动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 趋势数据点
class TrendDataPoint {
  final double value;
  final DateTime? timestamp;

  const TrendDataPoint({required this.value, this.timestamp});

  /// 从 JSON 创建
  factory TrendDataPoint.fromJson(Map<String, dynamic> json) {
    return TrendDataPoint(
      value: (json['value'] as num).toDouble(),
      timestamp:
          json['timestamp'] != null
              ? DateTime.parse(json['timestamp'] as String)
              : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'value': value, 'timestamp': timestamp?.toIso8601String()};
  }
}

/// 趋势数值卡片小组件
///
/// 通用的数值展示卡片，支持：
/// - 数值和单位显示（带翻转动画）
/// - 折线图（带斜纹面积填充）
class TrendValueCardWidget extends StatefulWidget {
  /// 当前数值
  final double value;

  /// 数值单位
  final String unit;

  /// 图表数据（Y坐标值，0-100范围）
  final List<double> chartData;

  /// 主色调
  final Color? primaryColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const TrendValueCardWidget({
    super.key,
    required this.value,
    required this.unit,
    required this.chartData,
    this.primaryColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory TrendValueCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return TrendValueCardWidget(
      value: (props['value'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? '',
      chartData:
          (props['chartData'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      primaryColor:
          props['primaryColor'] != null
              ? Color(int.parse(props['primaryColor'] as String))
              : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<TrendValueCardWidget> createState() => _TrendValueCardWidgetState();
}

class _TrendValueCardWidgetState extends State<TrendValueCardWidget>
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
    final primaryColor = widget.primaryColor ?? theme.primary;

    // 根据 size 计算各种尺寸
    final valueFontSize = widget.size.getLargeFontSize() * 0.35;
    final unitFontSize = widget.size.getSubtitleFontSize();
    final strokeWidth = widget.size.getStrokeWidth() * 0.3;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场；
    // 高度沿用尺寸档位的高度约束
    return ConstrainedBox(
      constraints: widget.size.getHeightConstraints(),
      child: WiredDraw(
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : null,
          radius: BorderRadius.circular(24 * scale),
          padding: widget.size.getPadding(),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图表区域
                  Expanded(
                    child: _buildChart(
                      theme,
                      primaryColor,
                      _animation.value,
                      strokeWidth,
                      scale,
                    ),
                  ),
                  SizedBox(height: widget.size.getItemSpacing()),

                  // 数值显示区域
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 数值和单位
                      SizedBox(
                        height: valueFontSize * 1.2,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: valueFontSize * 1.2,
                              child: AnimatedFlipCounter(
                                value: widget.value * _animation.value,
                                fractionDigits:
                                    widget.value % 1 != 0 ? 1 : 0,
                                textStyle: TextStyle(
                                  color: theme.text,
                                  fontSize: valueFontSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            SizedBox(width: widget.size.getSmallSpacing()),
                            SizedBox(
                              height: unitFontSize * 1.2,
                              child: Text(
                                widget.unit,
                                style: TextStyle(
                                  color: theme.textSub,
                                  fontSize: unitFontSize,
                                  fontWeight: FontWeight.w500,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 右侧箭头按钮
                      IconButton(
                        icon: DsIcon(
                          DsIconKind.chevronRight,
                          color: theme.textSub,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 构建折线图表
  Widget _buildChart(
    AppThemeData theme,
    Color primaryColor,
    double animationValue,
    double strokeWidth,
    double scale,
  ) {
    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendChartPainter(
          data: widget.chartData,
          primaryColor: primaryColor,
          dotFillColor: theme.surface,
          animationValue: animationValue,
          strokeWidth: strokeWidth,
          scale: scale,
        ),
      ),
    );
  }
}

/// 趋势图表绘制器
///
/// 数据色平直折线（无 rough 抖动），线下面积用数据色浅底 + 淡斜纹填充
/// （§9.5，替代原渐变），数据点为纸底圆 + 数据色描边。
class _TrendChartPainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor;
  final Color dotFillColor;
  final double animationValue;
  final double strokeWidth;
  final double scale;

  _TrendChartPainter({
    required this.data,
    required this.primaryColor,
    required this.dotFillColor,
    required this.animationValue,
    required this.strokeWidth,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final pointRadius = strokeWidth * 1.5;
    final denom = data.length > 1 ? data.length - 1 : 1;
    final pointDistance = size.width / denom;

    Offset pointAt(int i) => Offset(
      i * pointDistance,
      size.height - (data[i] / 100 * size.height * animationValue),
    );

    // 线下斜纹面积（数据色浅底 + 淡斜纹）
    final path = Path();
    path.moveTo(0, size.height);
    for (int i = 0; i < data.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = primaryColor.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      path,
      rect,
      color: primaryColor.withValues(alpha: 0.45),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );

    // 绘制折线（平直干净的数据色描边）
    final linePath = Path();
    for (int i = 0; i < data.length; i++) {
      final point = pointAt(i);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }

    final linePaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // 绘制数据点（纸底圆 + 数据色描边）
    final pointPaint =
        Paint()
          ..color = dotFillColor
          ..style = PaintingStyle.fill;

    final pointStrokePaint =
        Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.7;

    for (int i = 0; i < data.length; i++) {
      final point = pointAt(i);
      canvas.drawCircle(point, pointRadius, pointPaint);
      canvas.drawCircle(point, pointRadius, pointStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.dotFillColor != dotFillColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.scale != scale;
  }
}
