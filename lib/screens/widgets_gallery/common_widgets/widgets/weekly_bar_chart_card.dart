/// 周条形图小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 双层斜纹周条形（上层淡墨纹轨道段 + 下层主色数据段，胶囊端）/
/// 翻牌百分比计数 + 手绘徽章副标题。
/// 条形生长与计数动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 周条形数据（公共小组件版本）
class CommonWeeklyBarData {
  final String label;
  final double upperHeight;
  final double lowerHeight;

  const CommonWeeklyBarData({
    required this.label,
    required this.upperHeight,
    required this.lowerHeight,
  });

  /// 从 JSON 创建
  factory CommonWeeklyBarData.fromJson(Map<String, dynamic> json) {
    return CommonWeeklyBarData(
      label: json['label'] as String? ?? '',
      upperHeight: (json['upperHeight'] as num?)?.toDouble() ?? 0.0,
      lowerHeight: (json['lowerHeight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'upperHeight': upperHeight,
      'lowerHeight': lowerHeight,
    };
  }
}

/// 周条形图小组件（公共小组件版本）
class CommonWeeklyBarChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final int percentage;
  final List<CommonWeeklyBarData> weeklyData;
  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;
  /// 组件尺寸
  final HomeWidgetSize size;

  const CommonWeeklyBarChartCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.percentage,
    required this.weeklyData,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CommonWeeklyBarChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final weeklyDataList = props['weeklyData'] as List?;
    final weeklyData = weeklyDataList?.map((item) {
      return CommonWeeklyBarData.fromJson(item as Map<String, dynamic>);
    }).toList() ?? <CommonWeeklyBarData>[];

    return CommonWeeklyBarChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      percentage: props['percentage'] as int? ?? 0,
      weeklyData: weeklyData,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CommonWeeklyBarChartCardWidget> createState() =>
      _CommonWeeklyBarChartCardWidgetState();
}

class _CommonWeeklyBarChartCardWidgetState
    extends State<CommonWeeklyBarChartCardWidget>
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
        height:
            widget.inline
                ? double.maxFinite
                : widget.size.getHeightConstraints().maxHeight,
        width: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 条形图区域
            Expanded(
              child: _WeeklyBars(
                data: widget.weeklyData,
                animation: _animation,
                theme: theme,
                size: widget.size,
              ),
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            // 底部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: widget.size.getLargeFontSize() * 0.8,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return AnimatedFlipCounter(
                        value: widget.percentage.toDouble() *
                            _animation.value,
                        fractionDigits: 0,
                        suffix: '%',
                        textStyle: TextStyle(
                          fontSize: widget.size.getLargeFontSize() * 0.5,
                          fontWeight: FontWeight.bold,
                          color: theme.text,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      );
                    },
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: widget.size.getPadding().right * 0.6,
                        vertical: widget.size.getSmallSpacing() * 2),
                    // 手绘徽章：主色淡底 + 墨线描边
                    decoration: dsSketchDecoration(
                      theme: theme,
                      radius: BorderRadius.circular(999),
                      fillColor: theme.primary.withValues(alpha: 0.16),
                    ),
                    child: Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: widget.size.getSubtitleFontSize() * 0.8,
                        fontWeight: FontWeight.w500,
                        color: theme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 周条形图组件
class _WeeklyBars extends StatelessWidget {
  final List<CommonWeeklyBarData> data;
  final Animation<double> animation;
  final AppThemeData theme;
  final HomeWidgetSize size;

  const _WeeklyBars({
    required this.data,
    required this.animation,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (index) {
        final item = data[index];
        final step = 0.08;
        final barAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(
            index * step,
            0.5 + index * step,
            curve: Curves.easeOutCubic,
          ),
        );

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.getItemSpacing() / 2),
            child: Column(
              children: [
                // 条形图容器（轨道底）
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: BorderRadius.circular(size.getPadding().right * 0.75),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 上层轨道段：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边
                        AnimatedBuilder(
                          animation: barAnimation,
                          builder: (context, child) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: size.getSmallSpacing() * 1.5),
                              child: CustomPaint(
                                size: Size.fromHeight(
                                  100 * item.upperHeight * barAnimation.value,
                                ),
                                painter: _TrackBarPainter(
                                  theme: theme,
                                  scale: size.scale,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: size.getSmallSpacing()),
                        // 下层数据段：主色浅底 + 主色浓斜纹 + 主色描边
                        AnimatedBuilder(
                          animation: barAnimation,
                          builder: (context, child) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: size.getSmallSpacing() * 1.25),
                              child: CustomPaint(
                                size: Size.fromHeight(
                                  100 * item.lowerHeight * barAnimation.value,
                                ),
                                painter: _StripedBarPainter(
                                  color: theme.primary,
                                  scale: size.scale,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: size.getSmallSpacing()),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: size.getSmallSpacing() * 2),
                // 标签（small size 下隐藏）
                if (size is! SmallSize)
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: size.getLegendFontSize(),
                      fontWeight: FontWeight.w500,
                      color: theme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// 轨道段绘制器：surfaceAlt 底 + 淡墨斜纹（0.28）+ 淡墨描边（0.45）（§9.5 轨道规范）
class _TrackBarPainter extends CustomPainter {
  final AppThemeData theme;
  final double scale;

  const _TrackBarPainter({required this.theme, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(rrect),
      rect,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackBarPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.scale != scale;
  }
}

/// 数据段绘制器：主色浅底（0.28）+ 主色浓斜纹（0.9）+ 主色描边（0.85）（§9.5 数据规范）
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
