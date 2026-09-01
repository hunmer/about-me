/// 活动插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/activity/screens/activity_edit_screen.dart';

/// 注册活动的快速创建项（主页底部 ＋ 按钮）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'activity_record',
      pluginId: 'activity',
      name: 'activity_addActivity'.tr,
      icon: Icons.timeline,
      color: Colors.pink,
      onCreate: (context, date) {
        NavigationHelper.push(
          context,
          ActivityEditScreen(selectedDate: date),
        );
      },
    ),
  );
}
