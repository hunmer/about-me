import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/managers/home_date_controller.dart';

/// 日期视图排序选项条
///
/// 显示在日期横条下方，切换日期视图中数据的排序方式。
/// 排序状态保存在 [HomeDateController]，由各日期卡片自行应用。
class HomeDateSortBar extends StatelessWidget {
  const HomeDateSortBar({super.key});

  @override
  Widget build(BuildContext context) {
    final dateController = HomeDateController();

    return DSThemeBridge(
      child: AnimatedBuilder(
        animation: dateController,
        builder: (context, _) {
          final theme = DSThemeBridge.resolve(context);
          final current = dateController.sortOption;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                DsIcon(DsIconKind.sort, size: 14, color: theme.textSub),
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
      ),
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
    AppThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? theme.primary.mixWhite(0.88)
                    : (pressed ? theme.surfaceAlt : const Color(0x00000000)),
            borderRadius: theme.radii.sm,
            border: Border.all(
              color: isSelected ? theme.primary : theme.stroke,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: DsTypography.label.copyWith(
              color: isSelected ? theme.primary : theme.textSub,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      },
    );
  }
}
