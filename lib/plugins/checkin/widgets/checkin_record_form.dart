import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/widgets/form_fields/date_picker_field.dart';

class CheckinRecordForm extends StatefulWidget {
  final CheckinItem item;
  final CheckinListController controller;
  final VoidCallback onCheckinCompleted;
  final DateTime? selectedDate;

  const CheckinRecordForm({
    super.key,
    required this.item,
    required this.controller,
    required this.onCheckinCompleted,
    this.selectedDate,
  });

  @override
  State<CheckinRecordForm> createState() => _CheckinRecordFormState();
}

class _CheckinRecordFormState extends State<CheckinRecordForm> {
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late DateTime _startTime;
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    final now = DateTime.now();
    _selectedDate = widget.selectedDate ?? now;
    // 无论是否提供selectedDate，都使用当前时分作为默认时间，
    // 且起止时间必须锚定在所选日期上，避免跨天导致校验失败
    _startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
    );
    _endTime = _startTime;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDSDatePickerDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      initial: _selectedDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // 保持时分不变，只改变年月日
        _startTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _startTime.hour,
          _startTime.minute,
        );
        _endTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _endTime.hour,
          _endTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    // DS 无时间选择器，保留 Material showTimePicker（DS API 缺口）
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
    );

    if (picked != null) {
      setState(() {
        final selectedDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
        if (isStartTime) {
          _startTime = selectedDateTime;
          // 如果开始时间晚于结束时间，更新结束时间
          if (_startTime.isAfter(_endTime)) {
            _endTime = _startTime;
          }
        } else {
          _endTime = selectedDateTime;
          // 如果结束时间早于开始时间，更新开始时间
          if (_endTime.isBefore(_startTime)) {
            _startTime = _endTime;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // 对话框路由在主题树之外，先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          // 底部抽屉样式：由 SmoothBottomSheet 提供背景与拖拽指示器
          return Padding(
            padding: EdgeInsets.fromLTRB(
              theme.spacing.xl,
              theme.spacing.sm,
              theme.spacing.xl,
              theme.spacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    widget.selectedDate != null
                        ? 'checkin_addSpecificDateCheckin'.tr
                        : 'checkin_addCheckinRecord'.tr,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  // 日期选择
                  DatePickerField(
                    date: _selectedDate,
                    onTap: () => _selectDate(context),
                    formattedDate: _formatDate(_selectedDate),
                    placeholder: '',
                    labelText: 'app_date'.tr,
                    inline: true,
                  ),
                  SizedBox(height: theme.spacing.md),
                  // 起始时间选择
                  DatePickerField(
                    date: _startTime,
                    onTap: () => _selectTime(context, true),
                    formattedDate: _formatTime(_startTime),
                    placeholder: '',
                    labelText: 'app_startTime'.tr,
                    inline: true,
                  ),
                  SizedBox(height: theme.spacing.md),
                  // 终止时间选择：右侧按钮一键应用当前时分，
                  // 早于开始时间时沿用回推规则同步开始时间
                  DatePickerField(
                    date: _endTime,
                    onTap: () => _selectTime(context, false),
                    formattedDate: _formatTime(_endTime),
                    placeholder: '',
                    labelText: 'app_endTime'.tr,
                    inline: true,
                    onSync: _applyCurrentTimeToEndTime,
                    syncLabel: 'checkin_useCurrentTime'.tr,
                    syncIcon: DsIconKind.clock,
                  ),
                  SizedBox(height: theme.spacing.md),
                  // 备注输入框
                  DSInput(
                    controller: _noteController,
                    label: 'checkin_noteLabel'.tr,
                    hint: 'checkin_noteHint'.tr,
                    maxLines: 3,
                  ),
                  SizedBox(height: theme.spacing.md),
                      // 打卡时间显示
                      Text(
                        widget.selectedDate != null
                            ? '${'checkin_checkinDateLabel'.tr}: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}'
                            : '${'checkin_checkinTimeLabel'.tr}: ${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  // 操作按钮
                  DSButton(
                    label: 'checkin_checkinButton'.tr,
                    onPressed: () => _submit(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// 将当前时分应用到结束时间（仍锚定所选日期），
  /// 早于开始时间时与手动改时间一致，回推开始时间
  void _applyCurrentTimeToEndTime() {
    final now = DateTime.now();
    setState(() {
      _endTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
      );
      if (_endTime.isBefore(_startTime)) {
        _startTime = _endTime;
      }
    });
  }

  Future<void> _submit(BuildContext context) async {
    // 标准化时间，保留到秒级别（忽略毫秒）
    final normalizedStartTime = DateTime(
      _startTime.year,
      _startTime.month,
      _startTime.day,
      _startTime.hour,
      _startTime.minute,
      _startTime.second,
    );
    final normalizedEndTime = DateTime(
      _endTime.year,
      _endTime.month,
      _endTime.day,
      _endTime.hour,
      _endTime.minute,
      _endTime.second,
    );
    // 打卡时间跟随所选开始时间，保证落在 [startTime, endTime] 范围内，
    // 且记录日期与所选日期一致
    final normalizedCheckinTime = normalizedStartTime;

    final record = CheckinRecord(
      startTime: normalizedStartTime,
      endTime: normalizedEndTime,
      checkinTime: normalizedCheckinTime,
      note:
          _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
    );

    try {
      // 等待打卡记录保存完成
      await widget.item.addCheckinRecord(record);

      // 保存成功后才触发回调和关闭对话框
      if (mounted) {
        widget.onCheckinCompleted();
        widget.controller.notifyEvent('completed', widget.item);
        Navigator.of(context).pop();
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        Toast.error('打卡失败: $e');
      }
    }
  }
}
