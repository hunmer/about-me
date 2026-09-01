/// 日记相册插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/calendar_album/screens/entry_editor_screen.dart';

/// 注册相册的快速创建项（主页底部 ＋ 按钮，条目日期预填选中日期）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'calendar_album_entry',
      pluginId: 'calendar_album',
      name: 'calendar_album_new_entry'.tr,
      icon: Icons.photo_library,
      color: const Color.fromARGB(255, 245, 210, 52),
      onCreate: (context, date) {
        NavigationHelper.push(
          context,
          EntryEditorScreen(initialDate: date, isEditing: false),
        );
      },
    ),
  );
}
