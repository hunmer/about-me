import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/widgets/todo_day_card.dart';

/// 周视图 - 展示从周一到周日的待办事项
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

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        children: [
          // 顶部周信息
          _buildWeekHeader(context, weekDates),
          const SizedBox(height: 8),
          // 七天的卡片布局
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              padding: const EdgeInsets.all(4),
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
    );
  }

  /// 构建周标题
  Widget _buildWeekHeader(BuildContext context, List<DateTime> weekDates) {
    final theme = DSThemeBridge.resolve(context);
    final startDate = weekDates.first;
    final endDate = weekDates.last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.stroke),
      ),
      child: Row(
        children: [
          DsIcon(DsIconKind.calendar, size: 20, color: theme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${startDate.month}月${startDate.day}日 - ${endDate.month}月${endDate.day}日',
              style: DsTypography.label.copyWith(
                color: theme.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '本周任务',
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ],
      ),
    );
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
