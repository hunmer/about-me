/// 彩色标签任务列表卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 翻牌计数 + 标签 / 任务列表（数据色竖条 + 标题 + 标签，逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import '../models/color_tag_task_card_data.dart';

/// 彩色标签任务列表卡片小组件
/// 用于显示带彩色标签的任务列表，支持动画效果
class ColorTagTaskCardWidget extends StatefulWidget {
  /// 卡片数据
  final ColorTagTaskCardData data;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const ColorTagTaskCardWidget({
    super.key,
    required this.data,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例
  factory ColorTagTaskCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    return ColorTagTaskCardWidget(
      data: ColorTagTaskCardData.fromJson(props),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<ColorTagTaskCardWidget> createState() => _ColorTagTaskCardWidgetState();
}

class _ColorTagTaskCardWidgetState extends State<ColorTagTaskCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late Animation<double> _countAnimation;

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
    _countAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
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
        width: widget.inline ? double.maxFinite : 320,
        height: widget.inline ? double.maxFinite : 320,
        radius: BorderRadius.circular(24 * scale),
        padding: widget.size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题区域
            _buildHeader(theme),
            SizedBox(height: widget.size.getTitleSpacing()),
            // 任务列表
            Flexible(child: _buildTaskList()),
            // 底部更多按钮
            if (widget.data.moreCount > 0) _buildMoreButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeData theme) {
    final valueFontSize = widget.size.getLargeFontSize();
    final labelFontSize = widget.size.getSubtitleFontSize();
    final spacing = widget.size.getSmallSpacing();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _countAnimation,
          builder: (context, child) {
            return AnimatedFlipCounter(
              value: widget.data.taskCount.toDouble() * _countAnimation.value,
              textStyle: TextStyle(
                color: theme.text,
                fontSize: valueFontSize,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            );
          },
        ),
        SizedBox(height: spacing),
        Text(
          widget.data.label,
          style: TextStyle(
            color: theme.textSub,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.data.tasks.length; i++) ...[
            if (i > 0) SizedBox(height: widget.size.getItemSpacing()),
            _ColorTagTaskItemWidget(
              task: widget.data.tasks[i],
              animation: _animation,
              index: i,
              size: widget.size,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoreButton(AppThemeData theme) {
    final fontSize = widget.size.getSubtitleFontSize();

    return Padding(
      padding: EdgeInsets.only(top: widget.size.getSmallSpacing()),
      child: GestureDetector(
        onTap: () {},
        child: Text(
          '+${widget.data.moreCount} more',
          style: TextStyle(
            color: theme.primary,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 彩色标签任务项组件（数据色竖条 + 标题 + 标签，逐项错峰浮现）
class _ColorTagTaskItemWidget extends StatelessWidget {
  final ColorTagTaskItem task;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _ColorTagTaskItemWidget({
    required this.task,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final indicatorHeight = size.getLegendIndicatorHeight();
    final indicatorWidth = size.getLegendIndicatorWidth() * 0.2;
    final spacing = size.getSmallSpacing() * 3;
    final titleFontSize = size.getSubtitleFontSize();
    final tagFontSize = size.getLegendFontSize();

    // 确保最后一个元素的 end 不超过 1.0
    final step = 0.05;
    final start = index * step;
    final end = (0.6 + index * step).clamp(0.0, 1.0);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: itemAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - itemAnimation.value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            // 彩色竖条标签：数据色实底 + 墨线描边
            Container(
              width: indicatorWidth,
              height: indicatorHeight,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(2),
                fillColor: Color(task.color),
              ),
            ),
            SizedBox(width: spacing),
            // 任务标题（时间）
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 右侧标签（活动名称）
            if (task.tag.isNotEmpty)
              Text(
                task.tag,
                style: TextStyle(
                  color: theme.textSub,
                  fontSize: tagFontSize,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
