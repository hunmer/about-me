/// 每日待办事项小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 日期 + 时间徽章（墨线实底）/ 待办列表（手绘勾选框，逐项错峰浮现）/
/// 底部提醒（墨线分隔线 + 标签徽章）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 待办任务数据模型
class TodoTask {
  final String title;
  final bool isCompleted;

  const TodoTask({required this.title, required this.isCompleted});

  /// 从 JSON 创建
  factory TodoTask.fromJson(Map<String, dynamic> json) {
    return TodoTask(
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'title': title, 'isCompleted': isCompleted};
  }

  TodoTask copyWith({String? title, bool? isCompleted}) {
    return TodoTask(
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// 提醒信息数据模型
class TodoReminder {
  final String text;
  final String hashtag;
  final String hashtagEmoji;

  const TodoReminder({
    required this.text,
    required this.hashtag,
    required this.hashtagEmoji,
  });

  /// 从 JSON 创建
  factory TodoReminder.fromJson(Map<String, dynamic> json) {
    return TodoReminder(
      text: json['text'] as String? ?? '',
      hashtag: json['hashtag'] as String? ?? '',
      hashtagEmoji: json['hashtagEmoji'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {'text': text, 'hashtag': hashtag, 'hashtagEmoji': hashtagEmoji};
  }
}

/// 每日待办事项小组件
class DailyTodoListWidget extends StatefulWidget {
  final String date;
  final String time;
  final List<TodoTask> tasks;
  final TodoReminder reminder;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const DailyTodoListWidget({
    super.key,
    required this.date,
    required this.time,
    required this.tasks,
    required this.reminder,
    this.inline = false,
    this.size = const MediumSize(),
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory DailyTodoListWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final tasksList =
        (props['tasks'] as List<dynamic>?)
            ?.map((e) => TodoTask.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final reminderJson = props['reminder'] as Map<String, dynamic>?;
    final reminder =
        reminderJson != null
            ? TodoReminder.fromJson(reminderJson)
            : const TodoReminder(text: '', hashtag: '', hashtagEmoji: '');

    return DailyTodoListWidget(
      date: props['date'] as String? ?? '',
      time: props['time'] as String? ?? '',
      tasks: tasksList,
      reminder: reminder,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<DailyTodoListWidget> createState() => _DailyTodoListWidgetState();
}

class _DailyTodoListWidgetState extends State<DailyTodoListWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late List<TodoTask> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = List.from(widget.tasks);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: !_tasks[index].isCompleted,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    // （各分区自带 padding，面板层不再叠加）
    return WiredDraw(
      child: ConstrainedBox(
        constraints: widget.size.getHeightConstraints(),
        child: DsSketchPanel(
          theme: theme,
          width: widget.inline ? double.maxFinite : 360,
          height: widget.inline ? double.maxFinite : 600,
          radius: BorderRadius.circular(24 * scale),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部日期区域
              _HeaderSection(date: widget.date, time: widget.time, size: widget.size),
              // 任务列表
              _TasksSection(
                tasks: _tasks,
                onToggle: _toggleTask,
                animation: _fadeAnimation,
                size: widget.size,
              ),
              // 底部提醒
              _ReminderSection(
                reminder: widget.reminder,
                animation: _fadeAnimation,
                size: widget.size,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部日期区域：日期 + 时间徽章（主题色实底 + 墨线描边）
class _HeaderSection extends StatelessWidget {
  final String date;
  final String time;
  final HomeWidgetSize size;

  const _HeaderSection({
    required this.date,
    required this.time,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Padding(
      padding: size.getPadding(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: size.getTitleFontSize() * 0.8,
                    fontWeight: FontWeight.w500,
                    color: theme.text,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: size.getSmallSpacing() * 1.5),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.getSmallSpacing() * 2,
                    vertical: size.getSmallSpacing() * 0.5,
                  ),
                  decoration: dsSketchDecoration(
                    theme: theme,
                    radius: BorderRadius.circular(size.getSmallSpacing() * 1.5),
                    fillColor: theme.primary,
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: size.getLegendFontSize(),
                      fontWeight: FontWeight.bold,
                      color: theme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务列表区域
class _TasksSection extends StatelessWidget {
  final List<TodoTask> tasks;
  final Function(int) onToggle;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _TasksSection({
    required this.tasks,
    required this.onToggle,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: size.getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder:
                    (context, index) => SizedBox(height: size.getItemSpacing()),
                itemBuilder: (context, index) {
                  return _TaskItem(
                    task: tasks[index],
                    onTap: () => onToggle(index),
                    animation: animation,
                    index: index,
                    size: size,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个任务项（逐项错峰浮现）
class _TaskItem extends StatelessWidget {
  final TodoTask task;
  final VoidCallback onTap;
  final Animation<double> animation;
  final int index;
  final HomeWidgetSize size;

  const _TaskItem({
    required this.task,
    required this.onTap,
    required this.animation,
    required this.index,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final itemAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0.2 + index * 0.1,
        (0.6 + index * 0.1).clamp(0.0, 1.0),
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
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                children: [
                  _Checkbox(isChecked: task.isCompleted, size: size),
                  SizedBox(width: size.getItemSpacing()),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w400,
                        color: task.isCompleted ? theme.textSub : theme.text,
                        decoration:
                            task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 复选框组件：勾选主题色实底 + 手绘勾号，未勾选浅底空格
class _Checkbox extends StatelessWidget {
  final bool isChecked;
  final HomeWidgetSize size;

  const _Checkbox({required this.isChecked, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 根据尺寸调整复选框大小
    final checkboxSize = size.getThumbnailIconSize() * 0.8;
    final iconSize = checkboxSize * 0.67;
    final borderRadius = checkboxSize * 0.25;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: checkboxSize,
      height: checkboxSize,
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(borderRadius),
        fillColor: isChecked ? theme.primary : theme.surfaceAlt,
      ),
      child:
          isChecked
              ? Center(
                child: DsIcon(
                  DsIconKind.check,
                  size: iconSize,
                  color: theme.onPrimary,
                ),
              )
              : null,
    );
  }
}

/// 底部提醒区域：墨线分隔线 + 提醒文本 + 标签徽章
class _ReminderSection extends StatelessWidget {
  final TodoReminder reminder;
  final Animation<double> animation;
  final HomeWidgetSize size;

  const _ReminderSection({
    required this.reminder,
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final reminderAnimation = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: reminderAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: reminderAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - reminderAnimation.value)),
            child: Padding(
              padding: size.getPadding(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 墨线分隔线
                  Container(height: 1, color: theme.ink.withValues(alpha: 0.18)),
                  SizedBox(height: size.getSmallSpacing()),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: size.getSmallSpacing()),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                reminder.text,
                                style: TextStyle(
                                  fontSize: size.getSubtitleFontSize() + 1,
                                  fontWeight: FontWeight.w400,
                                  color: theme.text,
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(width: size.getSmallSpacing()),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: size.getSmallSpacing(),
                                  vertical: size.getSmallSpacing() * 0.5,
                                ),
                                decoration: dsSketchDecoration(
                                  theme: theme,
                                  radius: BorderRadius.circular(
                                    size.getSmallSpacing() * 1.5,
                                  ),
                                  fillColor: theme.surfaceAlt,
                                ),
                                child: Text(
                                  reminder.hashtag,
                                  style: TextStyle(
                                    fontSize: size.getSubtitleFontSize() + 1,
                                    fontWeight: FontWeight.w500,
                                    color: theme.primary,
                                  ),
                                ),
                              ),
                              SizedBox(width: size.getSmallSpacing()),
                              Text(
                                reminder.hashtagEmoji,
                                style: TextStyle(
                                  fontSize: size.getSubtitleFontSize() + 1,
                                  fontWeight: FontWeight.w400,
                                  color: theme.text,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
