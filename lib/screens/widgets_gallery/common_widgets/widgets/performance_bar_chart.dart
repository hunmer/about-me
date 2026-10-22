/// 性能指标柱状图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 翻牌增长率 + 周期文案 / 淡墨虚线网格 + 斜纹柱（数据色浅底 +
/// 数据色浓斜纹 + 数据色描边，顶部石灰黄帽 + 柱内标签）/
/// 手绘图例色点 + 页脚。
/// 柱高生长、翻牌与标签浮现动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 柱状图数据模型
class PerformanceBarData {
  final double value;
  final String label;

  const PerformanceBarData({required this.value, required this.label});

  /// 从 JSON 创建
  factory PerformanceBarData.fromJson(Map<String, dynamic> json) {
    return PerformanceBarData(
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'value': value, 'label': label};
  }
}

/// 性能指标柱状图小组件
class PerformanceBarChartWidget extends StatefulWidget {
  final double growthPercentage;
  final String timePeriod;
  final List<PerformanceBarData> barData;
  final String footerLabel;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const PerformanceBarChartWidget({
    super.key,
    required this.growthPercentage,
    required this.timePeriod,
    required this.barData,
    required this.footerLabel,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory PerformanceBarChartWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final barDataList =
        (props['barData'] as List<dynamic>?)
            ?.map((e) => PerformanceBarData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return PerformanceBarChartWidget(
      growthPercentage: (props['growthPercentage'] as num?)?.toDouble() ?? 0.0,
      timePeriod: props['timePeriod'] as String? ?? '',
      barData: barDataList,
      footerLabel: props['footerLabel'] as String? ?? '',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<PerformanceBarChartWidget> createState() =>
      _PerformanceBarChartWidgetState();
}

class _PerformanceBarChartWidgetState extends State<PerformanceBarChartWidget>
    with SingleTickerProviderStateMixin {
  /// 数据色（柱体主色 + 顶部强调帽，属数据不属于主题）
  static const primaryColor = Color(0xFF7c71f5);
  static const accentLime = Color(0xFFdcfeb6);

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
        width: widget.inline ? double.maxFinite : 360,
        height:
            widget.inline
                ? double.maxFinite
                : widget.size.getHeightConstraints().maxHeight,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return AnimatedFlipCounter(
                      value: widget.growthPercentage * _animation.value,
                      fractionDigits: 0,
                      prefix: '+',
                      suffix: '%',
                      duration: const Duration(milliseconds: 1000),
                      textStyle: TextStyle(
                        fontSize: widget.size.getLargeFontSize(),
                        fontWeight: FontWeight.w500,
                        color: theme.text,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    );
                  },
                ),
                SizedBox(height: widget.size.getSmallSpacing()),
                Text(
                  widget.timePeriod,
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 柱状图区域使用 Expanded 获取可用高度
            Expanded(
              // 子级全为 Positioned 时 Stack 尺寸取 constraints.smallest，
              // Column.start 下横向是宽松约束会缩成 0 宽，须 expand 撑满
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 淡墨虚线网格
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedGridPainter(
                        color: theme.ink.withValues(alpha: 0.18),
                        lineCount: 4,
                        scale: scale,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.size.getItemSpacing() / 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(widget.barData.length, (
                          index,
                        ) {
                          final bar = widget.barData[index];
                          final start = index * 0.1;
                          final end = (0.6 + index * 0.08).clamp(0.0, 1.0);
                          final barAnimation = CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              start,
                              end,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    widget.size.getItemSpacing() / 4,
                              ),
                              child: _AnimatedBar(
                                value: bar.value,
                                label: bar.label,
                                primaryColor: primaryColor,
                                accentLime: accentLime,
                                animation: barAnimation,
                                size: widget.size,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: [
                  // 手绘图例色块（§9.5 小控件档）
                  Container(
                    width: 8,
                    height: 8,
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(4),
                      fillColor: primaryColor,
                    ),
                  ),
                  SizedBox(width: widget.size.getItemSpacing()),
                  Text(
                    widget.footerLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: widget.size.getLegendFontSize(),
                      fontWeight: FontWeight.w700,
                      color: theme.textSub,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final double value;
  final String label;
  final Color primaryColor;
  final Color accentLime;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _AnimatedBar({
    required this.value,
    required this.label,
    required this.primaryColor,
    required this.accentLime,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animatedValue = value * animation.value;
        final showLabel = animation.value > 0.5;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: animatedValue / 100,
                    alignment: Alignment.bottomCenter,
                    child: CustomPaint(
                      painter: _PerfBarPainter(
                        color: primaryColor,
                        scale: size.scale,
                      ),
                      child: Stack(
                        children: [
                          // 顶部石灰黄数据帽
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: accentLime,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (showLabel)
                            Positioned(
                              top: 12,
                              left: 0,
                              right: 0,
                              child: Opacity(
                                opacity: (animation.value - 0.5) * 2,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: size.getLegendFontSize(),
                                    fontWeight: FontWeight.w700,
                                    color: theme.text,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

/// 性能柱绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直几何（顶部圆角，无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _PerfBarPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _PerfBarPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(8 * scale),
      topRight: Radius.circular(8 * scale),
    );

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
  bool shouldRepaint(covariant _PerfBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

/// 淡墨虚线网格：横向虚线均布
class _DashedGridPainter extends CustomPainter {
  final Color color;
  final int lineCount;
  final double scale;

  const _DashedGridPainter({
    required this.color,
    required this.lineCount,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || lineCount < 2) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1.2 * scale;
    for (var row = 0; row < lineCount; row++) {
      final y = size.height * row / (lineCount - 1);
      for (var x = 0.0; x < size.width; x += 10 * scale) {
        canvas.drawLine(
          Offset(x, y),
          Offset(
            x + 5 * scale > size.width ? size.width : x + 5 * scale,
            y,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.scale != scale;
  }
}
