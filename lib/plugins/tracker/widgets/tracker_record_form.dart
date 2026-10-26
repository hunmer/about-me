import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/plugins/tracker/models/goal.dart';
import 'package:aboutme/plugins/tracker/models/record.dart';
import 'package:aboutme/plugins/tracker/controllers/tracker_controller.dart';

class RecordDialog extends StatefulWidget {
  final Goal goal;
  final TrackerController controller;

  /// 初始记录时间（缺省为当前时刻），供快速新建预填日期
  final DateTime? initialRecordedAt;

  const RecordDialog({
    super.key,
    required this.goal,
    required this.controller,
    this.initialRecordedAt,
  });

  @override
  State<RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<RecordDialog> {
  late DateTime _recordedAt;
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  String? _valueError;

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.initialRecordedAt ?? DateTime.now();
    _valueController.text = '1';
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 对话框路由在主题树之外，内部组件先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'tracker_recordTitle'.tr.replaceFirst(
                    '{goalName}',
                    widget.goal.name,
                  ),
                  textAlign: TextAlign.center,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
                SizedBox(height: theme.spacing.lg),
                // 记录时间行：点击修改日期时间
                _buildTimeRow(context, theme),
                SizedBox(height: theme.spacing.lg),
                // 增加值 + 计算差值
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DSInput(
                        controller: _valueController,
                        errorText: _valueError,
                        hint: 'tracker_incrementValueWithUnit'.tr.replaceFirst(
                          '\${unit}',
                          widget.goal.unitType,
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    DSButton(
                      label: 'tracker_calculateDifference'.tr,
                      variant: DSButtonVariant.secondary,
                      size: DSButtonSize.sm,
                      onPressed: _calculateDifference,
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.md),
                DSInput(
                  controller: _noteController,
                  hint: '${'tracker_note'.tr} (${'tracker_noteHint'.tr})',
                  maxLines: 2,
                ),
                SizedBox(height: theme.spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: DSButton(
                        label: 'tracker_cancel'.tr,
                        variant: DSButtonVariant.outline,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: DSButton(
                        label: 'tracker_confirm'.tr,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 记录时间行：时钟图标 + 时间文本 + 编辑图标
  Widget _buildTimeRow(BuildContext context, AppThemeData theme) {
    return Pressable(
      onPressed: _pickDateTime,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color:
                pressed
                    ? theme.surfaceAlt.withValues(alpha: 0.6)
                    : theme.surfaceAlt.withValues(alpha: 0.35),
            borderRadius: theme.radii.lg,
          ),
          child: Row(
            children: [
              DsIcon(DsIconKind.clock, size: 20, color: theme.primary),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'tracker_recordTitle'.tr,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    Text(
                      _formatDateTime(_recordedAt),
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                  ],
                ),
              ),
              DsIcon(DsIconKind.edit, size: 18, color: theme.textSub),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    // DS 日期选择器
    final date = await showDSDatePickerDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      initial: _recordedAt.isAfter(now) ? now : _recordedAt,
    );
    if (date == null) return;

    // DS 无时间选择器，保留 Material showTimePicker（DS API 缺口）
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null) return;

    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _calculateDifference() async {
    final textController = TextEditingController();
    final targetValue = await showDSDialog<double>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'tracker_calculateDifference'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      DSInput(
                        controller: textController,
                        hint: 'tracker_inputTargetValue'.tr,
                        keyboardType: TextInputType.number,
                        onSubmitted:
                            (_) => _popTargetValue(context, textController),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'tracker_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: 'tracker_confirm'.tr,
                              onPressed:
                                  () =>
                                      _popTargetValue(context, textController),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
    textController.dispose();

    if (targetValue != null) {
      final newValue = targetValue - widget.goal.currentValue;
      setState(() {
        _valueController.text = newValue.toString();
      });
    }
  }

  void _popTargetValue(BuildContext context, TextEditingController controller) {
    final value = double.tryParse(controller.text);
    if (value != null) {
      Navigator.pop(context, value);
    }
  }

  void _submit() {
    final text = _valueController.text;
    if (text.isEmpty) {
      setState(() => _valueError = '请输入增加值');
      return;
    }
    final numValue = double.tryParse(text);
    if (numValue == null || numValue <= 0) {
      setState(() => _valueError = '请输入有效的正数');
      return;
    }

    final record = Record(
      id: const Uuid().v4(),
      goalId: widget.goal.id,
      value: numValue,
      // 与原版一致：空备注保存空字符串
      note: _noteController.text,
      recordedAt: _recordedAt,
    );

    widget.controller.addRecord(record, widget.goal);
    Navigator.pop(context);
  }
}
