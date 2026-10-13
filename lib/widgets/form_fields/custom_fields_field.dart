import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/custom_field.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 自定义字段组件
///
/// 功能特性：
/// - 支持添加、编辑、删除键值对字段
/// - DS 果冻风格列表与对话框
/// - 支持 inline 模式（label在左，字段列表在右）
class CustomFieldsField extends StatefulWidget {
  /// 自定义字段列表
  final List<CustomField> fields;

  /// 字段变更回调
  final Function(List<CustomField>) onFieldsChanged;

  /// 标签文本
  final String? labelText;

  /// 是否使用inline模式
  final bool inline;

  /// 添加按钮文本
  final String? addButtonText;

  /// 添加字段对话框标题
  final String? addDialogTitle;

  /// 编辑字段对话框标题
  final String? editDialogTitle;

  /// 字段名标签
  final String? fieldNameLabel;

  /// 字段名提示
  final String? fieldNameHint;

  /// 字段值标签
  final String? fieldValueLabel;

  /// 字段值提示
  final String? fieldValueHint;

  /// 删除确认对话框标题
  final String? deleteConfirmTitle;

  /// 删除确认内容
  final String? deleteConfirmContent;

  /// inline模式下label的宽度
  final double labelWidth;

  const CustomFieldsField({
    super.key,
    required this.fields,
    required this.onFieldsChanged,
    this.labelText,
    this.inline = false,
    this.addButtonText,
    this.addDialogTitle,
    this.editDialogTitle,
    this.fieldNameLabel,
    this.fieldNameHint,
    this.fieldValueLabel,
    this.fieldValueHint,
    this.deleteConfirmTitle,
    this.deleteConfirmContent,
    this.labelWidth = 100,
  });

  @override
  State<CustomFieldsField> createState() => _CustomFieldsFieldState();
}

class _CustomFieldsFieldState extends State<CustomFieldsField> {
  late List<CustomField> _fields;

  @override
  void initState() {
    super.initState();
    _fields = List<CustomField>.from(widget.fields);
  }

  @override
  void didUpdateWidget(CustomFieldsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fields != oldWidget.fields) {
      _fields = List<CustomField>.from(widget.fields);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // inline 模式与默认模式共用主体，仅 label 布局不同
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          SizedBox(
            width: widget.inline ? widget.labelWidth : null,
            child: Text(
              widget.labelText!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ),
          const SizedBox(height: 8),
        ],
        JellyBox(
          radius: theme.radii.lg,
          strokeColor: theme.textSub.withValues(alpha: 0.45),
          child: Column(
            children: [
              if (_fields.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'app_noCustomFields'.tr,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                )
              else
                ..._buildFieldsList(),
              _buildAddButton(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFieldsList() {
    final theme = DSThemeBridge.resolve(context);
    final List<Widget> widgets = [];

    for (int i = 0; i < _fields.length; i++) {
      widgets.add(
        Pressable(
          onPressed: () => _editField(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _fields[i].key,
                          style: DsTypography.body.copyWith(color: theme.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_fields[i].value.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _fields[i].value,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildActionButton(
                  icon: DsIconKind.edit,
                  color: theme.primaryText,
                  background: theme.primary.mixWhite(0.88),
                  semanticLabel: '编辑',
                  onTap: () => _editField(i),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: DsIconKind.trash,
                  color: theme.onDanger,
                  background: theme.danger.mixWhite(0.88),
                  semanticLabel: '删除',
                  onTap: () => _deleteField(i),
                ),
              ],
            ),
          ),
        ),
      );

      // 在字段之间添加分隔线（除了最后一个）
      if (i < _fields.length - 1) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1, color: theme.stroke),
          ),
        );
      }
    }

    return widgets;
  }

  /// 小型果冻图标操作按钮
  Widget _buildActionButton({
    required DsIconKind icon,
    required Color color,
    required Color background,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: onTap,
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return JellyBox(
          width: 34,
          height: 34,
          radius: theme.radii.md,
          raised: !pressed,
          color: background,
          alignment: Alignment.center,
          child: DsIcon(icon, size: 17, color: color),
        );
      },
    );
  }

  Widget _buildAddButton() {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: _addField,
      semanticLabel: widget.addButtonText ?? 'app_addField'.tr,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DsIcon(DsIconKind.plus, size: 18, color: theme.primary),
            const SizedBox(width: 8),
            Text(
              widget.addButtonText ?? 'app_addField'.tr,
              style: DsTypography.caption.copyWith(color: theme.primary),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加/编辑共用的键值输入对话框
  Future<bool?> _showFieldDialog({
    required String title,
    required TextEditingController keyController,
    required TextEditingController valueController,
  }) {
    return showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (dialogContext) {
        final theme = DSThemeBridge.resolve(dialogContext);
        return DSDialog(
          title: title,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DSInput(
                controller: keyController,
                label: widget.fieldNameLabel ?? 'app_fieldName'.tr,
                hint: widget.fieldNameHint ?? 'app_fieldNameHint'.tr,
              ),
              SizedBox(height: theme.spacing.md),
              DSInput(
                controller: valueController,
                label: widget.fieldValueLabel ?? 'app_fieldValue'.tr,
                hint: widget.fieldValueHint ?? 'app_fieldValueHint'.tr,
                maxLines: 2,
              ),
            ],
          ),
          cancelText: 'app_cancel'.tr,
          confirmText: 'app_ok'.tr,
          onConfirm: () {
            if (keyController.text.isNotEmpty &&
                valueController.text.isNotEmpty) {
              Navigator.of(dialogContext).pop(true);
            } else {
              toastService.showToast('app_fieldNameAndValueRequired'.tr);
            }
          },
        );
      },
    );
  }

  void _addField() async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();

    final bool? confirmed = await _showFieldDialog(
      title: widget.addDialogTitle ?? 'app_addCustomField'.tr,
      keyController: keyController,
      valueController: valueController,
    );

    if (confirmed == true) {
      setState(() {
        _fields.add(
          CustomField(key: keyController.text, value: valueController.text),
        );
        widget.onFieldsChanged(_fields);
      });
    }
    keyController.dispose();
    valueController.dispose();
  }

  void _editField(int index) async {
    final field = _fields[index];
    final keyController = TextEditingController(text: field.key);
    final valueController = TextEditingController(text: field.value);

    final bool? confirmed = await _showFieldDialog(
      title: widget.editDialogTitle ?? 'app_editCustomField'.tr,
      keyController: keyController,
      valueController: valueController,
    );

    if (confirmed == true) {
      setState(() {
        _fields[index] = CustomField(
          key: keyController.text,
          value: valueController.text,
        );
        widget.onFieldsChanged(_fields);
      });
    }
    keyController.dispose();
    valueController.dispose();
  }

  void _deleteField(int index) {
    showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
                title: widget.deleteConfirmTitle ?? 'app_confirmDelete'.tr,
                message:
                    widget.deleteConfirmContent ??
                    'app_confirmDeleteField'.tr,
                cancelText: 'app_cancel'.tr,
                confirmText: 'app_delete'.tr,
                confirmVariant: DSButtonVariant.destructive,
              ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _fields.removeAt(index);
          widget.onFieldsChanged(_fields);
        });
      }
    });
  }
}
