/// 账单插件 - 账单日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/bill/bill_plugin.dart';
import 'package:Memento/plugins/bill/models/bill.dart';
import 'package:Memento/plugins/bill/screens/bill_edit_screen.dart';
import 'package:Memento/plugins/bill/widgets/bill_day_card.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 获取指定日期的账单（按业务日期 bill.date 归属，与账单日历视图一致）
List<Bill> _billsForDate(DateTime date) {
  final controller = BillPlugin.instance.controller;
  final bills =
      controller.accounts
          .expand((account) => account.bills)
          .where((bill) => _isSameDay(bill.date, date))
          .toList();

  if (HomeDateController().sortOption == DateViewSortOption.time) {
    bills.sort((a, b) => a.date.compareTo(b.date));
  }
  return bills;
}

/// 打开新建账单表单（预填该日日期）
void _openBillEditor(BuildContext context, DateTime date) {
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
}

/// 注册账单日卡小组件（展示主页选中日期的账单）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'bill_day_card',
      pluginId: 'bill',
      name: 'bill_dayCardName'.tr,
      description: 'bill_dayCardDesc'.tr,
      icon: Icons.account_balance_wallet,
      color: const Color.fromARGB(255, 76, 175, 80),
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return _billsForDate(date).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _BillDayCardHomeWidget(),
    ),
  );
}

/// 账单日卡内容：读取主页选中日期，过滤该日账单后用 BillDayCard 渲染
class _BillDayCardHomeWidget extends StatelessWidget {
  const _BillDayCardHomeWidget();

  @override
  Widget build(BuildContext context) {
    try {
      final plugin = BillPlugin.instance;

      // 监听账单数据变化（controller 为 ChangeNotifier）与主页选中日期
      return AnimatedBuilder(
        animation: Listenable.merge([
          plugin.controller,
          HomeDateController(),
        ]),
        builder: (context, _) {
          final date = HomeDateController().date;

          return BillDayCard(
            date: date,
            bills: _billsForDate(date),
            onBillTap: (bill) => _openBillEditorFor(context, bill),
            onAddBill: (date) => _openBillEditor(context, date),
          );
        },
      );
    } catch (e) {
      return HomeWidget.buildErrorWidget(context, e.toString());
    }
  }

  /// 打开账单编辑页（与账单列表点击一致）
  void _openBillEditorFor(BuildContext context, Bill bill) {
    NavigationHelper.openContainer<bool>(
      context,
      (context) => BillEditScreen(
        billPlugin: BillPlugin.instance,
        accountId: bill.accountId,
        bill: bill,
      ),
    );
  }
}
