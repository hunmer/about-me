/// 待办插件 - 待办日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/widgets/smooth_bottom_sheet.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/todo/models/task.dart';
import 'package:Memento/plugins/todo/todo_plugin.dart';
import 'package:Memento/plugins/todo/views/todo_item_detail.dart';
import 'package:Memento/plugins/todo/widgets/todo_day_card.dart';
import 'package:Memento/plugins/todo/widgets/task_form.dart';

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

      // 同时监听任务数据变化和主页选中日期变化
      return AnimatedBuilder(
        animation: Listenable.merge([
          plugin.taskController,
          HomeDateController(),
        ]),
        builder: (context, _) {
          final date = HomeDateController().date;

          // 与周视图一致的过滤规则：未完成 + 开始日期（或截止日期）落在选中日
          final dayTasks = plugin.taskController.tasks
              .where((t) => t.status != TaskStatus.done)
              .where((t) {
                final taskDate = t.startDate ?? t.dueDate;
                return taskDate != null && _isSameDay(taskDate, date);
              })
              .toList();

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
      isScrollControlled: true,
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

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
