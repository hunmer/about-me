import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 习惯操作抽屉
///
/// 显示习惯的操作选项：编辑、删除
class HabitActionSheet extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitActionSheet({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  /// 显示习惯操作抽屉
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
              child: HabitActionSheet(onEdit: onEdit, onDelete: onDelete),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Sheet 路由在主题树之外，先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Container(
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽指示器
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.textSub.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      'habits_habitActions'.tr,
                      style: DsTypography.title.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 编辑选项
                  SmoothSheetAction(
                    icon: DsIconKind.edit,
                    label: 'habits_editHabit'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),

                  // 删除选项
                  SmoothSheetAction(
                    icon: DsIconKind.trash,
                    label: 'habits_delete'.tr,
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                  ),

                  // 取消按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DSButton(
                      label: 'habits_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      expand: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
