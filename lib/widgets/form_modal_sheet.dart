import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 通用表单底部弹层外壳（smooth_sheets ModalSheet）
///
/// 统一提供拖拽把手、标题栏（可选删除按钮）、内容区与底栏（取消/保存）。
/// [onSave] 为 null 时表示表单自动保存，底栏显示"完成"按钮。
/// 表单自带标题头时可通过 [showTitleBar] 关闭外壳标题栏避免重复。
class FormModalSheet extends StatelessWidget {
  final String title;
  final Widget child;

  /// 底栏保存按钮回调（触发表单提交）
  final VoidCallback? onSave;

  /// 标题栏左侧删除按钮回调
  final VoidCallback? onDelete;

  /// 是否显示外壳标题栏
  final bool showTitleBar;

  /// 提交按钮放标题栏右侧（替代关闭按钮），隐藏底栏按钮
  final bool submitInTitleBar;

  const FormModalSheet({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.onDelete,
    this.showTitleBar = true,
    this.submitInTitleBar = false,
  });

  /// 以 smooth_sheets 模态底部弹层打开
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    VoidCallback? onSave,
    VoidCallback? onDelete,
    bool showTitleBar = true,
    bool submitInTitleBar = false,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute(
        swipeDismissible: true,
        builder: (context) => FormModalSheet(
          title: title,
          onSave: onSave,
          onDelete: onDelete,
          showTitleBar: showTitleBar,
          submitInTitleBar: submitInTitleBar,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // 双档吸附：半屏档（视口65%）+ 满屏档
          return Sheet(
            initialOffset: const SheetOffset.proportionalToViewport(0.65),
            snapGrid: const SheetSnapGrid(
              snaps: [SheetOffset.proportionalToViewport(0.65), SheetOffset(1)],
            ),
            child: DsSketchPanel(
              theme: theme,
              width: double.infinity,
              radius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDragHandle(theme),
                  if (showTitleBar) _buildTitleBar(context, theme),
                  Flexible(child: child),
                  if (!submitInTitleBar) _buildBottomBar(context, theme),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(AppThemeData theme) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: theme.radii.pill,
          border: Border.all(
            color: theme.ink.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.sm,
        theme.spacing.md,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          if (onDelete != null)
            DSIconButton(
              icon: DsIconKind.trash,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: onDelete,
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          if (submitInTitleBar && onSave != null)
            DSButton(
              label: 'app_save'.tr,
              size: DSButtonSize.sm,
              icon: DsIconKind.check,
              onPressed: onSave,
            )
          else
            DSIconButton(
              icon: DsIconKind.close,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.xl,
        theme.spacing.sm,
        theme.spacing.xl,
        theme.spacing.md,
      ),
      child: Row(
        children: [
          if (onSave != null) ...[
            Expanded(
              child: DSButton(
                label: 'app_cancel'.tr,
                variant: DSButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: DSButton(
                label: 'app_save'.tr,
                icon: DsIconKind.check,
                onPressed: onSave,
              ),
            ),
          ] else
            // 自动保存表单：仅提供"完成"关闭入口
            Expanded(
              child: DSButton(
                label: 'app_done'.tr,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}
