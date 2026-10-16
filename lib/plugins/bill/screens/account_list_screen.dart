import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/models/account.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/stacked_accordion_card.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'account_edit_screen.dart';

class AccountListScreen extends StatefulWidget {
  final BillPlugin billPlugin;

  const AccountListScreen({super.key, required this.billPlugin});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  @override
  void initState() {
    super.initState();
    widget.billPlugin.addListener(_onAccountsChanged);

    // 设置路由上下文
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能识别当前页面
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/bill_accounts',
      title: '账户管理',
      params: {},
    );
  }

  @override
  void dispose() {
    widget.billPlugin.removeListener(_onAccountsChanged);
    super.dispose();
  }

  void _onAccountsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            backgroundColor: dsScaffoldBackground(theme),
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(title: 'bill_accountManagement'.tr),
                  Expanded(child: _buildAccountList()),
                ],
              ),
            ),
            floatingActionButton: DSThemeBridge(
              child: DSFab(
                size: 64,
                icon: DsIconKind.plus,
                onPressed:
                    () => SmoothBottomSheet.show(
                      context: context,
                      builder:
                          (context) =>
                              AccountEditScreen(billPlugin: widget.billPlugin),
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountList() {
    if (widget.billPlugin.accounts.isEmpty) {
      return Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Center(
            child: Text(
              'bill_noAccounts'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          );
        },
      );
    }

    final accounts = widget.billPlugin.accounts;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StackedAccordionCardWidget(
        inline: true,
        items: [
          for (final account in accounts) _buildAccountCardData(account),
        ],
        onCardLongPress: (index) => _showAccountActions(context, accounts[index]),
      ),
    );
  }

  /// 将账户映射为堆叠手风琴卡片数据
  StackedAccordionCardData _buildAccountCardData(Account account) {
    final expense = account.bills
        .where((b) => b.isExpense)
        .fold(0.0, (sum, b) => sum + b.absoluteAmount);
    final income = account.bills
        .where((b) => !b.isExpense)
        .fold(0.0, (sum, b) => sum + b.amount);
    final ratio = (expense + income) > 0 ? expense / (expense + income) : 0.0;

    final recent = [...account.bills]..sort((a, b) => b.date.compareTo(a.date));

    return StackedAccordionCardData(
      title: account.title,
      percentage: '¥${account.totalAmount.toStringAsFixed(2)}',
      tags: ['${account.bills.length} 笔账单'],
      progress: ratio,
      progressLabel: '支出占比',
      progressValue: '支出 ¥${expense.toStringAsFixed(0)} · 收入 ¥${income.toStringAsFixed(0)}',
      entries: [
        for (final bill in recent.take(4))
          StackedAccordionEntryData(
            term: bill.subscriptionTitle,
            subtitle:
                '${bill.date.month}/${bill.date.day} · ${bill.isExpense ? '-' : '+'}¥${bill.absoluteAmount.toStringAsFixed(2)}',
          ),
      ],
      backgroundColor: account.backgroundColor,
    );
  }

  /// 长按卡片弹出账户操作菜单（查看账单 / 编辑 / 删除）
  void _showAccountActions(BuildContext context, Account account) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: const Text('查看账单'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _openAccountBills(context, account);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('编辑账户'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _editAccount(context, account);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete, color: theme.danger),
                    title: Text(
                      '删除账户',
                      style: TextStyle(color: theme.danger),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmDelete(context, account);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Account account) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (BuildContext context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'bill_confirmDelete'.tr,
            message: '确定要删除账户"${account.title}"吗？\n删除后该账户下的所有账单记录都将被删除！',
            cancelText: 'bill_cancel'.tr,
            confirmText: '删除',
            confirmVariant: DSButtonVariant.destructive,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      widget.billPlugin.controller.deleteAccount(account.id);
      Toast.success('${'bill_accountDeleted'.tr} "${account.title}"');
    }
  }

  void _openAccountBills(BuildContext context, Account account) {
    // 设置选中的账户
    widget.billPlugin.selectedAccount = account;
    // 返回到主视图并显示选中账户的账单
    NavigationHelper.pushReplacement(
      context,
      widget.billPlugin.buildMainView(context),
    );
  }

  void _editAccount(BuildContext context, Account account) {
    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => AccountEditScreen(
            billPlugin: widget.billPlugin,
            account: account,
          ),
    );
  }
}
