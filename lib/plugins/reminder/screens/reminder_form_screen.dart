import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/reminder_date_selector_field.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import '../models/reminder.dart';
import '../services/reminder_service.dart';

/// 提醒表单界面
class ReminderFormScreen extends StatefulWidget {
  final Reminder? existingReminder;

  /// 以底部弹层形式嵌入（不渲染导航栏，由外壳提供标题与保存）
  final bool embedInSheet;

  /// 弹层模式下回传提交动作（外壳"保存"按钮触发）
  final void Function(VoidCallback submit)? onReady;

  const ReminderFormScreen({
    super.key,
    this.existingReminder,
    this.embedInSheet = false,
    this.onReady,
  });

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final ReminderService _service = ReminderService();
  bool _isSubmitting = false;
  FormBuilderWrapperState? _wrapperState;

  @override
  void initState() {
    super.initState();
    widget.onReady?.call(() => _wrapperState?.submitForm());
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReminder != null;

    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FormBuilderWrapper(
        onStateReady: (state) => _wrapperState = state,
        config: FormConfig(
            fields: [
              // 标题
              FormFieldConfig(
                name: 'title',
                type: FormFieldType.text,
                labelText: 'reminder_titleLabel'.tr,
                required: true,
                initialValue: widget.existingReminder?.title,
                validationMessage: 'reminder_titleRequired'.tr,
              ),

              // 内容
              FormFieldConfig(
                name: 'content',
                type: FormFieldType.textArea,
                labelText: 'reminder_contentLabel'.tr,
                required: true,
                initialValue: widget.existingReminder?.content,
                validationMessage: 'reminder_contentRequired'.tr,
                extra: {'maxLines': 3},
              ),

              // 图片（可选）
              FormFieldConfig(
                name: 'image',
                type: FormFieldType.imagePicker,
                labelText: 'reminder_imageLabel'.tr,
                required: false,
                initialValue:
                    widget.existingReminder?.imageUrl != null
                        ? {'url': widget.existingReminder!.imageUrl}
                        : null,
                extra: {'saveDirectory': 'reminder_images'},
              ),

              // 提醒时间配置
              FormFieldConfig(
                name: 'schedule',
                type: FormFieldType.reminderDate,
                labelText: 'reminder_timeLabel'.tr,
                required: true,
                initialValue:
                    widget.existingReminder != null
                        ? ReminderDateData(
                          type: _frequencyToType(
                            widget.existingReminder!.frequency,
                          ),
                          selectedDays: widget.existingReminder!.selectedDays,
                          time: widget.existingReminder!.time,
                        )
                        : const ReminderDateData(
                          type: ReminderDateType.daily,
                          selectedDays: [1, 2, 3, 4, 5, 6, 7],
                          time: TimeOfDay(hour: 9, minute: 0),
                        ),
              ),

              // 推送方式
              FormFieldConfig(
                name: 'pushMethod',
                type: FormFieldType.select,
                labelText: 'reminder_pushMethodLabel'.tr,
                required: true,
                initialValue:
                    widget.existingReminder?.pushMethod.index.toString() ?? '0',
                items: [
                  DropdownMenuItem(
                    value: '0',
                    child: Text('reminder_pushLocal'.tr),
                  ),
                  DropdownMenuItem(
                    value: '1',
                    child: Text('reminder_pushFcm'.tr),
                  ),
                  DropdownMenuItem(
                    value: '2',
                    child: Text('reminder_pushBoth'.tr),
                  ),
                ],
              ),

              // 优先级
              FormFieldConfig(
                name: 'priority',
                type: FormFieldType.select,
                labelText: 'reminder_priorityLabel'.tr,
                required: false,
                initialValue:
                    widget.existingReminder?.priority.toString() ?? '0',
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: '$i',
                      child: Text('reminder_priority$i'.tr),
                    ),
                ],
              ),
            ],
            onSubmit: _handleSubmit,
            submitButtonText: isEditing ? 'app_save'.tr : 'app_create'.tr,
            showSubmitButton: !widget.embedInSheet,
          ),
        ),
      );

    if (widget.embedInSheet) {
      return form;
    }

    return SuperCupertinoNavigationWrapper(
      title: Text(
        isEditing ? 'reminder_editReminder'.tr : 'reminder_createReminder'.tr,
      ),
      largeTitle:
          isEditing ? 'reminder_editReminder'.tr : 'reminder_createReminder'.tr,
      body: form,
    );
  }

  Future<void> _handleSubmit(Map<String, dynamic> values) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final title = values['title'] as String;
      final content = values['content'] as String;

      // 将 Map 转换为 ReminderDateData
      final scheduleMap = values['schedule'];
      final schedule = scheduleMap is ReminderDateData
          ? scheduleMap
          : ReminderDateData.fromMap(scheduleMap as Map<String, dynamic>);

      final imageData = values['image'] as Map<String, dynamic>?;
      final pushMethodIndex = int.parse(values['pushMethod'] as String? ?? '0');
      final priority = int.parse(values['priority'] as String? ?? '0');

      final imageUrl = imageData?['url'] as String?;

      if (widget.existingReminder != null) {
        // 编辑模式
        final updated = widget.existingReminder!.copyWith(
          title: title,
          content: content,
          imageUrl: imageUrl,
          frequency: _typeToFrequency(schedule.type),
          selectedDays: schedule.selectedDays,
          time: schedule.time ?? TimeOfDay.now(),
          pushMethod: ReminderPushMethod.values[pushMethodIndex],
          priority: priority,
        );
        await _service.updateReminder(updated);
      } else {
        // 创建模式
        await _service.addReminder(
          title: title,
          content: content,
          imageUrl: imageUrl,
          frequency: _typeToFrequency(schedule.type),
          selectedDays: schedule.selectedDays,
          time: schedule.time ?? TimeOfDay.now(),
          pushMethod: ReminderPushMethod.values[pushMethodIndex],
          priority: priority,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[ReminderFormScreen] 保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reminder_saveFailed'.trParams({'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  ReminderDateType _frequencyToType(ReminderFrequency frequency) {
    switch (frequency) {
      case ReminderFrequency.none:
        return ReminderDateType.none;
      case ReminderFrequency.daily:
        return ReminderDateType.daily;
      case ReminderFrequency.weekly:
        return ReminderDateType.weekly;
      case ReminderFrequency.monthly:
        return ReminderDateType.monthly;
    }
  }

  ReminderFrequency _typeToFrequency(ReminderDateType type) {
    switch (type) {
      case ReminderDateType.none:
        return ReminderFrequency.none;
      case ReminderDateType.daily:
        return ReminderFrequency.daily;
      case ReminderDateType.weekly:
        return ReminderFrequency.weekly;
      case ReminderDateType.monthly:
        return ReminderFrequency.monthly;
    }
  }
}
