import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// 仓库操作抽屉
///
/// 显示仓库的操作选项：编辑、删除
class WarehouseActionSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const WarehouseActionSheet({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  /// 显示仓库操作抽屉
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) async {
    await Navigator.of(context).push(
      ModalSheetRoute(
        swipeDismissible: true,
        builder:
            (context) => Sheet(
              child: WarehouseActionSheet(onEdit: onEdit, onDelete: onDelete),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isDark = theme.isDark;

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 操作选项
          _buildActionItem(
            context,
            icon: DsIconKind.edit,
            label: 'goods_editWarehouse'.tr,
            color: theme.primary,
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          _buildActionItem(
            context,
            icon: DsIconKind.trash,
            label: 'goods_deleteWarehouse'.tr,
            color: theme.danger,
            isDark: isDark,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }

  /// 构建操作项
  Widget _buildActionItem(
    BuildContext context, {
    required DsIconKind icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DsIcon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),

              // 标签
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.text,
                  ),
                ),
              ),

              // 箭头
              DsIcon(DsIconKind.chevronRight, color: theme.textSub, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
