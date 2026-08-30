/// 习惯插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/habits/habits_plugin.dart';
import 'package:Memento/plugins/habits/widgets/habit_form.dart';

/// 注册习惯的快速创建项（主页底部 ＋ 按钮）
///
/// 新建的是"习惯"本身（与选中日期无关，不预填日期），打开方式与插件页一致。
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'habits_habit',
      pluginId: 'habits',
      name: 'habits_newHabit'.tr,
      icon: Icons.self_improvement,
      color: Colors.amber,
      onCreate: (context, date) {
        final habitController = HabitsPlugin.instance.getHabitController();
        NavigationHelper.push(
          context,
          Scaffold(
            appBar: AppBar(title: Text('habits_newHabit'.tr)),
            body: Builder(
              builder: (formContext) => HabitForm(
                onSave: (habit) async {
                  await habitController.saveHabit(habit);
                  if (formContext.mounted) {
                    Navigator.pop(formContext);
                  }
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}
