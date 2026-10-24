import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
import 'package:aboutme/plugins/habits/models/habit.dart';
import 'package:aboutme/plugins/habits/models/skill.dart';
import 'package:aboutme/plugins/habits/utils/habits_utils.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/core/utils/icon_utils.dart';

class HabitForm extends StatefulWidget {
  final Habit? initialHabit;
  final Function(Habit) onSave;
  final bool showSubmitButton;
  final void Function(FormBuilderWrapperState)? onStateReady;

  const HabitForm({
    super.key,
    this.initialHabit,
    required this.onSave,
    this.showSubmitButton = true,
    this.onStateReady,
  });

  @override
  State<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<HabitForm> {
  GlobalKey<FormBuilderState> get _formKey => _internalFormKey;
  final GlobalKey<FormBuilderState> _internalFormKey =
      GlobalKey<FormBuilderState>();
  List<Skill> _skills = [];

  @override
  void initState() {
    super.initState();
    _loadSkills();
    // 设置路由上下文
    _updateRouteContext();
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.initialHabit;

    return FormBuilderWrapper(
      formKey: _formKey,
      onStateReady: (state) => widget.onStateReady?.call(state),
      config: FormConfig(
        fields: [
          // 圆形图标选择器（头像）
          FormFieldConfig(
            name: 'icon',
            type: FormFieldType.circleIconPicker,
            initialValue:
                habit?.icon != null
                    ? {
                      'icon': dynamicIconData(
                        int.parse(habit!.icon!),
                        fontFamily: 'MaterialIcons',
                      ),
                      'color': Colors.blue,
                    }
                    : {'icon': Icons.check_rounded, 'color': Colors.blue},
            extra: {
              'initialBackgroundColor': Colors.blue,
              'showLabel': true,
              'labelText': 'habits_icon'.tr,
            },
          ),
          // 标题
          FormFieldConfig(
            name: 'title',
            type: FormFieldType.text,
            labelText: 'habits_title'.tr,
            initialValue: habit?.title ?? '',
            required: true,
            validationMessage: 'habits_pleaseEnterTitle'.tr,
          ),
          // 备注
          FormFieldConfig(
            name: 'notes',
            type: FormFieldType.textArea,
            labelText: 'habits_notes'.tr,
            initialValue: habit?.notes ?? '',
            extra: {'minLines': 3, 'maxLines': 5},
          ),
          // 分组
          FormFieldConfig(
            name: 'group',
            type: FormFieldType.text,
            labelText: 'habits_group'.tr,
            initialValue: habit?.group ?? '',
          ),
          // 时长
          FormFieldConfig(
            name: 'durationMinutes',
            type: FormFieldType.number,
            labelText: '${'habits_duration'.tr} (${'habits_minutes'.tr})',
            initialValue: habit?.durationMinutes ?? 30,
          ),
          // 技能选择（可选）
          FormFieldConfig(
            name: 'skillId',
            type: FormFieldType.select,
            labelText: 'habits_skill'.tr,
            initialValue:
                _skills.any((s) => s.id == habit?.skillId)
                    ? habit?.skillId
                    : null,
            items: _buildSkillItems(),
          ),
        ],
        submitButtonText: 'habits_save'.tr,
        showSubmitButton: widget.showSubmitButton,
        showResetButton: false,
        fieldSpacing: 20,
        onSubmit: _handleSubmit,
        onValidationFailed: (errors) {
          Toast.error('请检查输入：${errors.values.join(", ")}');
        },
      ),
      contentBuilder: (context, fields) {
        // 图标选择器（CircleIconPickerField）与其余表单字段依次渲染
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...fields
                  .map(
                    (field) =>
                        Column(children: [field, const SizedBox(height: 20)]),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _handleSubmit(Map<String, dynamic> values) {
    final iconData = values['icon'] as Map<String, dynamic>?;
    final habit = Habit(
      id: widget.initialHabit?.id ?? HabitsUtils.generateId(),
      title: values['title'] as String? ?? '',
      notes:
          (values['notes'] as String?)?.isEmpty ?? true
              ? null
              : values['notes'] as String?,
      group:
          (values['group'] as String?)?.isEmpty ?? true
              ? null
              : values['group'] as String?,
      icon: (iconData?['icon'] as IconData?)?.codePoint.toString(),
      // 表单不再上传图片，编辑时保留原有图片
      image: widget.initialHabit?.image,
      durationMinutes:
          int.tryParse(values['durationMinutes']?.toString() ?? '30') ?? 30,
      skillId: values['skillId'] as String?,
      tags: const [],
    );
    widget.onSave(habit);
  }

  /// 构建技能选择项
  List<DropdownMenuItem> _buildSkillItems() {
    return [
      DropdownMenuItem<String>(
        value: null,
        child: Text('habits_selectSkill'.tr),
      ),
      ..._skills.map((skill) {
        return DropdownMenuItem<String>(
          value: skill.id,
          child: Text(skill.title),
        );
      }),
    ];
  }

  Future<void> _loadSkills() async {
    try {
      final habitsPlugin = PluginManager.instance.getPlugin('habits');
      if (habitsPlugin != null && habitsPlugin is HabitsPlugin) {
        final controller = habitsPlugin.getSkillController();
        final skills = controller.getSkills();
        setState(() {
          _skills = skills;
        });
      } else {
        debugPrint('Habits plugin not found or invalid');
        setState(() {
          _skills = [];
        });
      }
    } catch (e) {
      debugPrint('Error loading skills: $e');
      setState(() {
        _skills = [];
      });
    }
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    final isEdit = widget.initialHabit != null;
    final habitId = widget.initialHabit?.id ?? '';
    final habitTitle = widget.initialHabit?.title ?? '';

    RouteHistoryManager.updateCurrentContext(
      pageId: '/habit_form',
      title: isEdit ? '编辑习惯 - $habitTitle' : '新建习惯',
      params: {
        'mode': isEdit ? 'edit' : 'create',
        if (isEdit) 'habitId': habitId,
        if (isEdit) 'habitTitle': habitTitle,
      },
    );
  }
}
