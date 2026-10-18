/// 动作配置表单组件
/// 动态生成动作参数配置表单
library;

import 'package:flutter/material.dart';
import 'package:aboutme/core/action/models/action_definition.dart';
import 'package:aboutme/core/action/models/action_form.dart';
import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:get/get.dart';

/// 表单值改变回调
typedef OnFormChanged = void Function(Map<String, dynamic> values);

/// 动作配置表单（手绘风）
class ActionConfigForm extends StatefulWidget {
  final ActionDefinition actionDefinition;
  final OnFormChanged? onChanged;
  final Map<String, dynamic>? initialData;
  final bool readOnly;

  const ActionConfigForm({
    super.key,
    required this.actionDefinition,
    this.onChanged,
    this.initialData,
    this.readOnly = false,
  });

  @override
  State<ActionConfigForm> createState() => _ActionConfigFormState();
}

class _ActionConfigFormState extends State<ActionConfigForm> {
  // 表单数据
  final Map<String, dynamic> _formData = {};

  // 文本输入控制器（DSInput 无 initialValue，按字段名懒创建）
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();

    // 初始化表单数据
    if (widget.initialData != null) {
      _formData.addAll(widget.initialData!);
    } else if (widget.actionDefinition.form != null) {
      for (final entry in widget.actionDefinition.form!.fields.entries) {
        final field = entry.value;
        if (field.defaultValue != null) {
          _formData[entry.key] = field.defaultValue;
        }
      }
    }

    // 延迟触发初始变化回调，避免在构建过程中调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitChange();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerOf(String fieldName, String initial) {
    return _controllers.putIfAbsent(
      fieldName,
      () => TextEditingController(text: initial),
    );
  }

  void _emitChange() {
    widget.onChanged?.call(Map.from(_formData));
  }

  void _updateField(String fieldName, dynamic value) {
    setState(() {
      _formData[fieldName] = value;
    });
    _emitChange();
  }

  bool get _fieldReadOnly => widget.readOnly;

  List<Widget> _buildFormFields() {
    final widgets = <Widget>[];

    if (widget.actionDefinition.form == null) {
      // 没有表单配置，显示默认字段
      return _buildDefaultFields();
    }

    final form = widget.actionDefinition.form!;
    final sortedFields = form.getSortedFields();

    for (final entry in sortedFields) {
      final fieldName = entry.key;
      final fieldConfig = entry.value;

      // 跳过隐藏字段
      if (fieldConfig.hidden) continue;

      widgets.add(_buildFormField(fieldName, fieldConfig));
    }

    return widgets;
  }

  List<Widget> _buildDefaultFields() {
    // 为 openPlugin 动作显示插件选择器
    if (widget.actionDefinition.id == BuiltInActions.openPlugin) {
      return [
        _buildPluginSelectorField(
          'plugin',
          'core_pluginName'.tr,
          'core_selectPluginToOpen'.tr,
          _formData['plugin'] as String?,
        ),
      ];
    }

    // 默认显示空提示
    return [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Builder(
          builder: (context) {
            final theme = AppTheme.of(context);
            return Text(
              'core_noExtraConfig'.tr,
              style: DsTypography.caption
                  .copyWith(color: theme.textSub, fontStyle: FontStyle.italic),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildFormField(String fieldName, FormFieldConfig config) {
    Widget fieldWidget;

    switch (config.type) {
      case FormFieldType.text:
        fieldWidget = _buildTextField(fieldName, config);
        break;
      case FormFieldType.textarea:
        fieldWidget = _buildTextArea(fieldName, config);
        break;
      case FormFieldType.select:
        fieldWidget = _buildSelectField(fieldName, config);
        break;
      case FormFieldType.multiSelect:
        fieldWidget = _buildMultiSelectField(fieldName, config);
        break;
      case FormFieldType.checkbox:
        fieldWidget = _buildCheckboxField(fieldName, config);
        break;
      case FormFieldType.switchField:
        fieldWidget = _buildSwitchField(fieldName, config);
        break;
      case FormFieldType.slider:
        fieldWidget = _buildSliderField(fieldName, config);
        break;
      case FormFieldType.number:
        fieldWidget = _buildNumberField(fieldName, config);
        break;
      case FormFieldType.date:
        fieldWidget = _buildDateField(fieldName, config);
        break;
      case FormFieldType.time:
        fieldWidget = _buildTimeField(fieldName, config);
        break;
      case FormFieldType.dateTime:
        fieldWidget = _buildDateTimeField(fieldName, config);
        break;
      case FormFieldType.pluginSelector:
        fieldWidget = _buildPluginSelectorField(
          fieldName,
          config.label,
          config.hint,
          _formData[fieldName] as String?,
        );
        break;
      case FormFieldType.colorPicker:
        fieldWidget = _buildColorPickerField(fieldName, config);
        break;
      case FormFieldType.iconSelector:
        fieldWidget = _buildIconSelectorField(fieldName, config);
        break;
      default:
        fieldWidget = _buildTextField(fieldName, config);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: fieldWidget,
    );
  }

  Widget _buildTextField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as String? ?? '';

    return DSInput(
      controller: _controllerOf(fieldName, value),
      label: config.label,
      hint: config.hint,
      enabled: !(_fieldReadOnly || config.readOnly),
      onChanged: (value) => _updateField(fieldName, value),
    );
  }

  Widget _buildTextArea(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as String? ?? '';

    return DSInput(
      controller: _controllerOf(fieldName, value),
      label: config.label,
      hint: config.hint,
      maxLines: 3,
      enabled: !(_fieldReadOnly || config.readOnly),
      onChanged: (value) => _updateField(fieldName, value),
    );
  }

  Widget _buildSelectField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(config.label),
        const SizedBox(height: 4),
        DSSelect<String?>(
          value: value as String?,
          hint: config.hint ?? 'core_notSelected'.tr,
          enabled: !(_fieldReadOnly || config.readOnly),
          items: [
            if (!config.required)
              DSSelectItem<String?>(
                value: null,
                label: 'core_notSelected'.tr,
              ),
            ...?config.options?.map(
              (option) => DSSelectItem<String?>(
                value: option.value,
                label: option.description != null
                    ? '${option.label} · ${option.description}'
                    : option.label,
              ),
            ),
          ],
          onChanged: _fieldReadOnly || config.readOnly
              ? (_) {}
              : (value) => _updateField(fieldName, value),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(config.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...?config.options?.map((option) {
              final isSelected = value.contains(option.value);
              return DSChip(
                label: option.label,
                selected: isSelected,
                onSelected: _fieldReadOnly || config.readOnly
                    ? null
                    : (_) {
                        setState(() {
                          if (isSelected) {
                            value.remove(option.value);
                          } else {
                            value.add(option.value);
                          }
                          _updateField(fieldName, value);
                        });
                      },
              );
            }),
          ],
        ),
        if (config.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: _buildLabel(config.hint!),
          ),
      ],
    );
  }

  Widget _buildCheckboxField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as bool? ?? false;
    final disabled = _fieldReadOnly || config.readOnly;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DSCheckbox(
          value: value,
          onChanged: disabled ? null : (value) => _updateField(fieldName, value),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(config.label),
              if (config.hint != null) _buildLabel(config.hint!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as bool? ?? false;
    final disabled = _fieldReadOnly || config.readOnly;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(config.label),
              if (config.hint != null) _buildLabel(config.hint!),
            ],
          ),
        ),
        DSSwitch(
          value: value,
          onChanged: disabled ? null : (value) => _updateField(fieldName, value),
        ),
      ],
    );
  }

  Widget _buildSliderField(String fieldName, FormFieldConfig config) {
    final value = (_formData[fieldName] as num?)?.toDouble() ??
        (config.defaultValue as num?)?.toDouble() ??
        0.0;

    final min = (config.extraParams?['min'] as num?)?.toDouble() ?? 0.0;
    final max = (config.extraParams?['max'] as num?)?.toDouble() ?? 100.0;
    final disabled = _fieldReadOnly || config.readOnly;
    // DSSlider 取 0.0~1.0 归一值
    final normalized = max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('${config.label}: ${value.round()}'),
        DSSlider(
          value: normalized,
          onChanged: disabled
              ? null
              : (normalized) =>
                  _updateField(fieldName, min + normalized * (max - min)),
        ),
      ],
    );
  }

  Widget _buildNumberField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as num?;

    return DSInput(
      controller: _controllerOf(fieldName, value?.toString() ?? ''),
      label: config.label,
      hint: config.hint,
      keyboardType: TextInputType.number,
      enabled: !(_fieldReadOnly || config.readOnly),
      onChanged: (value) => _updateField(
        fieldName,
        value.isEmpty ? null : num.tryParse(value),
      ),
    );
  }

  /// 值展示行（日期/时间/颜色等点选字段的触发行）
  Widget _buildPickerRow({
    required String label,
    required String displayText,
    required DsIconKind icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Builder(
      builder: (context) {
        final theme = AppTheme.of(context);
        Widget row = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(label),
                  const SizedBox(height: 2),
                  Text(
                    displayText,
                    style: DsTypography.body.copyWith(color: theme.text),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            if (trailing != null)
              trailing
            else
              DsIcon(icon, size: 22, color: theme.textSub),
          ],
        );
        // 整行作为点击区（onTap 为 null 时不可点）
        if (onTap != null) {
          row = Pressable(onPressed: onTap, builder: (_, __) => row);
        }
        return row;
      },
    );
  }

  Widget _buildDateField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as DateTime?;

    return _buildPickerRow(
      label: config.label,
      displayText: value != null
          ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
          : config.hint ?? 'core_selectDate'.tr,
      icon: DsIconKind.calendar,
      onTap: _fieldReadOnly || config.readOnly
          ? null
          : () async {
              final date = await showDSDatePickerDialog(
                context: context,
                initial: value,
                cancelText: 'app_cancel'.tr,
                confirmText: 'app_confirm'.tr,
              );
              if (date != null) {
                _updateField(fieldName, date);
              }
            },
    );
  }

  Widget _buildTimeField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as TimeOfDay?;

    return _buildPickerRow(
      label: config.label,
      displayText:
          value != null ? value.format(context) : config.hint ?? 'core_selectTime'.tr,
      icon: DsIconKind.clock,
      onTap: _fieldReadOnly || config.readOnly
          ? null
          : () async {
              final time = await showDSTimePickerDialog(
                context: context,
                initial: value,
                cancelText: 'app_cancel'.tr,
                confirmText: 'app_confirm'.tr,
              );
              if (time != null) {
                _updateField(fieldName, time);
              }
            },
    );
  }

  Widget _buildDateTimeField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as DateTime?;

    return _buildPickerRow(
      label: config.label,
      displayText: value != null
          ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
          : config.hint ?? 'core_selectDateTime'.tr,
      icon: DsIconKind.calendarCheck,
      onTap: _fieldReadOnly || config.readOnly
          ? null
          : () async {
              final date = await showDSDatePickerDialog(
                context: context,
                initial: value,
                cancelText: 'app_cancel'.tr,
                confirmText: 'app_confirm'.tr,
              );
              if (date != null) {
                final time = await showDSTimePickerDialog(
                  context: context,
                  initial: value != null
                      ? TimeOfDay.fromDateTime(value)
                      : null,
                  cancelText: 'app_cancel'.tr,
                  confirmText: 'app_confirm'.tr,
                );
                if (time != null) {
                  _updateField(
                    fieldName,
                    DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                }
              }
            },
    );
  }

  Widget _buildPluginSelectorField(
    String fieldName,
    String label,
    String? hint,
    String? currentValue,
  ) {
    // 获取所有真实插件
    final plugins = globalPluginManager.allPlugins;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 4),
        DSSelect<String?>(
          value: currentValue,
          hint: hint ?? 'core_notSelected'.tr,
          items: [
            DSSelectItem<String?>(
              value: null,
              label: 'core_notSelected'.tr,
            ),
            ...plugins.map(
              (plugin) => DSSelectItem<String?>(
                value: plugin.id,
                label: plugin.getPluginName(context) ?? plugin.id,
              ),
            ),
          ],
          onChanged: (value) => _updateField(fieldName, value),
        ),
      ],
    );
  }

  Widget _buildColorPickerField(String fieldName, FormFieldConfig config) {
    final value = _formData[fieldName] as Color?;

    return _buildPickerRow(
      label: config.label,
      displayText: value != null
          ? '#${value.value.toRadixString(16).padLeft(8, '0')}'
          : config.hint ?? 'core_selectColor'.tr,
      icon: DsIconKind.palette,
      onTap: _fieldReadOnly || config.readOnly
          ? null
          : () => _pickColor(context, fieldName, value),
      trailing: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          return JellyBox(
            width: 30,
            height: 30,
            radius: theme.radii.sm,
            color: value ?? theme.surfaceAlt,
          );
        },
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    String fieldName,
    Color? current,
  ) async {
    // 预设颜色列表（待选色板数据，非 UI 主题色）
    final presetColors = [
      const Color(0xFFF44336),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF03A9F4),
      const Color(0xFF00BCD4),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFF8BC34A),
      const Color(0xFFCDDC39),
      const Color(0xFFFFEB3B),
      const Color(0xFFFFC107),
      const Color(0xFFFF9800),
      const Color(0xFFFF5722),
      const Color(0xFF795548),
      const Color(0xFF9E9E9E),
      const Color(0xFF607D8B),
      const Color(0xFF212121),
    ];

    final theme = AppTheme.of(context);
    final color = await showDSDialog<Color>(
      context: context,
      theme: theme,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DsSketchPanel(
          theme: theme,
          radius: theme.radii.xxl,
          padding: EdgeInsets.all(theme.spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'app_selectColor'.tr,
                textAlign: TextAlign.center,
                style: DsTypography.title.copyWith(color: theme.text),
              ),
              SizedBox(height: theme.spacing.lg),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: [
                  for (final c in presetColors)
                    Pressable(
                      onPressed: () => Navigator.of(context).pop(c),
                      builder: (context, states) {
                        final pressed =
                            states.contains(WidgetState.pressed);
                        return JellyBox(
                          width: 38,
                          height: 38,
                          radius: theme.radii.sm,
                          color: pressed ? c.mixBlack(0.08) : c,
                          raised: !pressed,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (color != null) {
      _updateField(fieldName, color);
    }
  }

  Widget _buildIconSelectorField(String fieldName, FormFieldConfig config) {
    return Builder(
      builder: (context) {
        final theme = AppTheme.of(context);
        return Text(
          'core_iconSelectorNotImplemented'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Builder(
      builder: (context) {
        final theme = AppTheme.of(context);
        return Text(
          text,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildFormFields(),
    );
  }
}
