/// 活动进度小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 标题/副标题 + 圆形图标徽章 / 翻牌数值 + 单位 + 活动数 /
/// 圆点进度（完成点数据色实底 + 淡墨格描边，逐点错峰入场）。
library;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 活动进度小组件
class CardDotProgressDisplay extends StatefulWidget {
  final String title;
  final String subtitle;
  final double value;
  final String unit;
  final int activities;
  final int totalProgress;
  final int completedProgress;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const CardDotProgressDisplay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.activities,
    required this.totalProgress,
    required this.completedProgress,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory CardDotProgressDisplay.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return CardDotProgressDisplay(
      title: props['title'] as String? ?? '',
      subtitle: props['subtitle'] as String? ?? '',
      value: (props['value'] as num?)?.toDouble() ?? 0.0,
      unit: props['unit'] as String? ?? '',
      activities: props['activities'] as int? ?? 0,
      totalProgress: props['totalProgress'] as int? ?? 0,
      completedProgress: props['completedProgress'] as int? ?? 0,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CardDotProgressDisplay> createState() => _CardDotProgressDisplayState();
}

class _CardDotProgressDisplayState extends State<CardDotProgressDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    // 根据尺寸计算各元素大小
    final iconSize = widget.size.getIconSize() * 0.7;
    final iconContainerSize =
        widget.size.getIconSize() * widget.size.iconContainerScale;
    final titleFontSize = widget.size.getTitleFontSize() * 0.6;
    final subtitleFontSize = widget.size.getSubtitleFontSize();
    final valueFontSize = widget.size.getLargeFontSize() * 0.6;
    final unitFontSize = widget.size.getSubtitleFontSize();

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    Widget card = WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        width: widget.inline ? double.maxFinite : null,
        height: widget.inline ? double.maxFinite : null,
        radius: BorderRadius.circular(24 * widget.size.scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题和图标
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
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: theme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w500,
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 圆形图标徽章：surfaceAlt 实底 + 墨线描边
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  // 大圆角被 rough 引擎自动钳制成圆
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(iconContainerSize / 2),
                    fillColor: theme.surfaceAlt,
                  ),
                  child: Center(
                    child: WiredIcon(
                      icon: Icons.directions_run,
                      size: iconSize,
                      color: theme.primary,
                      drawConfig: theme.wired.drawConfig,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: widget.size.getTitleSpacing()),

            // 数值和活动数
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedFlipCounter(
                  value: widget.value * _animation.value,
                  fractionDigits: 1,
                  textStyle: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
                SizedBox(width: widget.size.getSmallSpacing()),
                SizedBox(
                  height: unitFontSize * 1.5,
                  child: Text(
                    widget.unit,
                    style: TextStyle(
                      fontSize: unitFontSize,
                      fontWeight: FontWeight.w500,
                      color: theme.textSub,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.activities > 0)
                  Text(
                    '${widget.activities} 活动',
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      fontWeight: FontWeight.w500,
                      color: theme.textSub,
                    ),
                  ),
              ],
            ),

            SizedBox(height: widget.size.getItemSpacing()),

            // 进度点
            _ProgressDots(
              total: widget.totalProgress,
              completed: widget.completedProgress,
              color: theme.primary,
              animation: _animation,
              theme: theme,
              size: widget.size,
            ),
          ],
        ),
      ),
    );

    // 非 inline 模式用尺寸档高度约束
    if (!widget.inline) {
      card = ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: card,
      );
    }
    return card;
  }
}

/// 进度点组件（参照 habit_heatmap_card：档位色实底 + 淡墨格描边）
class _ProgressDots extends StatelessWidget {
  final int total;
  final int completed;
  final Color color;
  final Animation<double> animation;
  final AppThemeData theme;
  final HomeWidgetSize size;

  const _ProgressDots({
    required this.total,
    required this.completed,
    required this.color,
    required this.animation,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // 根据尺寸计算点的大小
    final baseDotSize = size.getStrokeWidth() * 0.8;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 计算可用宽度，考虑间距
        final spacing = size.getSmallSpacing();
        final totalSpacing = spacing * (total - 1);
        final availableWidth = constraints.maxWidth - totalSpacing;

        // 计算每个点的实际大小
        final dotSize = (availableWidth / total).clamp(0.5, baseDotSize);

        return Row(
          children: List.generate(total, (index) {
            final isCompleted = index < completed;
            final isLast = index == total - 1;

            // 确保 end 值不超过 1.0
            final start = (index / total) * 0.3;
            final end = (index / total) * 0.3 + 0.5;
            final clampedEnd = end.clamp(0.0, 1.0);

            final dotAnimation = CurvedAnimation(
              parent: animation,
              curve: Interval(start, clampedEnd, curve: Curves.easeOutCubic),
            );

            return Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : spacing),
              child: AnimatedBuilder(
                animation: dotAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: dotAnimation.value,
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * dotAnimation.value,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          // 完成点数据色实底 / 未完成淡底 + 淡墨格描边
                          color: isCompleted ? color : theme.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.ink.withValues(
                              alpha: isCompleted ? 0.45 : 0.22,
                            ),
                            width: size.scale,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        );
      },
    );
  }
}
