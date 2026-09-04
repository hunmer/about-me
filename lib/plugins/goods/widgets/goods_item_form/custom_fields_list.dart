import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/custom_field.dart';
import 'package:aboutme/core/services/toast_service.dart';

class CustomFieldsList extends StatefulWidget {
  final List<CustomField> fields;
  final Function(List<CustomField>) onFieldsChanged;

  const CustomFieldsList({
    super.key,
    required this.fields,
    required this.onFieldsChanged,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CustomFieldsListState createState() => _CustomFieldsListState();
}

class _CustomFieldsListState extends State<CustomFieldsList> {
  late List<CustomField> _fields;

  @override
  void initState() {
    super.initState();
    _fields = List<CustomField>.from(widget.fields);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DSThemeBridge(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'goods_customFields'.tr,
                style: DsTypography.heading.copyWith(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DSButton(
                label: 'goods_addField'.tr,
                variant: DSButtonVariant.ghost,
                icon: DsIconKind.plus,
                size: DSButtonSize.sm,
                onPressed: _addNewField,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_fields.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'goods_noCustomFields'.tr,
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _fields.length,
              itemBuilder: (context, index) {
                final field = _fields[index];
                return JellyBox(
                  color: theme.surfaceAlt,
                  radius: theme.radii.lg,
                  raised: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.key,
                              style: DsTypography.body.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              field.value,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DSIconButton(
                        icon: DsIconKind.edit,
                        size: 36,
                        color: theme.primary.withValues(alpha: 0.12),
                        iconColor: theme.primary,
                        onPressed: () => _editField(index),
                      ),
                      const SizedBox(width: 4),
                      DSIconButton(
                        icon: DsIconKind.trash,
                        size: 36,
                        color: theme.danger.withValues(alpha: 0.12),
                        iconColor: theme.danger,
                        onPressed: () => _removeField(index),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 弹出字段编辑对话框（新增/编辑共用）
  Future<bool?> _showFieldDialog(
    String title,
    TextEditingController keyController,
    TextEditingController valueController,
  ) {
    return showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => JellyBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: DsTypography.title.copyWith(
                              color: DSThemeBridge.resolve(context).text,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DSInput(
                            controller: keyController,
                            label: 'goods_fieldName'.tr,
                            hint: 'goods_enterFieldName'.tr,
                          ),
                          const SizedBox(height: 16),
                          DSInput(
                            controller: valueController,
                            label: 'goods_fieldValue'.tr,
                            hint: 'goods_enterFieldValue'.tr,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: DSButton(
                                  label: 'goods_cancel'.tr,
                                  variant: DSButtonVariant.outline,
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DSButton(
                                  label: 'goods_confirm'.tr,
                                  onPressed: () {
                                    if (keyController.text.isNotEmpty &&
                                        valueController.text.isNotEmpty) {
                                      Navigator.of(context).pop(true);
                                    } else {
                                      toastService.showToast(
                                        'goods_fieldNameAndValueCannotBeEmpty'
                                            .tr,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
    );
  }

  void _addNewField() async {
    final TextEditingController keyController = TextEditingController();
    final TextEditingController valueController = TextEditingController();

    final bool? confirmed = await _showFieldDialog(
      'goods_addCustomField'.tr,
      keyController,
      valueController,
    );

    if (confirmed == true) {
      setState(() {
        _fields.add(
          CustomField(key: keyController.text, value: valueController.text),
        );
        widget.onFieldsChanged(_fields);
      });
    }
  }

  void _editField(int index) async {
    final field = _fields[index];
    final TextEditingController keyController = TextEditingController(
      text: field.key,
    );
    final TextEditingController valueController = TextEditingController(
      text: field.value,
    );

    final bool? confirmed = await _showFieldDialog(
      'goods_editCustomField'.tr,
      keyController,
      valueController,
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
  }

  void _removeField(int index) {
    showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'goods_confirmDelete'.tr,
                    message: 'goods_confirmDeleteCustomField'.tr,
                    cancelText: 'goods_cancel'.tr,
                    confirmText: 'goods_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
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
