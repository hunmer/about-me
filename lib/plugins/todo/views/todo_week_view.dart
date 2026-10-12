import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/widgets/todo_day_card.dart';

/// 周视图 - 展示从周一到周日的待办事项（手绘纸墨风）
///
/// 周信息头与七张日卡均走手绘面板，挂载时经 [WiredDraw] 播墨线描画入场。
class TodoWeekView extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onTaskTap;
  final Function(Task, TaskStatus) onTaskStatusChanged;
  final Function(DateTime)? onAddTask;

  const TodoWeekView({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskStatusChanged,
    this.onAddTask,
  });

  @override
  Widget build(BuildContext context) {
    // 获取本周的日期范围
    final weekDates = _getCurrentWeekDates();
    // 按日期分组任务
    final tasksByDate = _groupTasksByDate(tasks, weekDates);
    // 本周未完成任务总数
    final weekTaskCount = tasksByDate.values
        .fold(0, (sum, list) => sum + list.length);

    // 经 CustomBottomBar/TabBarView 挂载，自备主题桥保证 DS 组件可用
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          // Tab 切换挂载时墨线描画入场
          return WiredDraw(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                children: [
                  // 顶部周信息
                  _buildWeekHeader(
                    context,
                    weekDates: weekDates,
                    taskCount: weekTaskCount,
                  ),
                  const SizedBox(height: 8),
                  // 七天的卡片布局
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      padding: EdgeInsets.fromLTRB(
                        4,
                        4,
                        4,
                        4 + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: List.generate(7, (index) {
                        return _buildDayCard(
                          context,
                          dayIndex: index,
                          date: weekDates[index],
                          dayTasks: tasksByDate[index] ?? [],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建周标题（大容器走手绘面板：纸底 + 淡排线 + 墨线框）
  Widget _buildWeekHeader(
    BuildContext context, {
    required List<DateTime> weekDates,
    required int taskCount,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final start = _formatShortDate(weekDates.first);
    final end = _formatShortDate(weekDates.last);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.lg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            DsIcon(DsIconKind.calendar, size: 18, color: theme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'todo_weekDateRange'.trParams({'start': start, 'end': end}),
                style: DsTypography.label.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 任务数徽章：小控件走纯色实底 + 墨线描边
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: dsSketchDecoration(
                theme: theme,
                fillColor: theme.primary.withValues(alpha: 0.12),
                stroke: theme.primary.withValues(alpha: 0.55),
                strokeWidth: 1.2,
                radius: theme.radii.pill,
              ),
              child: Text(
                'todo_weekTaskCount'.trParams({'count': '$taskCount'}),
                style: DsTypography.caption.copyWith(
                  fontSize: 10,
                  color: theme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 本地化短日期（如 zh「10月6日」/ en「10/6」）
  String _formatShortDate(DateTime date) {
    return 'todo_monthDay'.trParams({
      'month': '${date.month}',
      'day': '${date.day}',
    });
  }

  /// 构建单日卡片
  Widget _buildDayCard(
    BuildContext context, {
    required int dayIndex,
    required DateTime date,
    required List<Task> dayTasks,
  }) {
    // 排除已完成的任务
    final activeTasks =
        dayTasks.where((t) => t.status != TaskStatus.done).toList();

    return TodoDayCard(
      date: date,
      tasks: activeTasks,
      onTaskTap: onTaskTap,
      onTaskStatusChanged: onTaskStatusChanged,
      onAddTask: onAddTask,
    );
  }

  /// 获取本周的日期列表（周一到周日）
  List<DateTime> _getCurrentWeekDates() {
    final now = DateTime.now();
    // 找到本周一
    final monday = now.subtract(Duration(days: now.weekday - 1));
    // 重置时间部分为 00:00:00
    final normalizedMonday = DateTime(monday.year, monday.month, monday.day);

    // 生成周一到周日的日期
    return List.generate(7, (index) {
      return normalizedMonday.add(Duration(days: index));
    });
  }

  /// 按日期分组任务
  Map<int, List<Task>> _groupTasksByDate(
    List<Task> allTasks,
    List<DateTime> weekDates,
  ) {
    final Map<int, List<Task>> grouped = {};

    for (int i = 0; i < 7; i++) {
      grouped[i] = [];
    }

    for (final task in allTasks) {
      if (task.status == TaskStatus.done) continue;

      // 检查任务的开始日期或截止日期是否在本周的某一天
      final taskDate = task.startDate ?? task.dueDate;
      if (taskDate == null) continue;

      for (int i = 0; i < 7; i++) {
        if (_isSameDay(taskDate, weekDates[i])) {
          grouped[i]!.add(task);
          break;
        }
      }
    }

    return grouped;
  }

  /// 判断两个日期是否是同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
