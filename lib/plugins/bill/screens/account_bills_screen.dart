import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/bill/models/bill.dart';
import 'bill_edit_screen.dart' as bill_edit;
import 'package:aboutme/plugins/bill/bill_plugin.dart';
import 'package:aboutme/plugins/bill/models/account.dart';
import 'package:aboutme/plugins/bill/models/statistic_range.dart';
import 'package:aboutme/plugins/bill/widgets/bill_statistics_card.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';

class AccountBillsScreen extends StatefulWidget {
  final BillPlugin billPlugin;
  final Account account;

  const AccountBillsScreen({
    super.key,
    required this.billPlugin,
    required this.account,
  });

  @override
  State<AccountBillsScreen> createState() => _AccountBillsScreenState();
}

class _AccountBillsScreenState extends State<AccountBillsScreen> {
  StatisticRange _selectedRange = StatisticRange.month;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.title),
        actions: [
          // 统计范围选择(DSPopover 经根 Overlay 展示,需 DSThemeBridge 包裹)
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSPopover(
                  width: 190,
                  contentBuilder: (popoverContext, close) {
                    final popoverTheme = DSThemeBridge.resolve(popoverContext);
                    Widget menuRow(StatisticRange range, String label) {
                      return Pressable(
                        onPressed: () {
                          close();
                          setState(() {
                            _selectedRange = range;
                            if (range != StatisticRange.custom) {
                              _customStartDate = null;
                              _customEndDate = null;
                            } else {
                              _showDateRangePicker();
                            }
                          });
                        },
                        builder: (context, states) {
                          final pressed = states.contains(WidgetState.pressed);
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: popoverTheme.spacing.sm,
                              vertical: popoverTheme.spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: pressed ? popoverTheme.surfaceAlt : null,
                              borderRadius: popoverTheme.radii.sm,
                            ),
                            child: Row(
                              children: [
                                DsIcon(
                                  _selectedRange == range
                                      ? DsIconKind.check
                                      : DsIconKind.sort,
                                  size: 18,
                                  color: popoverTheme.text,
                                ),
                                SizedBox(width: popoverTheme.spacing.sm),
                                Text(
                                  label,
                                  style: DsTypography.body.copyWith(
                                    color: popoverTheme.text,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        menuRow(StatisticRange.week, 'bill_thisWeek'.tr),
                        menuRow(StatisticRange.month, 'bill_thisMonth'.tr),
                        menuRow(StatisticRange.year, 'bill_thisYear'.tr),
                        menuRow(StatisticRange.all, 'bill_all'.tr),
                        menuRow(StatisticRange.custom, 'bill_custom'.tr),
                      ],
                    );
                  },
                  child: JellyBox(
                    width: 40,
                    height: 40,
                    radius: theme.radii.circle,
                    color: theme.surfaceAlt,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.sort,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: DSThemeBridge(
        child: DSFab(
          icon: DsIconKind.plus,
          onPressed: () => _createBill(context),
        ),
      ),
    );
  }

  // 添加一个账户引用来存储最新的账户数据
  late Account _currentAccount;

  @override
  void initState() {
    super.initState();
    _currentAccount = widget.account;
    widget.billPlugin.addListener(_handlePluginUpdate);
  }

  @override
  void dispose() {
    widget.billPlugin.removeListener(_handlePluginUpdate);
    super.dispose();
  }

  // 刷新账户数据
  void _refreshAccountData() {
    if (!mounted) return;

    // 从插件中获取最新的账户数据
    final updatedAccount = widget.billPlugin.accounts.firstWhere(
      (account) => account.id == widget.account.id,
      orElse: () => widget.account,
    );

    setState(() {
      _currentAccount = updatedAccount;
    });
  }

  void _handlePluginUpdate() {
    if (mounted) {
      _refreshAccountData();
    }
  }

  Widget _buildBody() {
    final statistics = widget.billPlugin.controller.getStatistics(
      bills: _currentAccount.bills,
      range: _selectedRange,
      startDate: _customStartDate,
      endDate: _customEndDate,
    );

    return Column(
      children: [
        BillStatisticsCard(
          totalIncome: statistics.totalIncome,
          totalExpense: statistics.totalExpense,
          balance: statistics.balance,
        ),
        Expanded(child: _buildBillsList(_currentAccount.bills)),
      ],
    );
  }

  Widget _buildBillsList(List<Bill> bills) {
    if (bills.isEmpty) {
      return Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Center(
            child: Text(
              'bill_noBillsYet'.tr,
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          );
        },
      );
    }

    // 对账单按日期排序
    final sortedBills = List<Bill>.from(bills)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return HandDrawnListView(
      itemCount: sortedBills.length,
      tiltKeyOf: (index) => sortedBills[index].id,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final bill = sortedBills[index];
        return _buildBillItem(bill);
      },
    );
  }

  Widget _buildBillItem(Bill bill) {
    final theme = DSThemeBridge.resolve(context);
    final isExpense = bill.amount < 0;
    final amountColor = isExpense ? theme.danger : theme.success;

    return Dismissible(
      key: Key(bill.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: DsIcon(DsIconKind.trash, color: Colors.white),
      ),
      onDismissed: (direction) {
        widget.billPlugin.controller.deleteBill(
          widget.account.id,
          bill.id,
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.account.backgroundColor.withAlpha(
            51,
          ), // 0.2 * 255 ≈ 51
          child: Icon(bill.icon, color: widget.account.backgroundColor),
        ),
        title: Text(
          bill.title,
          style: DsTypography.body.copyWith(color: theme.text),
        ),
        subtitle: bill.tag != null
            ? Text(
                bill.tag!,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              )
            : null,
        trailing: Text(
          '${isExpense ? '-' : '+'}¥${bill.absoluteAmount.toStringAsFixed(2)}',
          style: DsTypography.body.copyWith(
            color: amountColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => _editBill(context, bill),
      ),
    );
  }

  void _createBill(BuildContext context) {
    _showBillEditor(context);
  }

  void _editBill(BuildContext context, Bill bill) {
    _showBillEditor(context, bill: bill);
  }

  /// 账单新建/编辑：smooth_sheets 底部弹层（与主界面 FAB 同款）
  void _showBillEditor(BuildContext context, {Bill? bill}) {
    final theme = DSThemeBridge.resolve(context);
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: theme.surface,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              bill == null ? 'bill_addBill'.tr : 'bill_editBill'.tr,
              style: DsTypography.title.copyWith(
                color: theme.text,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
          // 固定高度：BillEditScreen 内部 Expanded 布局需要
          // 有界高度约束
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: bill_edit.BillEditScreen(
              billPlugin: widget.billPlugin,
              accountId: _currentAccount.id,
              bill: bill,
              embeddedInSheet: true,
              onSaved: () {
                // 强制更新列表
                _refreshAccountData();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null && mounted) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    }
  }
}
