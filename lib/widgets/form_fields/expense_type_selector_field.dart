import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 收支类型选择器组件
///
/// 用于账单编辑界面选择收入/支出类型
class ExpenseTypeSelectorField extends StatelessWidget {
  /// 是否为支出（true=支出，false=收入）
  final bool isExpense;

  /// 类型变化回调
  final ValueChanged<bool> onTypeChanged;

  /// 支出颜色（未传时取主题 danger）
  final Color? expenseColor;

  /// 收入颜色（未传时取主题 success）
  final Color? incomeColor;

  const ExpenseTypeSelectorField({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
    this.expenseColor,
    this.incomeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dsTheme = DSThemeBridge.resolve(context);
    final unselectedColor = theme.colorScheme.surfaceContainerLow;
    final selectedBgColor = theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: unselectedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              context: context,
              label: 'app_expense'.tr,
              isSelected: isExpense,
              activeColor: expenseColor ?? dsTheme.danger,
              bgOnSelected: selectedBgColor,
              onTap: () => onTypeChanged(true),
            ),
          ),
          Expanded(
            child: _buildTypeButton(
              context: context,
              label: 'app_income'.tr,
              isSelected: !isExpense,
              activeColor: incomeColor ?? dsTheme.success,
              bgOnSelected: selectedBgColor,
              onTap: () => onTypeChanged(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required Color bgOnSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgOnSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
