/// 圆角任务列表卡片（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 主题色圆点徽章 + 大写标题 / 任务列表（标题 + 副标题 + 日期、
/// 墨线分隔线、逐项错峰浮现）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 任务列表项数据模型
class TaskListItem {
  /// 任务标题
  final String title;

  /// 任务副标题
  final String subtitle;

  /// 任务日期
  final String date;

  const TaskListItem({
    required this.title,
    required this.subtitle,
    required this.date,
  });

  /// 创建副本
  TaskListItem copyWith({
    String? title,
    String? subtitle,
    String? date,
  }) {
    return TaskListItem(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      date: date ?? this.date,
    );
  }

  /// 从 JSON 创建
  factory TaskListItem.fromJson(Map<String, dynamic> json) {
    return TaskListItem(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      date: json['date'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'date': date,
    };
  }
}

/// 圆角任务列表卡片组件
///
/// 用于展示任务列表的高度圆角卡片组件，支持动画效果和主题适配。
/// 显示标题、任务列表和日期信息。
///
/// 使用示例：
/// ```dart
/// RoundedTaskListCard(
///   tasks: [
///     TaskListItem(
///       title: 'Design mobile UI dashboard',
///       subtitle: 'Widgefy UI kit',
///       date: '12 Jan 2021',
///     ),
///     TaskListItem(
///       title: 'Calculate budget and contract',
///       subtitle: 'BetaCRM',
///       date: '1 Feb 2021',
///     ),
///   ],
///   headerText: 'Upcoming',
/// )
/// ```
class RoundedTaskListCard extends StatefulWidget {
  /// 任务列表
  final List<TaskListItem> tasks;

  /// 标题文本
  final String headerText;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const RoundedTaskListCard({
    super.key,
    required this.tasks,
    this.headerText = 'Upcoming',
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory RoundedTaskListCard.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final tasksList =
        (props['tasks'] as List<dynamic>?)
            ?.map((e) => TaskListItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return RoundedTaskListCard(
      tasks: tasksList,
      headerText: props['headerText'] as String? ?? 'Upcoming',
      size: size,
    );
  }

  @override
  State<RoundedTaskListCard> createState() => _RoundedTaskListCardState();
}

class _RoundedTaskListCardState extends State<RoundedTaskListCard>
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

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: 344,
          radius: BorderRadius.circular(24 * widget.size.scale),
          padding: (widget.size.getPadding() * 0.7).copyWith(
            top: widget.size.getPadding().top * 0.8,
            bottom: widget.size.getPadding().bottom * 0.8,
            left: widget.size.getPadding().left * 0.8,
            right: widget.size.getPadding().right * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              _buildHeader(theme),
              SizedBox(height: widget.size.getTitleSpacing() * 1.4),
              // 任务列表 - 支持滚动
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: _buildTaskList(theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(AppThemeData theme) {
    final dotSize = widget.size.getSmallSpacing() * 3;

    return Row(
      children: [
        // 主题色圆点徽章：实底 + 墨线描边（大圆角被 rough 引擎钳成圆）
        Container(
          width: dotSize,
          height: dotSize,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(dotSize / 2),
            fillColor: theme.primary,
          ),
        ),
        SizedBox(width: widget.size.getSmallSpacing() * 2),
        Text(
          widget.headerText.toUpperCase(),
          style: TextStyle(
            fontSize: widget.size.getSubtitleFontSize(),
            fontWeight: FontWeight.w500,
            color: theme.textSub,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  /// 构建任务列表
  List<Widget> _buildTaskList(AppThemeData theme) {
    final widgets = <Widget>[];
    final elementCount = widget.tasks.length;
    const baseStart = 0.0;
    const baseEnd = 0.5;
    // 计算合适的 step 确保最后一个 Interval 的 end <= 1.0
    // step <= (1.0 - baseEnd) / (elementCount - 1)
    final step = elementCount > 1 ? (1.0 - baseEnd) / (elementCount - 1) * 0.9 : 0.1;

    for (int i = 0; i < widget.tasks.length; i++) {
      final task = widget.tasks[i];
      final itemAnimation = CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          baseStart + i * step,
          baseEnd + i * step,
          curve: Curves.easeOutCubic,
        ),
      );

      widgets.add(
        _TaskListItem(
          task: task,
          animation: itemAnimation,
          isLast: i == widget.tasks.length - 1,
          isSmallSize: widget.size is SmallSize,
          size: widget.size,
        ),
      );
    }

    return widgets;
  }
}

/// 任务列表项组件
class _TaskListItem extends StatelessWidget {
  final TaskListItem task;
  final Animation<double> animation;
  final bool isLast;
  final bool isSmallSize;
  final HomeWidgetSize size;

  const _TaskListItem({
    required this.task,
    required this.animation,
    required this.isLast,
    required this.isSmallSize,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              padding: (size.getPadding() * 0.7).copyWith(
                top: size.getPadding().top * 0.8,
                bottom: size.getPadding().bottom * 0.8,
              ),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: theme.ink.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
              ),
              child: isSmallSize
                  ? _buildSmallSizeLayout(theme)
                  : _buildNormalLayout(theme),
            ),
          ),
        );
      },
    );
  }

  /// 小尺寸布局：日期在新行
  Widget _buildSmallSizeLayout(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题和副标题
        Text(
          task.title,
          style: TextStyle(
            fontSize: size.getSubtitleFontSize() + 1,
            fontWeight: FontWeight.w700,
            color: theme.text,
            height: 1.3,
          ),
        ),
        SizedBox(height: size.getSmallSpacing()),
        Text(
          task.subtitle,
          style: TextStyle(
            fontSize: size.getSubtitleFontSize() - 1,
            fontWeight: FontWeight.w500,
            color: theme.textSub,
            height: 1.2,
          ),
        ),
        // 日期在单独新行
        if (task.date.isNotEmpty) ...[
          SizedBox(height: size.getSmallSpacing() * 1.5),
          Text(
            task.date,
            style: TextStyle(
              fontSize: size.getSubtitleFontSize() - 1,
              fontWeight: FontWeight.w700,
              color: theme.primary,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }

  /// 正常布局：日期在右侧
  Widget _buildNormalLayout(AppThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize() + 1,
                  fontWeight: FontWeight.w700,
                  color: theme.text,
                  height: 1.3,
                ),
              ),
              SizedBox(height: size.getSmallSpacing()),
              Text(
                task.subtitle,
                style: TextStyle(
                  fontSize: size.getSubtitleFontSize() - 1,
                  fontWeight: FontWeight.w500,
                  color: theme.textSub,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (task.date.isNotEmpty) ...[
          SizedBox(width: size.getSmallSpacing() * 3),
          Text(
            task.date,
            style: TextStyle(
              fontSize: size.getSubtitleFontSize() - 1,
              fontWeight: FontWeight.w700,
              color: theme.primary,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
