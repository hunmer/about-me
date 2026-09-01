/// 日历插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/calendar/calendar_plugin.dart';
import 'package:aboutme/plugins/calendar/pages/event_edit_page.dart';

/// 注册日历的快速创建项（主页底部 ＋ 按钮）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'calendar_event',
      pluginId: 'calendar',
      name: 'calendar_quickAddEvent'.tr,
      icon: Icons.event,
      color: const Color.fromARGB(255, 211, 91, 91),
      onCreate: (context, date) {
        final plugin = CalendarPlugin.instance;
        NavigationHelper.push(
          context,
          EventEditPage(
            initialDate: date,
            onSave: (event) {
              plugin.controller.addEvent(event);
              plugin.controller.refresh();
            },
          ),
        );
      },
    ),
  );
}
