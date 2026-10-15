import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/widgets/habit_form.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';

/// 习惯表单底部弹层（smooth_sheets ModalSheet，支持新建和编辑）
class HabitFormSheet extends StatefulWidget {
  /// 要编辑的习惯（null 表示新建）
  final Habit? habit;

  /// 保存回调（保存成功后弹层自动关闭）
  final Future<void> Function(Habit habit) onSave;

  /// 删除回调（仅编辑时有意义）
  final Future<void> Function(Habit habit)? onDelete;

  const HabitFormSheet({
    super.key,
    this.habit,
    required this.onSave,
    this.onDelete,
  });

  /// 以 smooth_sheets 模态底部弹层打开
  static Future<void> show(
    BuildContext context, {
    Habit? habit,
    required Future<void> Function(Habit habit) onSave,
    Future<void> Function(Habit habit)? onDelete,
  }) {
    return Navigator.of(context).push(
      ModalSheetRoute(
        swipeDismissible: true,
        builder: (context) =>
            HabitFormSheet(habit: habit, onSave: onSave, onDelete: onDelete),
      ),
    );
  }

  @override
  State<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<HabitFormSheet> {
  FormBuilderWrapperState? _wrapperState;

  Future<void> _delete() async {
    final habit = widget.habit;
    if (habit == null) return;

    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'habits_confirmDelete'.tr,
        message: 'habits_confirmDeleteHabit'.tr,
        cancelText: 'habits_cancel'.tr,
        confirmText: 'habits_delete'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (confirmed == true) {
      await widget.onDelete?.call(habit);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final isEditing = widget.habit != null;

          // 双档吸附：半屏档（视口65%）+ 满屏档
          return Sheet(
            initialOffset: const SheetOffset.proportionalToViewport(0.65),
            snapGrid: const SheetSnapGrid(
              snaps: [
                SheetOffset.proportionalToViewport(0.65),
                SheetOffset(1),
              ],
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
                  _buildTitleBar(theme, isEditing),
                  Flexible(
                    child: HabitForm(
                      initialHabit: widget.habit,
                      showSubmitButton: false,
                      onSave: (habit) async {
                        await widget.onSave(habit);
                        if (mounted) Navigator.of(context).pop();
                      },
                      onStateReady: (state) => _wrapperState = state,
                    ),
                  ),
                  _buildBottomBar(theme),
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

  Widget _buildTitleBar(AppThemeData theme, bool isEditing) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.sm,
        theme.spacing.md,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          if (isEditing)
            DSIconButton(
              icon: DsIconKind.trash,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: _delete,
            )
          else
            const SizedBox(width: 36),
          Expanded(
            child: Text(
              isEditing ? 'habits_editHabit'.tr : 'habits_createHabit'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
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

  Widget _buildBottomBar(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.xl,
        theme.spacing.sm,
        theme.spacing.xl,
        theme.spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: DSButton(
              label: 'habits_cancel'.tr,
              variant: DSButtonVariant.outline,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: DSButton(
              label: 'habits_save'.tr,
              icon: DsIconKind.check,
              onPressed: () => _wrapperState?.submitForm(),
            ),
          ),
        ],
      ),
    );
  }
}
