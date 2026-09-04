import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/checkin/controllers/checkin_list_controller.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';

class CheckinRecordDialog extends StatefulWidget {
  final CheckinItem item;
  final CheckinListController controller;
  final VoidCallback onCheckinCompleted;
  final DateTime? selectedDate;

  const CheckinRecordDialog({
    super.key,
    required this.item,
    required this.controller,
    required this.onCheckinCompleted,
    this.selectedDate,
  });

  @override
  State<CheckinRecordDialog> createState() => _CheckinRecordDialogState();
}

class _CheckinRecordDialogState extends State<CheckinRecordDialog> {
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
    // 无论是否提供selectedDate，都使用当前时间作为默认时间
    _startTime = now;
    _endTime = now;
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

          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.xl),
            constraints: const BoxConstraints(maxWidth: 360),
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
                  _buildPickerRow(
                    context,
                    label: 'app_save'.tr,
                    value:
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                    onTap: () => _selectDate(context),
                  ),
                  // 起始时间选择
                  _buildPickerRow(
                    context,
                    label: 'app_startTime'.tr,
                    value:
                        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                    onTap: () => _selectTime(context, true),
                  ),
                  // 终止时间选择
                  _buildPickerRow(
                    context,
                    label: 'app_endTime'.tr,
                    value:
                        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                    onTap: () => _selectTime(context, false),
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
                        : '${'checkin_checkinTimeLabel'.tr}: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  SizedBox(height: theme.spacing.lg),
                  // 操作按钮
                  Row(
                    children: [
                      Expanded(
                        child: DSButton(
                          label: 'app_cancel'.tr,
                          variant: DSButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DSButton(
                          label: 'checkin_checkinButton'.tr,
                          onPressed: () => _submit(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 日期/时间选择行：标签 + 可点击值
  Widget _buildPickerRow(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DsTypography.body.copyWith(color: theme.text),
            ),
          ),
          DSButton(
            label: value,
            variant: DSButtonVariant.ghost,
            size: DSButtonSize.sm,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final now = DateTime.now();
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
    final normalizedCheckinTime = DateTime(
      (widget.selectedDate ?? now).year,
      (widget.selectedDate ?? now).month,
      (widget.selectedDate ?? now).day,
      (widget.selectedDate ?? now).hour,
      (widget.selectedDate ?? now).minute,
      (widget.selectedDate ?? now).second,
    );

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
