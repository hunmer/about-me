import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 提醒时间管理组件（手绘纸墨风）
///
/// 功能特性：
/// - 显示提醒时间列表
/// - 添加新提醒（日期+时间选择器）
/// - 删除提醒
///
/// 字段行走 [JellyBox]（实底 + 墨线描边），管理面板走 [showDSBottomSheet]
/// （纸底 + 淡排线 + 墨线框 + 描画入场）。
class RemindersField extends StatefulWidget {
  /// 提醒时间列表
  final List<DateTime> reminders;

  /// 删除提醒的回调
  final Function(int index) onRemoveReminder;

  /// 添加提醒后的回调（返回新的提醒列表）
  final Function(List<DateTime> newReminders)? onReminderAdded;

  /// 字段标签
  final String? labelText;

  /// 占位提示文本（无提醒时显示）
  final String? hintText;

  /// 主题色（未传时取 design_system 主题主色）
  final Color? primaryColor;

  const RemindersField({
    super.key,
    required this.reminders,
    required this.onRemoveReminder,
    this.onReminderAdded,
    this.labelText,
    this.hintText,
    this.primaryColor,
  });

  @override
  State<RemindersField> createState() => _RemindersFieldState();
}

class _RemindersFieldState extends State<RemindersField> {
  late List<DateTime> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = List.from(widget.reminders);
  }

  @override
  void didUpdateWidget(RemindersField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reminders != oldWidget.reminders) {
      _reminders = List.from(widget.reminders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Pressable(
            onPressed: () => _showRemindersSheet(context, locale, theme),
            child: JellyBox(
              height: 50,
              radius: theme.radii.lg,
              padding: EdgeInsets.only(
                left: theme.spacing.md,
                right: theme.spacing.lg,
              ),
              child: Row(
                children: [
                  if (widget.labelText != null)
                    Text(
                      widget.labelText!,
                      style: DsTypography.body.copyWith(color: theme.text),
                    )
                  else
                    DsIcon(
                      DsIconKind.bell,
                      size: 20,
                      color: widget.primaryColor ?? theme.primary,
                    ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      _getDisplayText(locale),
                      style: DsTypography.body.copyWith(
                        color:
                            _reminders.isNotEmpty ? theme.text : theme.textSub,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  /// 获取显示文本
  String _getDisplayText(String locale) {
    if (_reminders.isEmpty) {
      return widget.hintText ?? 'app_none'.tr;
    }
    final first = _reminders.first;
    final formatted = DateFormat.yMMMEd(locale).add_jm().format(first);
    if (_reminders.length > 1) {
      return '$formatted (+${_reminders.length - 1})';
    }
    return formatted;
  }

  /// 显示提醒管理底部面板（纸底 + 淡排线 + 墨线框 + 描画入场）
  Future<void> _showRemindersSheet(
    BuildContext context,
    String locale,
    AppThemeData theme,
  ) async {
    await showDSBottomSheet(
      context: context,
      title: widget.labelText ?? 'app_reminders'.tr,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 添加入口
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        DSIconButton(
                          icon: DsIconKind.plus,
                          size: 32,
                          onPressed: () => _addReminder(setModalState, theme),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  Flexible(
                    child:
                        _reminders.isEmpty
                            ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  widget.hintText ?? 'app_noReminders'.tr,
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.fromLTRB(
                                theme.spacing.lg,
                                0,
                                theme.spacing.lg,
                                theme.spacing.sm,
                              ),
                              itemCount: _reminders.length,
                              itemBuilder: (context, index) {
                                final r = _reminders[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      DsIcon(
                                        DsIconKind.bell,
                                        size: 18,
                                        color: theme.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          DateFormat.yMMMEd(
                                            locale,
                                          ).add_jm().format(r),
                                          style: DsTypography.body.copyWith(
                                            color: theme.text,
                                          ),
                                        ),
                                      ),
                                      DSIconButton(
                                        icon: DsIconKind.trash,
                                        size: 32,
                                        color: theme.surfaceAlt,
                                        iconColor: theme.danger,
                                        onPressed: () {
                                          setState(
                                            () => _reminders.removeAt(index),
                                          );
                                          widget.onRemoveReminder(index);
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }

  /// 添加提醒
  Future<void> _addReminder(
    StateSetter setModalState,
    AppThemeData theme,
  ) async {
    final baseDate = _reminders.isNotEmpty ? _reminders.last : DateTime.now();

    // 选择日期（DS 手绘日历；无范围约束参数，与表单日期字段行为一致）
    final pickedDate = await showDSDatePickerDialog(
      context: context,
      initial: baseDate,
      cancelText: 'app_cancel'.tr,
      confirmText: 'app_ok'.tr,
      theme: theme,
    );

    if (pickedDate == null) return;

    // 选择时间（DS 手绘双滚轮）
    final pickedTime = await showDSTimePickerDialog(
      context: context,
      initial: TimeOfDay.now(),
      cancelText: 'app_cancel'.tr,
      confirmText: 'app_ok'.tr,
      theme: theme,
    );

    if (pickedTime == null) return;

    // 组合日期和时间
    final reminderDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() => _reminders.add(reminderDateTime));
    widget.onReminderAdded?.call(_reminders);
    setModalState(() {});
  }
}
