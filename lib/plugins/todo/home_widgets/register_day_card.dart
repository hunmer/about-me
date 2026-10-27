/// 待办插件 - 待办日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/home_widget_registry.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/home_screen/widgets/home_widget.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/todo/models/task.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:aboutme/plugins/todo/views/todo_item_detail.dart';
import 'package:aboutme/plugins/todo/widgets/todo_day_card.dart';
import 'package:aboutme/plugins/todo/widgets/task_form.dart';

/// 判断指定日期是否已有未完成任务（日期视图据此决定是否显示卡片）
bool _hasActiveTasksForDate(DateTime date) {
  try {
    final tasks = TodoPlugin.instance.taskController.tasks;
    return tasks.any((t) => t.status != TaskStatus.done && _taskDate(t, date));
  } catch (_) {
    return false;
  }
}

/// 与周视图一致的任务归属判断：startDate（或 dueDate）落在该日
bool _taskDate(Task t, DateTime date) {
  final taskDate = t.startDate ?? t.dueDate;
  return taskDate != null && _isSameDay(taskDate, date);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 按日期视图的排序选项排列任务
List<Task> _applySort(List<Task> tasks) {
  switch (HomeDateController().sortOption) {
    case DateViewSortOption.priority:
      tasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      break;
    case DateViewSortOption.time:
      tasks.sort((a, b) => _taskTime(a).compareTo(_taskTime(b)));
      break;
    case DateViewSortOption.def:
      break;
  }
  return tasks;
}

/// 任务的时间排序键：开始时刻 → 截止 → 开始日 → 创建时间
DateTime _taskTime(Task t) {
  return t.startTime ?? t.dueDate ?? t.startDate ?? t.createdAt;
}

/// 注册待办日卡小组件（展示主页选中日期的待办）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'todo_day_card',
      pluginId: 'todo',
      name: 'todo_dayCardName'.tr,
      description: 'todo_dayCardDesc'.tr,
      icon: Icons.event_available,
      color: Colors.blue,
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryTools'.tr,
      isDateDriven: true,
      hasDateData: (date) async => _hasActiveTasksForDate(date),
      dateCardRoute: AppRoutes.todo,
      dateStatsProvider: (date) async {
        final tasks = TodoPlugin.instance.taskController.tasks
            .where((t) => t.status != TaskStatus.done && _taskDate(t, date))
            .toList();
        return [
          DateStatItem(
            label: 'todo_dateStatLabel'.tr,
            value: tasks.length.toString(),
            unit: '项',
          ),
        ];
      },
      builder: (context, config) => const _TodoDayCardHomeWidget(),
    ),
  );
}

/// 待办日卡内容：读取主页选中日期，过滤该日任务后用 TodoDayCard 渲染
class _TodoDayCardHomeWidget extends StatelessWidget {
  const _TodoDayCardHomeWidget();

  @override
  Widget build(BuildContext context) {
    try {
      final plugin = TodoPlugin.instance;

      // 同时监听任务数据变化、主页选中日期和排序变化
      return AnimatedBuilder(
        animation: Listenable.merge([
          plugin.taskController,
          HomeDateController(),
        ]),
        builder: (context, _) {
          final date = HomeDateController().date;

          // 与周视图一致的过滤规则：未完成 + 开始日期（或截止日期）落在选中日
          final dayTasks = _applySort(
            plugin.taskController.tasks
                .where((t) => t.status != TaskStatus.done)
                .where((t) => _taskDate(t, date))
                .toList(),
          );

          return TodoDayCard(
            date: date,
            tasks: dayTasks,
            onTaskTap: (task) => _showTaskDetail(context, task),
            onTaskStatusChanged: (task, status) =>
                plugin.taskController.updateTaskStatus(task.id, status),
            onAddTask: (date) => _openTaskForm(context, date),
          );
        },
      );
    } catch (e) {
      return HomeWidget.buildErrorWidget(context, e.toString());
    }
  }

  /// 打开任务详情（与插件页一致）
  void _showTaskDetail(BuildContext context, Task task) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => TodoItemDetail(
        task: task,
        taskController: TodoPlugin.instance.taskController,
      ),
    );
  }

  /// 打开新建任务表单（预填该日日期）
  void _openTaskForm(BuildContext context, DateTime date) {
    final plugin = TodoPlugin.instance;
    NavigationHelper.openContainerWithHero(
      context,
      (context) => TaskForm(
        taskController: plugin.taskController,
        reminderController: plugin.reminderController,
        initialStartDate: date,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
