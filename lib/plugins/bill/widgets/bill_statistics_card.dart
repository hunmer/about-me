import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:intl/intl.dart';

class BillStatisticsCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const BillStatisticsCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSThemeBridge(
      child: DSCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '账单概览',
              style: DsTypography.title.copyWith(
                color: theme.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '收入',
                  totalIncome,
                  theme.success,
                  DsIconKind.chevronDown,
                ),
                _buildStatItem(
                  '支出',
                  totalExpense,
                  theme.danger,
                  DsIconKind.chevronUp,
                ),
                _buildStatItem(
                  '结余',
                  balance,
                  balance >= 0 ? theme.primary : theme.warning,
                  DsIconKind.piggy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    double amount,
    Color color,
    DsIconKind icon,
  ) {
    final formatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

    return Builder(
      builder: (context) {
        return Column(
          children: [
            DsIcon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              title,
              style: DsTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatter.format(amount),
              style: DsTypography.body.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
