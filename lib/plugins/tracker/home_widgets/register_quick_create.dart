/// 追踪插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/plugins/tracker/widgets/record_day_card.dart';

/// 注册追踪的快速创建项（主页底部 ＋ 按钮）
///
/// 添加的是一条目标记录：多目标时先选择目标，再打开记录弹窗（日期预填选中日期）。
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'tracker_record',
      pluginId: 'tracker',
      name: 'tracker_addRecord'.tr,
      icon: Icons.flag,
      color: Colors.red,
      onCreate: (context, date) {
        openRecordCreateFlow(context, date);
      },
    ),
  );
}
