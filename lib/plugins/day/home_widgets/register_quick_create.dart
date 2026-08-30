/// 纪念日插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/plugins/day/models/memorial_day.dart';
import 'package:Memento/plugins/day/widgets/memorial_day_edit_flow.dart';

/// 注册纪念日的快速创建项（主页底部 ＋ 按钮，目标日期预填选中日期）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'day_memorial',
      pluginId: 'day',
      name: 'day_addMemorialDay'.tr,
      icon: Icons.celebration,
      color: Colors.deepOrange,
      onCreate: (context, date) {
        openMemorialDayEditor(
          context,
          prefilled: MemorialDay(title: '', targetDate: date),
        );
      },
    ),
  );
}
