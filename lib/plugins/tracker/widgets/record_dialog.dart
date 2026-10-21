import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/widgets/siri_voice_assistant_orb_demo.dart';
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
  final _valueFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _orbController = SiriOrbCardController();

  /// 抽屉当前编辑目标：false=增加值，true=备注
  bool _noteMode = false;
  String? _valueError;

  @override
  void initState() {
    super.initState();
    _recordedAt = widget.initialRecordedAt ?? DateTime.now();
    _valueController.text = '1';
    // 提示区实时显示"当前值 → 预计值"，输入变化即刷新
    _valueController.addListener(_onValueChanged);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    _valueFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _onValueChanged() {
    setState(() => _valueError = null);
  }

  SiriOrbInput get _input => _noteMode
      ? SiriOrbInput(
          controller: _noteController,
          focusNode: _noteFocus,
          hint: '${'tracker_note'.tr} (${'tracker_noteHint'.tr})',
          onSubmitted: (_) {
            // 备注填写完自动切回增加值输入
            setState(() => _noteMode = false);
            _orbController.openInput();
          },
        )
      : SiriOrbInput(
          controller: _valueController,
          focusNode: _valueFocus,
          hint: 'tracker_incrementValueWithUnit'.tr.replaceFirst(
                '\${unit}',
                widget.goal.unitType,
              ),
          keyboard: TextInputType.number,
          onSubmitted: (_) => _submit(),
        );

  String get _prompt {
    if (_valueError != null) return _valueError!;
    final goal = widget.goal;
    final delta = double.tryParse(_valueController.text) ?? 0;
    return '${'tracker_recordTitle'.tr.replaceAll('@goalName', goal.name)}\n'
        '${goal.currentValue} → ${goal.currentValue + delta} · '
        '${_formatDateTime(_recordedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 对话框路由在主题树之外，日期/差值选择器先过桥再取令牌
      child: Builder(
        builder: (context) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SiriOrbCard(
                controller: _orbController,
                prompt: _prompt,
                height: 430,
                input: _input,
                topLeft: SiriOrbCorner(
                  tooltip: 'tracker_cancel'.tr,
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
                actions: [
                  SiriOrbAction(
                    icon: Icons.event,
                    label: 'tracker_time'.tr,
                    onTap: _pickDateTime,
                  ),
                  SiriOrbAction(
                    icon: Icons.calculate_outlined,
                    label: 'tracker_calculateDifference'.tr,
                    onTap: _calculateDifference,
                  ),
                  SiriOrbAction(
                    icon: Icons.edit_note,
                    label: 'tracker_note'.tr,
                    onTap: () {
                      setState(() => _noteMode = true);
                      _orbController.openInput();
                    },
                  ),
                  SiriOrbAction(
                    icon: Icons.check_rounded,
                    label: 'tracker_confirm'.tr,
                    highlighted: true,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
        _valueError = null;
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
      _orbController.pulse();
      return;
    }
    final numValue = double.tryParse(text);
    if (numValue == null || numValue <= 0) {
      setState(() => _valueError = '请输入有效的正数');
      _orbController.pulse();
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
