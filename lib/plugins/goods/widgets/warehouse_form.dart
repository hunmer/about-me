import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/warehouse.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/core/services/toast_service.dart';

class WarehouseForm extends StatefulWidget {
  final Warehouse? warehouse;
  final Future<void> Function(Warehouse) onSave;
  final Future<void> Function()? onDelete;

  /// 是否在底部弹层中展示（无 Scaffold，紧凑头部 + 自适应高度）
  final bool inSheet;

  const WarehouseForm({
    super.key,
    this.warehouse,
    required this.onSave,
    this.onDelete,
    this.inSheet = false,
  });

  @override
  State<WarehouseForm> createState() => _WarehouseFormState();
}

class _WarehouseFormState extends State<WarehouseForm> {
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.warehouse != null;

    if (widget.inSheet) {
      // 底部弹层版：自适应高度（键盘避让由 smooth_sheets 处理）
      return DSThemeBridge(
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, isEdit),
              Flexible(child: _buildFormBody(isEdit)),
              SafeArea(top: false, child: const SizedBox(height: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: DSThemeBridge(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isEdit),
              Expanded(child: _buildFormBody(isEdit)),
            ],
          ),
        ),
      ),
    );
  }

  /// 头部：弹层内用关闭图标，全屏页用返回箭头
  Widget _buildHeader(BuildContext context, bool isEdit) {
    final theme = DSThemeBridge.resolve(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          DSIconButton(
            icon: widget.inSheet ? DsIconKind.close : DsIconKind.chevronLeft,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              isEdit
                  ? ('goods_editWarehouseTitle'.tr)
                  : ('goods_createWarehouse'.tr),
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(
                color: theme.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 44), // Balance the back button
        ],
      ),
    );
  }

  /// 表单主体（滚动区域）
  Widget _buildFormBody(bool isEdit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          FormBuilderWrapper(
            config: FormConfig(
              fields: [
                // 图标和颜色选择器
                FormFieldConfig(
                  name: 'iconAvatar',
                  type: FormFieldType.iconAvatarRow,
                  labelText: '选择图标和颜色',
                  initialValue: {
                    'icon': widget.warehouse?.icon ?? Icons.inventory_2,
                    'iconColor': widget.warehouse?.iconColor ?? Colors.blue,
                    'avatarUrl': widget.warehouse?.imageUrl,
                  },
                  extra: {'avatarSaveDirectory': 'goods/warehouse_avatars'},
                ),
                // 标题字段
                FormFieldConfig(
                  name: 'title',
                  type: FormFieldType.text,
                  labelText: 'goods_warehouseName'.tr,
                  hintText: 'goods_warehouseNameHint'.tr,
                  initialValue: widget.warehouse?.title ?? '',
                  required: true,
                  validationMessage: 'goods_warehouseName'.tr,
                ),
              ],
              submitButtonText: isEdit ? 'goods_save'.tr : 'goods_confirm'.tr,
              showResetButton: false,
              onSubmit: (values) => _handleSubmit(context, values),
              onValidationFailed: (errors) {
                toastService.showToast(errors.values.join(', '));
              },
              crossAxisAlignment: CrossAxisAlignment.center,
              fieldSpacing: 16,
            ),
            buttonBuilder: (context, onSubmit, onReset) {
              return Column(
                children: [
                  const SizedBox(height: 24),
                  DSButton(
                    label: isEdit ? ('goods_save'.tr) : ('goods_confirm'.tr),
                    onPressed: onSubmit,
                    expand: true,
                    size: DSButtonSize.lg,
                  ),
                  if (isEdit && widget.onDelete != null) ...[
                    const SizedBox(height: 16),
                    DSButton(
                      label: 'goods_deleteWarehouse'.tr,
                      variant: DSButtonVariant.destructive,
                      icon: DsIconKind.trash,
                      onPressed: () => _handleDelete(context),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleSubmit(BuildContext context, Map<String, dynamic> values) async {
    final title = values['title'] as String? ?? '';
    if (title.isEmpty) {
      toastService.showToast('goods_warehouseName'.tr);
      return;
    }

    final iconAvatar = values['iconAvatar'] as Map<String, dynamic>? ?? {};
    final icon = iconAvatar['icon'] as IconData? ?? Icons.inventory_2;
    final color = iconAvatar['iconColor'] as Color? ?? Colors.blue;
    final imageUrl = iconAvatar['avatarUrl'] as String?;

    final warehouseData = Warehouse(
      id: widget.warehouse?.id ?? const Uuid().v4(),
      title: title,
      icon: icon,
      iconColor: color,
      imageUrl: imageUrl,
    );

    await widget.onSave(warehouseData);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleDelete(BuildContext context) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'goods_confirmDelete'.tr,
            message: 'goods_confirmDeleteWarehouseMessage'.tr.replaceFirst(
              '%s',
              widget.warehouse!.title,
            ),
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
