import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';
import 'package:aboutme/screens/home_screen/widgets/day_card_header.dart';
import 'package:aboutme/plugins/bill/models/bill.dart';

/// 账单单日卡片 - 展示某一天的账单列表
///
/// 供主页账单日卡使用：金额/分类/收支，
/// 点击账单打开编辑页（与插件页一致）。
class BillDayCard extends StatelessWidget {
  /// 卡片对应的日期
  final DateTime date;

  /// 该日的账单列表（由调用方按 bill.date 过滤并排序）
  final List<Bill> bills;

  /// 点击账单回调（打开编辑页）
  final Function(Bill) onBillTap;

  /// 新建账单回调（预填该日日期），为 null 时不显示 ＋ 按钮
  final Function(DateTime)? onAddBill;

  /// 头部主题色
  final Color color;

  const BillDayCard({
    super.key,
    required this.date,
    required this.bills,
    required this.onBillTap,
    this.onAddBill,
    this.color = const Color.fromARGB(255, 76, 175, 80),
  });

  // 与账单列表页一致的红绿配色
  static const Color _expenseColor = Color(0xFFE74C3C);
  static const Color _incomeColor = Color(0xFF2ECC71);

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DayCardHeader(
            color: color,
            date: date,
            count: bills.length,
            summary: _summaryText(),
            onAdd: onAddBill == null ? null : () => onAddBill!(date),
          ),
          Expanded(
            child:
                bills.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DsIcon(
                            DsIconKind.piggy,
                            size: 32,
                            color: theme.disabled.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'bill_dayCardEmpty'.tr,
                            style: TextStyle(
                              color: theme.disabled.withValues(alpha: 0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: bills.length,
                      itemBuilder: (context, index) {
                        return _buildBillItem(context, bills[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// 头部摘要：当日收支合计（无账单时不显示）
  String? _summaryText() {
    if (bills.isEmpty) return null;
    var income = 0.0;
    var expense = 0.0;
    for (final bill in bills) {
      if (bill.isExpense) {
        expense += bill.absoluteAmount;
      } else {
        income += bill.absoluteAmount;
      }
    }
    return '+${_formatAmount(income)} -${_formatAmount(expense)}';
  }

  /// 单条账单行：分类图标 + 标题/分类 + 时间 + 金额
  Widget _buildBillItem(BuildContext context, Bill bill) {
    final theme = DSThemeBridge.resolve(context);

    return InkWell(
      onTap: () => onBillTap(bill),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: bill.iconColor.withValues(alpha: 0.2),
              child: Icon(bill.icon, size: 16, color: bill.iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title.isNotEmpty ? bill.title : bill.category,
                    style: DsTypography.caption.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bill.category} ${_formatTime(bill.date)}',
                    style: DsTypography.caption.copyWith(
                      fontSize: 11,
                      color: theme.disabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${bill.isExpense ? '-' : '+'}¥${bill.absoluteAmount.toStringAsFixed(2)}',
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: bill.isExpense ? _expenseColor : _incomeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
