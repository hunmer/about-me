import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/checkin/checkin_plugin.dart';
import 'package:aboutme/plugins/checkin/models/checkin_item.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 打卡项目表单屏幕（全屏，编辑模式入口）
///
/// 使用 FormBuilderWrapper 进行声明式表单构建；
/// 新建模式通过 [showAsSheet] 以底部弹层打开
class CheckinFormScreen extends StatefulWidget {
  /// 初始打卡项目（编辑模式）
  final CheckinItem? initialItem;

  const CheckinFormScreen({super.key, this.initialItem});

  /// 以底部弹层形式打开表单（新建打卡项目）
  static Future<CheckinItem?> showAsSheet(
    BuildContext context, {
    CheckinItem? initialItem,
  }) {
    final fieldsKey = GlobalKey<CheckinFormFieldsState>();
    return SmoothBottomSheet.showForm<CheckinItem>(
      context: context,
      title: initialItem == null
          ? 'checkin_addCheckinItem'.tr
          : 'checkin_editCheckinItemTitle'.tr,
      onSave: () => fieldsKey.currentState?.submit(),
      child: CheckinFormFields(key: fieldsKey, initialItem: initialItem),
    );
  }

  @override
  State<CheckinFormScreen> createState() => _CheckinFormScreenState();
}

class _CheckinFormScreenState extends State<CheckinFormScreen> {
  final GlobalKey<CheckinFormFieldsState> _fieldsKey =
      GlobalKey<CheckinFormFieldsState>();

  @override
  void initState() {
    super.initState();

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  /// 更新路由上下文
  void _updateRouteContext() {
    final isEdit = widget.initialItem != null;
    final itemName = widget.initialItem?.name ?? '';

    if (isEdit) {
      RouteHistoryManager.updateCurrentContext(
        pageId: "/checkin_form_edit",
        title: '编辑打卡项目 - $itemName',
        params: {'itemName': itemName},
      );
    } else {
      RouteHistoryManager.updateCurrentContext(
        pageId: "/checkin_form_new",
        title: '新建打卡项目',
        params: {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialItem == null
              ? 'checkin_addCheckinItem'.tr
              : 'checkin_editCheckinItemTitle'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => _fieldsKey.currentState?.submit(),
            child: Text('checkin_save'.tr),
          ),
        ],
      ),
      body: CheckinFormFields(
        key: _fieldsKey,
        initialItem: widget.initialItem,
      ),
    );
  }
}

/// 打卡项目表单内容（供全屏页面与底部弹层复用）
///
/// 使用 FormBuilderWrapper 进行声明式表单构建
class CheckinFormFields extends StatefulWidget {
  /// 初始打卡项目（编辑模式）
  final CheckinItem? initialItem;

  const CheckinFormFields({super.key, this.initialItem});

  @override
  State<CheckinFormFields> createState() => CheckinFormFieldsState();
}

class CheckinFormFieldsState extends State<CheckinFormFields> {
  /// 表单 key（用于名称验证）
  final GlobalKey<FormBuilderState> _formKey = GlobalKey<FormBuilderState>();

  /// FormBuilderWrapper 的状态（用于触发提交）
  FormBuilderWrapperState? _wrapperState;

  /// 现有分组集合
  Set<String> _existingGroups = <String>{};

  /// 现有名称集合
  Set<String> _existingNames = <String>{};

  /// 当前提醒类型（用于条件显示字段）
  ReminderType? _currentReminderType;

  @override
  void initState() {
    super.initState();
    _currentReminderType = widget.initialItem?.reminderSettings?.type;
    _loadExistingData();
  }

  /// 加载现有分组和名称
  void _loadExistingData() {
    final items = CheckinPlugin.shared.checkinItems;
    if (items.isNotEmpty) {
      _existingGroups =
          items.map((item) => item.group).whereType<String>().toSet();
      if (_existingGroups.isEmpty) {
        _existingGroups.add('默认分组');
      }

      _existingNames =
          items
              .where((item) => item.id != widget.initialItem?.id)
              .map((item) => item.name)
              .toSet();
    } else {
      _existingGroups = {'默认分组'};
      _existingNames = {};
    }
  }

  /// 验证名称是否重复
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'checkin_nameRequiredError'.tr;
    }
    if (_existingNames.contains(value.trim())) {
      return 'checkin_nameExistsError'.tr;
    }
    return null;
  }

  /// 提交表单
  void _handleSubmit(Map<String, dynamic> values) {
    // 图标颜色数据
    final iconColorData = values['iconColor'] as Map<String, dynamic>?;
    if (iconColorData == null) {
      Toast.error('请选择图标');
      return;
    }
    final icon = iconColorData['icon'] as IconData?;
    final color = iconColorData['color'] as Color?;

    // 验证必要字段
    if (icon == null || color == null) {
      Toast.error('请选择图标');
      return;
    }

    // 提醒设置
    ReminderSettings? reminderSettings;
    final reminderType = values['reminderType'] as ReminderType?;
    if (reminderType != null) {
      switch (reminderType) {
        case ReminderType.weekly:
          final weekdays = values['weekdays'] as List<int>? ?? [];
          reminderSettings = ReminderSettings(
            type: reminderType,
            weekdays: weekdays,
            timeOfDay: values['reminderTime'] as TimeOfDay? ?? TimeOfDay.now(),
          );
          break;
        case ReminderType.monthly:
          reminderSettings = ReminderSettings(
            type: reminderType,
            dayOfMonth: values['monthDay'] as int?,
            timeOfDay: values['reminderTime'] as TimeOfDay? ?? TimeOfDay.now(),
          );
          break;
        case ReminderType.specific:
          reminderSettings = ReminderSettings(
            type: reminderType,
            specificDate: values['specificDate'] as DateTime?,
            timeOfDay: values['reminderTime'] as TimeOfDay? ?? TimeOfDay.now(),
          );
          break;
      }
    }

    // 分组处理
    final groupValue = values['group'] as String?;
    final String? trimmedGroup = groupValue?.trim();
    final group =
        (trimmedGroup == null || trimmedGroup.isEmpty) ? null : trimmedGroup;

    // 构建打卡项目
    final item = CheckinItem(
      id: widget.initialItem?.id,
      name: (values['name'] as String).trim(),
      icon: icon,
      color: color,
      group: group,
      isPenalty: values['isPenalty'] as bool? ?? false,
      reminderSettings: reminderSettings,
      checkInRecords: widget.initialItem?.checkInRecords ?? {},
    );

    Navigator.of(context).pop(item);
  }

  /// 提醒类型变化回调
  void _onReminderTypeChanged(dynamic value) {
    final type = value is ReminderType ? value : null;
    setState(() {
      _currentReminderType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FormBuilderWrapper(
        formKey: _formKey,
        onStateReady: (state) => _wrapperState = state,
        config: FormConfig(
          submitButtonText: 'checkin_save'.tr,
          showSubmitButton: false,
          showResetButton: false,
          fieldSpacing: 16,
          onValidationFailed: (errors) {
            Toast.error(errors.values.join(', '));
          },
          onSubmit: _handleSubmit,
          fields: [
            // 图标和颜色选择器
            FormFieldConfig(
              name: 'iconColor',
              type: FormFieldType.circleIconPicker,
              initialValue: {
                'icon': widget.initialItem?.icon ?? Icons.check_circle,
                'color': widget.initialItem?.color ?? Colors.blue,
              },
            ),

            // 名称输入框
            FormFieldConfig(
              name: 'name',
              type: FormFieldType.text,
              labelText: 'checkin_nameLabel'.tr,
              hintText: 'checkin_nameHint'.tr,
              initialValue: widget.initialItem?.name ?? '',
              required: true,
              validationMessage: 'checkin_nameRequiredError'.tr,
            ),

            // 分组输入框
            FormFieldConfig(
              name: 'group',
              type: FormFieldType.text,
              labelText: 'checkin_groupLabel'.tr,
              hintText: 'checkin_groupHint'.tr,
              initialValue: widget.initialItem?.group ?? '',
            ),

            // 扣分项开关
            FormFieldConfig(
              name: 'isPenalty',
              type: FormFieldType.switchField,
              labelText: 'checkin_penaltyLabel'.tr,
              hintText: 'checkin_penaltyHint'.tr,
              prefixIcon: Icons.remove_circle_outline,
              initialValue: widget.initialItem?.isPenalty ?? false,
            ),

            // 提醒类型选择器
            FormFieldConfig(
              name: 'reminderType',
              type: FormFieldType.select,
              labelText: 'checkin_reminderTypeLabel'.tr,
              initialValue: widget.initialItem?.reminderSettings?.type,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('checkin_noReminder'.tr),
                ),
                ...ReminderType.values.map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(switch (type) {
                      ReminderType.weekly => 'checkin_weeklyReminder'.tr,
                      ReminderType.monthly => 'checkin_monthlyReminder'.tr,
                      ReminderType.specific => 'checkin_specificDateReminder'.tr,
                    }),
                  ),
                ),
              ],
              onChanged: _onReminderTypeChanged,
            ),

            // 月份日期选择器（仅当选择每月提醒时显示）
            FormFieldConfig(
              name: 'monthDay',
              type: FormFieldType.select,
              labelText: 'checkin_monthlyReminderDayLabel'.tr,
              initialValue: widget.initialItem?.reminderSettings?.dayOfMonth,
              visible:
                  (values) => values['reminderType'] == ReminderType.monthly,
              items: List.generate(31, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}${'checkin_daySuffix'.tr}'),
                );
              }),
            ),

            // 特定日期选择器（仅当选择特定日期提醒时显示）
            FormFieldConfig(
              name: 'specificDate',
              type: FormFieldType.date,
              labelText: 'checkin_selectDate'.tr,
              initialValue:
                  widget.initialItem?.reminderSettings?.specificDate,
              visible:
                  (values) => values['reminderType'] == ReminderType.specific,
              extra: {
                'firstDate': DateTime.now(),
                'lastDate': DateTime.now().add(const Duration(days: 365 * 2)),
              },
            ),

            // 提醒时间选择器（有提醒类型时显示）
            FormFieldConfig(
              name: 'reminderTime',
              type: FormFieldType.time,
              labelText: 'checkin_selectTime'.tr,
              initialValue:
                  widget.initialItem?.reminderSettings?.timeOfDay ??
                  TimeOfDay.now(),
              visible: (values) => values['reminderType'] != null,
            ),
          ],
        ),
        contentBuilder: (context, fields) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标准字段
              for (final field in fields) ...[
                field,
                const SizedBox(height: 16),
              ],

              // 星期选择器（条件显示）
              if (_currentReminderType == ReminderType.weekly) ...[
                _buildWeekdaySelector(),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
        buttonBuilder: (context, onSubmit, onReset) {
          return const SizedBox.shrink(); // 保存按钮由外壳提供
        },
      ),
    );
  }

  /// 触发表单提交（供外部保存按钮调用）
  void submit() {
    // 先验证名称
    final nameValue = _formKey.currentState?.fields['name']?.value as String?;
    final nameError = _validateName(nameValue);
    if (nameError != null) {
      Toast.error(nameError);
      return;
    }
    // 使用 wrapperState 提交表单
    _wrapperState?.submitForm();
  }

  /// 构建星期选择器
  Widget _buildWeekdaySelector() {
    final weekdays = [
      'checkin_sunday'.tr,
      'checkin_monday'.tr,
      'checkin_tuesday'.tr,
      'checkin_wednesday'.tr,
      'checkin_thursday'.tr,
      'checkin_friday'.tr,
      'checkin_saturday'.tr,
    ];

    final theme = DSThemeBridge.resolve(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.textSub.withValues(alpha: 0.2)),
      ),
      child: FormBuilderField<List<int>>(
        name: 'weekdays',
        initialValue: widget.initialItem?.reminderSettings?.weekdays ?? <int>[],
        builder: (fieldState) {
          final selectedWeekdays = fieldState.value ?? <int>[];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final isSelected = selectedWeekdays.contains(index);
              return DSThemeBridge(
                child: DSChip(
                  label: weekdays[index],
                  selected: isSelected,
                  onSelected: (_) {
                    final newWeekdays = List<int>.from(selectedWeekdays);
                    if (isSelected) {
                      newWeekdays.remove(index);
                    } else {
                      newWeekdays.add(index);
                    }
                    fieldState.didChange(newWeekdays);
                  },
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
