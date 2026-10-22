/// 垂直柱状图卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题头部 / 手绘图例色块 / 淡墨虚线网格 + 双段斜纹柱
/// （各段数据色浅底 + 数据色浓斜纹 + 数据色描边，胶囊端）。
/// 柱高生长动画保留。
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 柱状图数据模型
class BarData {
  final double value1;
  final double value2;

  const BarData({required this.value1, required this.value2});

  /// 从 JSON 创建（用于公共小组件系统）
  factory BarData.fromJson(Map<String, dynamic> json) {
    return BarData(
      value1: (json['value1'] as num?)?.toDouble() ?? 0.0,
      value2: (json['value2'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON（用于公共小组件系统）
  Map<String, dynamic> toJson() {
    return {'value1': value1, 'value2': value2};
  }
}

/// 垂直柱状图卡片小组件
class VerticalBarChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String dataLabel1;
  final String dataLabel2;
  final List<BarData> bars;
  final Color? primaryColor;
  final Color? secondaryColor;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const VerticalBarChartCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dataLabel1,
    required this.dataLabel2,
    required this.bars,
    this.primaryColor,
    this.secondaryColor,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory VerticalBarChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final barsList =
        (props['bars'] as List<dynamic>?)
            ?.map((e) => BarData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return VerticalBarChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      dataLabel1: props['dataLabel1'] as String? ?? '',
      dataLabel2: props['dataLabel2'] as String? ?? '',
      bars: barsList,
      primaryColor:
          props['primaryColor'] != null
              ? Color(props['primaryColor'] as int)
              : null,
      secondaryColor:
          props['secondaryColor'] != null
              ? Color(props['secondaryColor'] as int)
              : null,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<VerticalBarChartCardWidget> createState() =>
      _VerticalBarChartCardWidgetState();
}

class _VerticalBarChartCardWidgetState extends State<VerticalBarChartCardWidget>
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
    // 数据色（props 可覆盖，属数据不属于主题）
    final primaryColor = widget.primaryColor ?? const Color(0xFF0072B5);
    final secondaryColor = widget.secondaryColor ?? const Color(0xFF00A8CC);

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 350,
        height: widget.inline ? double.maxFinite : 320,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: widget.size.getTitleFontSize(),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: theme.textSub,
                          fontSize: widget.size.getSubtitleFontSize(),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.size.getTitleSpacing() * 0.8),
            // 图例
            Row(
              children: [
                _LegendItem(
                  color: primaryColor,
                  label: widget.dataLabel1,
                  size: widget.size,
                ),
                SizedBox(width: widget.size.getItemSpacing()),
                _LegendItem(
                  color: secondaryColor,
                  label: widget.dataLabel2,
                  size: widget.size,
                ),
              ],
            ),
            SizedBox(height: widget.size.getItemSpacing()),

            // 柱状图
            Expanded(
              child: _BarChart(
                bars: widget.bars,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                theme: theme,
                animation: _animation,
                size: widget.size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 图例项：手绘数据色色块 + 标签（§9.5 图例色块小控件档）
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final HomeWidgetSize size;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final indicatorWidth = size.getLegendIndicatorWidth();
    final indicatorHeight = size.getLegendIndicatorHeight();
    return Row(
      children: [
        Container(
          width: indicatorWidth,
          height: indicatorHeight,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(4),
            fillColor: color,
          ),
        ),
        SizedBox(width: size.getSmallSpacing()),
        Text(
          label,
          style: TextStyle(
            color: theme.text,
            fontSize: size.getLegendFontSize(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 柱状图主体
class _BarChart extends StatelessWidget {
  final List<BarData> bars;
  final Color primaryColor;
  final Color secondaryColor;
  final AppThemeData theme;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _BarChart({
    required this.bars,
    required this.primaryColor,
    required this.secondaryColor,
    required this.theme,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 计算最大值用于缩放
    double maxValue = 0;
    for (var bar in bars) {
      final total = bar.value1 + bar.value2;
      if (total > maxValue) maxValue = total;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;

        return Stack(
          children: [
            // 淡墨虚线网格（垂直参考线 + 上下段基准线）
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.getPadding().right),
                child: CustomPaint(
                  painter: _DashedGridPainter(
                    color: theme.ink.withValues(alpha: 0.18),
                    lineCount: 6,
                    baselineFromBottom: 0.3,
                    scale: size.scale,
                  ),
                ),
              ),
            ),
            // 柱子
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                bars.length,
                (index) => _Bar(
                  data: bars[index],
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                  maxValue: maxValue,
                  maxHeight: maxHeight,
                  animation: animation,
                  index: index,
                  size: size,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 单个柱子：上下两段斜纹胶囊（各自数据色浅底 + 浓斜纹 + 描边）
class _Bar extends StatelessWidget {
  final BarData data;
  final Color primaryColor;
  final Color secondaryColor;
  final double maxValue;
  final double maxHeight;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _Bar({
    required this.data,
    required this.primaryColor,
    required this.secondaryColor,
    required this.maxValue,
    required this.maxHeight,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final barAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        index * 0.08,
        (index * 0.08 + 0.3).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    // 计算可用高度（减去间距）
    final availableHeight = maxHeight - size.getBarSpacing();
    final height1 = data.value1 / maxValue * availableHeight;
    final height2 = data.value2 / maxValue * availableHeight;

    return AnimatedBuilder(
      animation: barAnimation,
      builder: (context, child) {
        final currentHeight1 = height1 * barAnimation.value;
        final currentHeight2 = height2 * barAnimation.value;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CustomPaint(
              size: Size(size.getBarWidth(), currentHeight1),
              painter: _StripedBarPainter(
                color: primaryColor,
                scale: size.scale,
              ),
            ),
            SizedBox(height: size.getBarSpacing()),
            CustomPaint(
              size: Size(size.getBarWidth(), currentHeight2),
              painter: _StripedBarPainter(
                color: secondaryColor,
                scale: size.scale,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 斜纹柱绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直胶囊几何（无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _StripedBarPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _StripedBarPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      rect,
      color: color.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

/// 淡墨虚线网格：垂直参考线均布 + 底部基准线（柱段分界）
class _DashedGridPainter extends CustomPainter {
  final Color color;
  final int lineCount;
  final double baselineFromBottom;
  final double scale;

  const _DashedGridPainter({
    required this.color,
    required this.lineCount,
    required this.baselineFromBottom,
    required this.scale,
  });

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 5.0;
    const gapLength = 5.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final total = math.sqrt(dx * dx + dy * dy);
    if (total <= 0) return;
    var drawn = 0.0;
    var drawing = true;
    while (drawn < total) {
      final segment = math.min(dashLength, total - drawn);
      if (drawing) {
        final t0 = drawn / total;
        final t1 = (drawn + segment) / total;
        canvas.drawLine(
          Offset(a.dx + dx * t0, a.dy + dy * t0),
          Offset(a.dx + dx * t1, a.dy + dy * t1),
          paint,
        );
      }
      drawn += drawing ? segment : gapLength;
      drawing = !drawing;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.2 * scale;
    for (var i = 0; i < lineCount; i++) {
      final x = size.width * i / (lineCount - 1);
      _drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), paint);
    }
    // 上下柱段分界基准线
    final y = size.height * (1 - baselineFromBottom);
    _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.baselineFromBottom != baselineFromBottom ||
        oldDelegate.scale != scale;
  }
}
