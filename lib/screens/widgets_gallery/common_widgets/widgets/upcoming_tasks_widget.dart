/// 即将到来的任务小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 翻牌计数 + 标题 / 任务列表（数据色竖条 + 标题 + 标签，逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 任务项数据模型
class TaskItem {
  final String title;
  final Color color;
  final String tag;

  const TaskItem({required this.title, required this.color, this.tag = ''});

  /// 从 JSON 创建（用于公共小组件系统）
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      title: json['title'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFF000000),
      tag: json['tag'] as String? ?? '',
    );
  }

  /// 转换为 JSON（用于公共小组件系统）
  Map<String, dynamic> toJson() {
    return {'title': title, 'color': color.value, 'tag': tag};
  }
}

/// 即将到来的任务小组件
class UpcomingTasksWidget extends StatefulWidget {
  final int taskCount;
  final List<TaskItem> tasks;
  final int moreCount;

  /// 自定义标题（默认为 "Upcoming"）
  final String title;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const UpcomingTasksWidget({
    super.key,
    required this.taskCount,
    required this.tasks,
    this.moreCount = 0,
    this.title = 'Upcoming',
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory UpcomingTasksWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final tasksList =
        (props['tasks'] as List<dynamic>?)
            ?.map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return UpcomingTasksWidget(
      taskCount: props['taskCount'] as int? ?? 0,
      tasks: tasksList,
      moreCount: props['moreCount'] as int? ?? 0,
      title: props['title'] as String? ?? 'Upcoming',
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<UpcomingTasksWidget> createState() => _UpcomingTasksWidgetState();
}

class _UpcomingTasksWidgetState extends State<UpcomingTasksWidget>
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
    Widget panel = DsSketchPanel(
      theme: theme,
      width: widget.inline ? double.maxFinite : null,
      height: widget.inline ? double.maxFinite : null,
      radius: BorderRadius.circular(24 * scale),
      padding: widget.size.getPadding(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：任务计数
          _buildTaskCounter(theme),
          SizedBox(width: widget.size.getTitleSpacing()),
          // 右侧：任务列表
          Expanded(child: _buildTaskList(theme)),
        ],
      ),
    );
    if (!widget.inline) {
      panel = ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: panel,
      );
    }
    return WiredDraw(child: panel);
  }

  /// 构建任务计数区域
  Widget _buildTaskCounter(AppThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 添加顶部 padding 以与右侧对齐
        SizedBox(height: widget.size.getItemSpacing()),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return AnimatedFlipCounter(
              value: widget.taskCount.toDouble() * _animation.value,
              textStyle: TextStyle(
                fontSize: widget.size.getLargeFontSize(),
                fontWeight: FontWeight.bold,
                color: theme.text,
                height: 1.0,
              ),
            );
          },
        ),
        SizedBox(height: widget.size.getItemSpacing()),
        SizedBox(
          width: widget.size.getLargeFontSize() * 1.2,
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: widget.size.getSubtitleFontSize() * 0.85,
              fontWeight: FontWeight.w500,
              color: theme.textSub,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建任务列表
  Widget _buildTaskList(AppThemeData theme) {
    return Flexible(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(widget.tasks.length, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom:
                      index < widget.tasks.length - 1
                          ? widget.size.getItemSpacing()
                          : 0,
                ),
                child: _TaskItemWidget(
                  task: widget.tasks[index],
                  animation: _animation,
                  index: index,
                  size: widget.size,
                ),
              );
            }),
            if (widget.moreCount > 0) ...[
              SizedBox(height: widget.size.getItemSpacing()),
              GestureDetector(
                onTap: () {
                  // 处理"查看更多"点击
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('查看更多 ${widget.moreCount} 个任务'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(
                  '+${widget.moreCount} more',
                  style: TextStyle(
                    fontSize: widget.size.getSubtitleFontSize(),
                    fontWeight: FontWeight.w600,
                    color: theme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个任务项组件（数据色竖条 + 标题 + 标签，逐项错峰浮现）
class _TaskItemWidget extends StatelessWidget {
  final TaskItem task;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _TaskItemWidget({
    required this.task,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final itemAnimation = CurvedAnimation(
          parent: animation,
          curve: Interval(
            index * 0.1,
            0.5 + index * 0.1,
            curve: Curves.easeOutCubic,
          ),
        );

        return Opacity(
          opacity: itemAnimation.value,
          child: Transform.translate(
            offset: Offset(10 * (1 - itemAnimation.value), 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('点击任务: ${task.title}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  children: [
                    // 彩色指示条：数据色实底 + 墨线描边
                    Container(
                      width: size.getSmallSpacing() * 1.5,
                      height: size.getSubtitleFontSize(),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(2),
                        fillColor: task.color,
                      ),
                    ),
                    SizedBox(width: size.getItemSpacing()),
                    // 任务标题
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: size.getSubtitleFontSize() * 1.03,
                          fontWeight: FontWeight.w500,
                          color: theme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 标签（显示在右侧）
                    if (task.tag.isNotEmpty) ...[
                      SizedBox(width: size.getItemSpacing()),
                      Text(
                        task.tag,
                        style: TextStyle(
                          fontSize: size.getSubtitleFontSize() * 0.85,
                          fontWeight: FontWeight.w400,
                          color: theme.textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
