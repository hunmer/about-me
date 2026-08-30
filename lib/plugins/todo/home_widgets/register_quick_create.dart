/// 待办插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/todo/todo_plugin.dart';
import 'package:Memento/plugins/todo/widgets/task_form.dart';

/// 注册待办的快速创建项（主页底部 ＋ 按钮）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'todo_task',
      pluginId: 'todo',
      name: 'todo_quickCreateTask'.tr,
      icon: Icons.check_box,
      color: Colors.blue,
      onCreate: (context, date) {
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
      },
    ),
  );
}
