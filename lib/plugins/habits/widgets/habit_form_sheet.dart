import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/widgets/habit_form.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 习惯表单底部弹层（基于通用 [SmoothBottomSheet.showForm]，支持新建和编辑）
class HabitFormSheet {
  /// 以 smooth_sheets 模态底部弹层打开
  ///
  /// 保存成功后弹层自动关闭；编辑时标题栏提供删除（带确认弹窗）。
  static Future<void> show(
    BuildContext context, {
    Habit? habit,
    required Future<void> Function(Habit habit) onSave,
    Future<void> Function(Habit habit)? onDelete,
  }) {
    FormBuilderWrapperState? wrapperState;

    return SmoothBottomSheet.showForm(
      context: context,
      title: habit == null ? 'habits_createHabit'.tr : 'habits_editHabit'.tr,
      child: HabitForm(
        initialHabit: habit,
        showSubmitButton: false,
        onStateReady: (state) => wrapperState = state,
        onSave: (updated) async {
          await onSave(updated);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
      onSave: () => wrapperState?.submitForm(),
      onDelete:
          habit == null
              ? null
              : () => _confirmDelete(context, habit, onDelete),
    );
  }

  /// 删除确认（与长按删除一致的双步确认）
  static Future<void> _confirmDelete(
    BuildContext context,
    Habit habit,
    Future<void> Function(Habit habit)? onDelete,
  ) async {
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
      await onDelete?.call(habit);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
