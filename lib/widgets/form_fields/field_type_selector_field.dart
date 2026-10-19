// ignore_for_file: overridden_fields

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/form_fields/form_field_wrapper.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/plugins/database/controllers/field_controller.dart';
import 'package:aboutme/plugins/database/models/field_model.dart';
import 'package:skribble/skribble.dart';

import 'package:get/get.dart';
/// 字段类型选择器字段
///
/// 功能特性：
/// - 显示字段类型选择对话框
/// - 支持单选和多选模式
/// - 显示已选类型数量
/// - 支持配置模式（双 Tab）
class FieldTypeSelectorField extends FormFieldWrapper {
  /// 是否支持多选
  final bool multiSelect;

  /// 对话框标题
  final String? dialogTitle;

  /// 前缀图标
  final IconData? prefixIcon;

  /// 是否显示配置 Tab（启用后对话框会有两个 Tab）
  final bool showConfigTab;

  /// 初始字段模型（配置模式下使用）
  final FieldModel? initialField;

  /// 值变化回调
  @override
  final ValueChanged<dynamic>? onChanged;

  const FieldTypeSelectorField({
    super.key,
    required super.name,
    super.initialValue,
    this.multiSelect = true,
    this.dialogTitle,
    this.prefixIcon,
    this.showConfigTab = false,
    this.initialField,
    this.onChanged,
    super.enabled = true,
  });

  @override
  State<FieldTypeSelectorField> createState() => _FieldTypeSelectorFieldState();
}

class _FieldTypeSelectorFieldState
    extends FormFieldWrapperState<FieldTypeSelectorField> {
  late dynamic _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue =
        widget.initialValue ?? (widget.multiSelect ? <String>[] : null);
  }

  String get _selectedText {
    if (widget.multiSelect) {
      final selectedList = _selectedValue as List<String>?;
      if (selectedList == null || selectedList.isEmpty) return '未选择';
      return '已选择 ${selectedList.length} 个字段类型';
    } else {
      return _selectedValue?.toString() ?? '未选择';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading:
            widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: Theme.of(context).colorScheme.primary)
                : Icon(Icons.dashboard, color: Theme.of(context).colorScheme.primary),
        title: Text(widget.dialogTitle ?? '选择字段类型'),
        subtitle: Text(_selectedText),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.enabled ? _showFieldTypeSelector : null,
      ),
    );
  }

  Future<void> _showFieldTypeSelector() async {
    if (widget.showConfigTab && !widget.multiSelect) {
      // 配置模式：单选 + 双 Tab
      final result = await showDialog<FieldModel>(
        context: context,
        builder:
            (context) => FieldTypeSelectorDialog(
              initialSelectedTypes:
                  _selectedValue != null ? [_selectedValue as String] : [],
              dialogTitle: widget.dialogTitle ?? '选择字段类型',
              multiSelect: false,
              showConfigTab: true,
              initialField: widget.initialField,
            ),
      );

      if (result != null) {
        setState(() {
          _selectedValue = result.type;
        });
        widget.onChanged?.call(_selectedValue);
      }
    } else if (widget.multiSelect) {
      // 多选模式
      final result = await showDialog<List<String>>(
        context: context,
        builder:
            (context) => FieldTypeSelectorDialog(
              initialSelectedTypes: _selectedValue as List<String>? ?? [],
              dialogTitle: widget.dialogTitle ?? '选择字段类型',
              multiSelect: true,
            ),
      );

      if (result != null) {
        setState(() {
          _selectedValue = result;
        });
        widget.onChanged?.call(_selectedValue);
      }
    } else {
      // 单选模式（无配置）
      final result = await showDialog<String>(
        context: context,
        builder:
            (context) => FieldTypeSelectorDialog(
              initialSelectedTypes:
                  _selectedValue != null ? [_selectedValue as String] : [],
              dialogTitle: widget.dialogTitle ?? '选择字段类型',
              multiSelect: false,
            ),
      );

      if (result != null) {
        setState(() {
          _selectedValue = result;
        });
        widget.onChanged?.call(_selectedValue);
      }
    }
  }

  @override
  dynamic getValue() => _selectedValue;
}

/// 字段类型选择器对话框
class FieldTypeSelectorDialog extends StatefulWidget {
  /// 初始选中的字段类型列表
  final List<String> initialSelectedTypes;

  /// 对话框标题
  final String dialogTitle;

  /// 是否支持多选
  final bool multiSelect;

  /// 是否显示配置 Tab
  final bool showConfigTab;

  /// 初始字段模型（配置模式下使用）
  final FieldModel? initialField;

  const FieldTypeSelectorDialog({
    super.key,
    required this.initialSelectedTypes,
    required this.dialogTitle,
    this.multiSelect = true,
    this.showConfigTab = false,
    this.initialField,
  });

  @override
  State<FieldTypeSelectorDialog> createState() =>
      FieldTypeSelectorDialogState();
}

class FieldTypeSelectorDialogState extends State<FieldTypeSelectorDialog> {
  late Set<String> _selectedTypes;
  late String _selectedType;
  FormBuilderWrapperState? _wrapperState;

  /// 表单最近一次的实时值（类型切换重建表单时保留已填内容）
  Map<String, dynamic> _lastValues = {};

  /// 字段名称必填校验失败标注
  bool _nameError = false;

  /// 是否有选中的类型
  bool get _hasSelection => _selectedTypes.isNotEmpty;

  /// 获取所有可用的字段类型
  List<String> get _availableTypes => FieldController.getFieldTypes();

  /// 当前选中的字段类型
  String get currentType => _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedTypes = widget.initialSelectedTypes.toSet();

    // 如果没有初始选中类型，默认选中第一个
    if (_selectedTypes.isEmpty) {
      _selectedType = _availableTypes.first;
      _selectedTypes.add(_selectedType);
    } else {
      _selectedType = widget.initialField?.type ?? _selectedTypes.first;
    }
  }

  /// 全选或反选
  void _toggleSelectAll() {
    setState(() {
      if (_hasSelection) {
        _selectedTypes.clear();
      } else {
        _selectedTypes = _availableTypes.toSet();
      }
    });
  }

  /// 表单值变化：同步实时值；类型下拉切换时重建类型相关配置字段
  void _handleValuesChanged(Map<String, dynamic> values) {
    _lastValues = values;
    final type = values['__fieldType']?.toString();
    if (type != null && type.isNotEmpty && type != _selectedType) {
      setState(() => _selectedType = type);
    }
  }

  /// 构建配置表单字段（类型下拉 + 字段名称 + 类型相关配置）
  List<FormFieldConfig> _buildConfigFields() {
    // 解析已保存的配置（实时输入优先于持久化配置）
    final savedConfig = _parseDescription(widget.initialField?.description);
    String textOf(String key, [String fallback = '']) =>
        _lastValues[key]?.toString() ??
        savedConfig[key]?.toString() ??
        fallback;
    int intOf(String key, int fallback) =>
        int.tryParse(_lastValues[key]?.toString() ?? '') ??
        int.tryParse(savedConfig[key]?.toString() ?? '') ??
        fallback;

    final fields = <FormFieldConfig>[
      // 字段类型（下拉选择，切换即时重建下方配置）
      FormFieldConfig(
        name: '__fieldType',
        type: FormFieldType.select,
        labelText: '字段类型',
        initialValue: _selectedType,
        extra: {
          'items': [
            for (final type in _availableTypes)
              DropdownMenuItem(value: type, child: Text(type)),
          ],
        },
      ),
      // 字段名称（必填）
      FormFieldConfig(
        name: 'name',
        type: FormFieldType.text,
        labelText: '字段名称 *',
        hintText: '请输入字段名称',
        initialValue:
            _lastValues['name']?.toString() ?? widget.initialField?.name ?? '',
        required: true,
        validationMessage: '字段名称不能为空',
        prefixIcon: Icons.label,
      ),
    ];

    // 根据字段类型添加特定配置
    switch (_selectedType) {
      case 'Text':
      case 'Long Text':
      case 'Password':
        fields.addAll([
          FormFieldConfig(
            name: 'placeholder',
            type: FormFieldType.text,
            labelText: '占位提示',
            hintText: '输入框占位文本',
            initialValue: textOf('placeholder'),
            prefixIcon: Icons.help_outline,
          ),
          FormFieldConfig(
            name: 'defaultValue',
            type:
                _selectedType == 'Long Text'
                    ? FormFieldType.textArea
                    : FormFieldType.text,
            labelText: '默认值',
            hintText: '请输入默认值',
            initialValue: textOf('defaultValue'),
            prefixIcon: Icons.data_array,
          ),
          if (_selectedType == 'Long Text')
            FormFieldConfig(
              name: 'maxLines',
              type: FormFieldType.number,
              labelText: '最大行数',
              hintText: '默认 3 行',
              initialValue: intOf('maxLines', 3),
              prefixIcon: Icons.line_style,
            ),
        ]);
        break;

      case 'Integer':
      case 'Rating':
        fields.addAll([
          FormFieldConfig(
            name: 'minValue',
            type: FormFieldType.number,
            labelText: '最小值',
            hintText: '最小值',
            initialValue: intOf('minValue', 0),
            prefixIcon: Icons.arrow_downward,
          ),
          FormFieldConfig(
            name: 'maxValue',
            type: FormFieldType.number,
            labelText: '最大值',
            hintText: _selectedType == 'Rating' ? '默认 5' : '最大值',
            initialValue: intOf('maxValue', _selectedType == 'Rating' ? 5 : 100),
            prefixIcon: Icons.arrow_upward,
          ),
          FormFieldConfig(
            name: 'defaultValue',
            type: FormFieldType.number,
            labelText: '默认值',
            hintText: '请输入默认值',
            initialValue: intOf('defaultValue', 0),
            prefixIcon: Icons.data_array,
          ),
        ]);
        break;

      case 'Dropdown':
        fields.add(
          FormFieldConfig(
            name: 'options',
            type: FormFieldType.textArea,
            labelText: '选项列表',
            hintText: '每行一个选项',
            initialValue: textOf('options'),
            prefixIcon: Icons.list,
            extra: {'maxLines': 5},
          ),
        );
        break;

      case 'Date':
      case 'Time':
      case 'Date/Time':
        fields.addAll([
          FormFieldConfig(
            name: 'defaultValue',
            type: FormFieldType.text,
            labelText: '默认值',
            hintText: '留空使用当前时间',
            initialValue: textOf('defaultValue', 'now'),
            prefixIcon: Icons.access_time,
          ),
          FormFieldConfig(
            name: 'format',
            type: FormFieldType.text,
            labelText: '日期格式',
            hintText: _selectedType == 'Time' ? 'HH:mm' : 'yyyy-MM-dd',
            initialValue: textOf(
              'format',
              _selectedType == 'Time' ? 'HH:mm' : 'yyyy-MM-dd',
            ),
            prefixIcon: Icons.text_format,
          ),
        ]);
        break;

      case 'Checkbox':
        fields.add(
          FormFieldConfig(
            name: 'defaultValue',
            type: FormFieldType.switchField,
            labelText: '默认选中',
            hintText: '默认状态',
            initialValue: _lastValues['defaultValue'] == true ||
                savedConfig['defaultValue'] == true,
          ),
        );
        break;

      case 'URL':
        fields.addAll([
          FormFieldConfig(
            name: 'placeholder',
            type: FormFieldType.text,
            labelText: '占位提示',
            hintText: 'https://example.com',
            initialValue: textOf('placeholder'),
            prefixIcon: Icons.link,
          ),
          FormFieldConfig(
            name: 'defaultValue',
            type: FormFieldType.text,
            labelText: '默认 URL',
            hintText: '请输入默认 URL',
            initialValue: textOf('defaultValue'),
            prefixIcon: Icons.data_array,
          ),
        ]);
        break;
    }

    return fields;
  }

  /// 解析 description 字符串为 Map
  Map<String, dynamic> _parseDescription(String? description) {
    if (description == null || description.isEmpty) return {};

    // 尝试解析为 JSON
    try {
      if (description.trim().startsWith('{')) {
        // 如果是 JSON 格式
        final parsed = jsonDecode(description) as Map<String, dynamic>;
        return parsed;
      }
    } catch (e) {
      // JSON 解析失败，尝试其他格式
    }

    // 如果是旧格式的纯文本，作为 defaultValue 返回
    return {'defaultValue': description};
  }

  /// 保存并返回配置的字段模型
  FieldModel _buildFieldModel(Map<String, dynamic> values) {
    final name = values['name'] as String? ?? '';
    final description = _buildDescription(values);

    return FieldModel(
      id: widget.initialField?.id ?? '', // 调用者需要设置 ID
      name: name,
      type: _selectedType,
      description: description,
    );
  }

  /// 从表单值构建 description 字符串（排除名称与类型选择器内部键）
  String? _buildDescription(Map<String, dynamic> values) {
    final description = <String, dynamic>{};

    for (final key in values.keys) {
      if (key != 'name' && key != '__fieldType') {
        final value = values[key];
        if (value != null && value.toString().isNotEmpty) {
          description[key] = value;
        }
      }
    }

    return description.isEmpty ? null : jsonEncode(description);
  }

  void _handleConfirm() {
    if (widget.showConfigTab) {
      // 单表单模式：自行校验必填项，失败时标注且不关闭
      final values = _wrapperState?.currentValues ?? _lastValues;
      final name = values['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        setState(() => _nameError = true);
        return;
      }
      _handleConfigSubmit(values);
    } else {
      // 普通模式：直接返回选中的类型
      if (widget.multiSelect) {
        Navigator.pop(context, _selectedTypes.toList());
      } else {
        Navigator.pop(context, _selectedTypes.first);
      }
    }
  }

  void _handleConfigSubmit(Map<String, dynamic> values) {
    _nameError = false;
    final fieldModel = _buildFieldModel(values);
    Navigator.pop(context, fieldModel);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showConfigTab) {
      return _buildConfigForm();
    }
    return _buildPlainSelector();
  }

  /// 配置模式：合并单表单（类型下拉 + 名称必填 + 类型配置），
  /// 手绘面板外壳（配合 showDSDialog 使用）
  Widget _buildConfigForm() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: DsSketchPanel(
              theme: theme,
              radius: theme.radii.xl,
              padding: EdgeInsets.all(theme.spacing.lg),
              progress: WiredDrawTransition.progressOf(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.dialogTitle,
                    textAlign: TextAlign.center,
                    style: DsTypography.title.copyWith(color: theme.text),
                  ),
                  SizedBox(height: theme.spacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 必填校验失败标注
                          if (_nameError)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: theme.spacing.sm,
                              ),
                              child: Text(
                                '字段名称为必填项，请填写后重试',
                                style: DsTypography.caption.copyWith(
                                  color: theme.danger,
                                ),
                              ),
                            ),
                          // 类型切换时重建表单（同键已填值经 _lastValues 保留）
                          FormBuilderWrapper(
                            key: ValueKey(_selectedType),
                            onStateReady: (state) => _wrapperState = state,
                            config: FormConfig(
                              showSubmitButton: false,
                              showResetButton: false,
                              fieldSpacing: 16,
                              fields: _buildConfigFields(),
                              onValuesChanged: _handleValuesChanged,
                              onSubmit: _handleConfigSubmit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DSButton(
                        label: 'app_cancel'.tr,
                        variant: DSButtonVariant.secondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(width: theme.spacing.sm),
                      DSButton(
                        label: 'app_ok'.tr,
                        onPressed: _handleConfirm,
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

  /// 普通模式（多选/单选，无配置）：保留原列表选择
  Widget _buildPlainSelector() {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _buildTypeSelectionTab(),
      ),
      actions: [
        // 左侧全选/反选按钮（仅多选模式）
        if (widget.multiSelect)
          TextButton.icon(
            onPressed: _toggleSelectAll,
            icon: Icon(_hasSelection ? Icons.deselect : Icons.select_all),
            label: Text(_hasSelection ? '反选' : '全选'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (widget.multiSelect) const SizedBox(width: 8),
        // 右侧取消/确定按钮
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('app_cancel'.tr),
        ),
        FilledButton(
          onPressed: _hasSelection ? _handleConfirm : null,
          child: Text('app_ok'.tr),
        ),
      ],
    );
  }

  /// 构建类型选择列表（普通模式）
  Widget _buildTypeSelectionTab() {
    return ListView.builder(
      itemCount: _availableTypes.length,
      itemBuilder: (context, index) {
        final type = _availableTypes[index];
        final icon = FieldController.fieldTypes[type];
        final isSelected = _selectedTypes.contains(type);

        if (widget.multiSelect) {
          // 多选模式
          return CheckboxListTile(
            secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(type),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedTypes.add(type);
                } else {
                  _selectedTypes.remove(type);
                }
              });
            },
          );
        } else {
          // 单选模式
          return RadioListTile<String>(
            secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(type),
            value: type,
            groupValue: _selectedType,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                  _selectedTypes
                    ..clear()
                    ..add(value);
                });
              }
            },
          );
        }
      },
    );
  }
}
