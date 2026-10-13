import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/picker/icon_picker_dialog.dart';

/// 计时器图标网格选择器字段组件
///
/// 显示预设图标网格 + 更多按钮打开完整图标选择器
class TimerIconGridField extends StatelessWidget {
  /// 当前选中的图标
  final IconData selectedIcon;

  /// 图标变化回调
  final ValueChanged<IconData>? onIconChanged;

  /// 预设图标列表
  final List<IconData> presetIcons;

  /// 是否启用
  final bool enabled;

  /// 主色调（未传时取 Material 主色）
  final Color? primaryColor;

  const TimerIconGridField({
    super.key,
    required this.selectedIcon,
    this.onIconChanged,
    this.presetIcons = const [
      Icons.psychology,
      Icons.auto_stories,
      Icons.code,
      Icons.fitness_center,
      Icons.edit,
      Icons.more_horiz,
    ],
    this.enabled = true,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themePrimaryColor = primaryColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签
        Text(
          'app_icon'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),

        // 图标网格
        _buildIconGrid(context, themePrimaryColor),
      ],
    );
  }

  Widget _buildIconGrid(BuildContext context, Color primaryColor) {
    final theme = Theme.of(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.0,
      children:
          presetIcons.map((icon) {
            final isSelected = selectedIcon == icon;
            return InkWell(
              onTap:
                  enabled
                      ? () {
                        if (icon == Icons.more_horiz) {
                          // 打开完整图标选择器
                          _openFullIconPicker(context);
                        } else {
                          onIconChanged?.call(icon);
                        }
                      }
                      : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? primaryColor
                          : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      isSelected ? Border.all(color: primaryColor, width: 2) : null,
                ),
                child: Icon(
                  icon,
                  color:
                      isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            );
          }).toList(),
    );
  }

  /// 打开完整图标选择器
  Future<void> _openFullIconPicker(BuildContext context) async {
    final result = await showIconPickerDialog(context, selectedIcon);
    if (result != null) {
      onIconChanged?.call(result);
    }
  }
}
