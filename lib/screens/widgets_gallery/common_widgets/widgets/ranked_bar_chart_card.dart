/// 排名条形图卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题 / 副标题 / 计数 / 斜纹排名条（数据色浅底 + 数据色浓斜纹 +
/// 数据色描边，右端圆角，条内标签 + 翻牌数值）。
/// 条宽生长与数值翻牌动画保留。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// 排名条目数据模型
class RankedBarItem {
  final String label;
  final double value;
  final Color color;

  const RankedBarItem({
    required this.label,
    required this.value,
    required this.color,
  });

  factory RankedBarItem.fromJson(Map<String, dynamic> json) {
    return RankedBarItem(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      color: Color(json['color'] as int? ?? 0xFF000000),
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value, 'color': color.value};
  }
}

class RankedBarChartCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String itemCount;
  final List<RankedBarItem> items;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const RankedBarChartCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.items,
    this.inline = false,
    this.size = const MediumSize(),
  });

  factory RankedBarChartCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList =
        (props['items'] as List<dynamic>?)
            ?.map((e) => RankedBarItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return RankedBarChartCardWidget(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      itemCount: props['itemCount'] as String? ?? '',
      items: itemsList,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<RankedBarChartCardWidget> createState() =>
      _RankedBarChartCardWidgetState();
}

class _RankedBarChartCardWidgetState extends State<RankedBarChartCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
        height: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: widget.size.getTitleFontSize(),
                fontWeight: FontWeight.bold,
                color: theme.text,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              maxLines: 1,
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: widget.size.getSubtitleFontSize(),
                color: theme.textSub,
                height: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              maxLines: 1,
            ),
            SizedBox(height: widget.size.getTitleSpacing()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.itemCount,
                  style: TextStyle(
                    fontSize: widget.size.getLegendFontSize(),
                    fontWeight: FontWeight.w500,
                    color: theme.textSub,
                  ),
                ),
              ],
            ),
            SizedBox(height: widget.size.getItemSpacing()),
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxValue = widget.items.first.value;
                    final maxWidth = constraints.maxWidth;
                    return Column(
                      children:
                          widget.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final step = 0.05;
                            final start = index * step;
                            final end = (0.6 + index * step).clamp(0.0, 1.0);
                            final itemAnimation = CurvedAnimation(
                              parent: _animationController,
                              curve: Interval(
                                start,
                                end,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                            return _RankedBarWidget(
                              item: item,
                              animation: itemAnimation,
                              isLast: index == widget.items.length - 1,
                              size: widget.size,
                              maxValue: maxValue,
                              maxWidth: maxWidth,
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankedBarWidget extends StatelessWidget {
  final RankedBarItem item;
  final Animation<double> animation;
  final bool isLast;
  final HomeWidgetSize size;
  final double maxValue;
  final double maxWidth;

  const _RankedBarWidget({
    required this.item,
    required this.animation,
    required this.isLast,
    required this.size,
    required this.maxValue,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animatedValue = item.value * animation.value;
        final width =
            maxValue > 0 ? (animatedValue / maxValue) * maxWidth : 0.0;

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
          height: size.getRankedBarItemHeight(),
          child: Row(
            children: [
              // 斜纹排名条：数据色浅底 + 数据色浓斜纹 + 数据色描边（右端圆角）
              CustomPaint(
                painter: _RankBarPainter(
                  color: item.color,
                  scale: size.scale,
                ),
                child: SizedBox(
                  width: width,
                  height: size.getRankedBarItemHeight(),
                  child: ClipRect(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: size.getPadding().left,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: size.getLegendFontSize(),
                                fontWeight: FontWeight.w600,
                                color: theme.text,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedFlipCounter(
                            value: item.value * 100.0 * animation.value,
                            fractionDigits: 0,
                            textStyle: TextStyle(
                              fontSize: size.getLegendFontSize(),
                              fontWeight: FontWeight.w600,
                              color: theme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 排名条绘制器：数据色浅底（0.28）+ 数据色浓斜纹（0.9）+ 数据色描边（0.85）
///
/// 平直几何（右端圆角，无 rough 抖动），保证读数清晰（§9.5 统计图表规范）。
class _RankBarPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _RankBarPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(2 * scale),
      bottomLeft: Radius.circular(2 * scale),
      topRight: Radius.circular(6 * scale),
      bottomRight: Radius.circular(6 * scale),
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
  bool shouldRepaint(covariant _RankBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}
