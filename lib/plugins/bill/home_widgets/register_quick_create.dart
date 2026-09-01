/// 账单插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/managers/quick_create_registry.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/screens/bill_edit_screen.dart';

/// 注册账单的快速创建项（主页底部 ＋ 按钮）
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'bill_bill',
      pluginId: 'bill',
      name: 'bill_newBill'.tr,
      icon: Icons.account_balance_wallet,
      color: const Color.fromARGB(255, 76, 175, 80),
      onCreate: (context, date) {
        final plugin = BillPlugin.instance;
        final accountId =
            plugin.controller.accounts.isNotEmpty
                ? plugin.controller.accounts.first.id
                : '';
        NavigationHelper.openContainerWithHero(
          context,
          (context) => BillEditScreen(
            billPlugin: plugin,
            accountId: accountId,
            initialDate: date,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    ),
  );
}
