/// 日记插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/diary/diary_plugin.dart';
import 'package:Memento/plugins/diary/screens/diary_editor_screen.dart';

/// 注册日记的快速创建项（主页底部 ＋ 按钮）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'diary_entry',
      pluginId: 'diary',
      name: 'diary_quickCreateEntry'.tr,
      icon: Icons.book,
      color: const Color(0xFFD8BFD8),
      onCreate: (context, date) {
        NavigationHelper.push(
          context,
          DiaryEditorScreen(
            date: date,
            storage: DiaryPlugin.instance.storage,
            initialContent: '',
          ),
        );
      },    ),
  );
}
