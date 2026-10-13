import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/group_selector_dialog.dart';

/// 分组选择器字段组件
///
/// 集成 GroupSelectorDialog，提供分组选择、新建、重命名、删除功能
class GroupSelectorField extends StatelessWidget {
  /// 可选分组列表
  final List<String> groups;

  /// 当前选中的分组
  final String? selectedGroup;

  /// 分组变更回调
  final ValueChanged<String?>? onGroupChanged;

  /// 分组重命名回调
  final OnGroupRenamed? onGroupRenamed;

  /// 分组删除回调
  final OnGroupDeleted? onGroupDeleted;

  /// 是否启用
  final bool enabled;

  /// 字段标签
  final String? labelText;

  /// 占位提示
  final String? hintText;

  const GroupSelectorField({
    super.key,
    required this.groups,
    this.selectedGroup,
    this.onGroupChanged,
    this.onGroupRenamed,
    this.onGroupDeleted,
    this.enabled = true,
    this.labelText,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              labelText!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        InkWell(
          onTap: enabled ? () => _showGroupSelector(context) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedGroup ?? (hintText ?? 'app_selectGroup'.tr),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showGroupSelector(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupSelectorDialog(
              groups: groups,
              initialSelectedGroup: selectedGroup,
              onGroupRenamed: onGroupRenamed ?? (_, __) {},
              onGroupDeleted: onGroupDeleted ?? (_) {},
            ),
      ),
    );

    if (result != null) {
      onGroupChanged?.call(result);
    }
  }
}
