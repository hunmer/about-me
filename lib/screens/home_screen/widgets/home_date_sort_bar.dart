import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';

/// 日期视图排序选项条
///
/// 显示在日期横条下方，切换日期视图中数据的排序方式。
/// 排序状态保存在 [HomeDateController]，由各日期卡片自行应用。
class HomeDateSortBar extends StatelessWidget {
  const HomeDateSortBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateController = HomeDateController();

    return AnimatedBuilder(
      animation: dateController,
      builder: (context, _) {
        final current = dateController.sortOption;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Icon(
                Icons.sort,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final option in DateViewSortOption.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildChip(
                            theme,
                            label: _optionLabel(option),
                            isSelected: current == option,
                            onTap: () => dateController.setSortOption(option),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _optionLabel(DateViewSortOption option) {
    switch (option) {
      case DateViewSortOption.def:
        return 'home_sortDefault'.tr;
      case DateViewSortOption.priority:
        return 'home_sortPriority'.tr;
      case DateViewSortOption.time:
        return 'home_sortTime'.tr;
    }
  }

  Widget _buildChip(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
