/// 每日条形图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 手绘圆形图标徽章 + 标题头部 / 翻牌计数器 / 横向滚动斜纹条形
/// （数据色浅底 + 数据色浓斜纹 + 数据色描边，胶囊端）。
/// 条形生长与计数动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 条形颜色枚举
enum DailyBarColor { teal, red }

/// 条形颜色扩展
extension DailyBarColorExtension on DailyBarColor {
  String toJson() => name;

  static DailyBarColor fromJson(String value) {
    return DailyBarColor.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DailyBarColor.teal,
    );
  }
}

/// 每日条形数据
class DailyBarData {
  final double height;
  final DailyBarColor color;

  const DailyBarData({required this.height, required this.color});

  /// 从 JSON 创建
  factory DailyBarData.fromJson(Map<String, dynamic> json) {
    return DailyBarData(
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      color: DailyBarColorExtension.fromJson(
        json['color'] as String? ?? 'teal',
      ),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'height': height, 'color': color.toJson()};
  }
}

/// 每日条形图小组件
class DailyBarChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final int value;
  final String unit;
  final List<DailyBarData> bars;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const DailyBarChartCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.bars,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory DailyBarChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final barsList =
        (props['bars'] as List<dynamic>?)
            ?.map((e) => DailyBarData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return DailyBarChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      value: props['value'] as int? ?? 0,
      unit: props['unit'] as String? ?? '',
      bars: barsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<DailyBarChartCardWidget> createState() => _DailyBarChartCardWidgetState();
}

class _DailyBarChartCardWidgetState extends State<DailyBarChartCardWidget>
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
    final badgeSize = widget.size.getIconSize() * 1.6;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : 384 * scale,
        height: widget.inline ? double.maxFinite : 280 * scale,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: widget.size.getTitleFontSize(),
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: widget.size.getSmallSpacing()),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: widget.size.getSubtitleFontSize(),
                          fontWeight: FontWeight.w500,
                          color: theme.textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  // 大圆角被 rough 引擎自动钳制成圆
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(badgeSize / 2),
                    fillColor: theme.surfaceAlt,
                  ),
                  child: Center(
                    child: WiredIcon(
                      icon: Icons.directions_walk,
                      size: widget.size.getIconSize(),
                      color: theme.primary,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  height: widget.size.getLargeFontSize(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFlipCounter(
                            value:
                                widget.value.toDouble() * _animation.value,
                            fractionDigits: 0,
                            textStyle: TextStyle(
                              fontSize: widget.size.getLargeFontSize(),
                              fontWeight: FontWeight.bold,
                              color: theme.text,
                              letterSpacing: -1,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: widget.size.getSmallSpacing()),
                      SizedBox(
                        height: widget.size.getSubtitleFontSize() + 4,
                        child: Text(
                          widget.unit,
                          style: TextStyle(
                            fontSize: widget.size.getSubtitleFontSize(),
                            fontWeight: FontWeight.w500,
                            color: theme.textSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            Expanded(
              child: _DailyBars(
                bars: widget.bars,
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

class _DailyBars extends StatelessWidget {
  final List<DailyBarData> bars;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _DailyBars({
    required this.bars,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 数据色（teal/red 由 DailyBarColor 数据语义决定，属数据不属于主题）
    const tealColor = Color(0xFF2DD4BF);
    const redColor = Color(0xFFFB7185);

    final barWidth = size.getBarWidth();
    final barSpacing = size.getItemSpacing() / 2;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars.length, (index) {
          final bar = bars[index];
          final step = 0.015;
          final barAnimation = CurvedAnimation(
            parent: animation,
            curve: Interval(
              index * step,
              0.55 + index * step,
              curve: Curves.easeOutCubic,
            ),
          );

          final baseColor =
              bar.color == DailyBarColor.teal ? tealColor : redColor;
          final fullBarHeight = size.getLargeFontSize() * 2 * bar.height;

          return Padding(
            padding: EdgeInsets.only(right: barSpacing),
            child: AnimatedBuilder(
              animation: barAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(barWidth, fullBarHeight * barAnimation.value),
                  painter: _StripedBarPainter(
                    color: baseColor,
                    scale: size.scale,
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

/// 斜纹条形绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
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
