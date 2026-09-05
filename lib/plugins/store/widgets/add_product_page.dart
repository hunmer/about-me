import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/form_fields/form_builder_wrapper.dart';
import 'package:aboutme/widgets/form_fields/config.dart';
import 'package:aboutme/widgets/form_fields/types.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';

class AddProductPage extends StatefulWidget {
  final StoreController controller;
  final Product? product;

  const AddProductPage({super.key, required this.controller, this.product});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormBuilderWrapperState>();
  final TextEditingController _pointsRatioController = TextEditingController();
  final TextEditingController _targetPriceController = TextEditingController();
  FormBuilderWrapperState? _formWrapperState;

  // 获取积分比率配置
  double _getPointsRatio() {
    final ratio = widget.controller.plugin.settings['points_to_rmb_ratio'];
    if (ratio == null) {
      return 100.0; // 默认 100 积分 = 1 元
    }
    return ratio is double ? ratio : (ratio as int).toDouble();
  }

  // 保存积分比率配置
  Future<void> _savePointsRatio(double ratio) async {
    await widget.controller.plugin.updateSettings({
      'points_to_rmb_ratio': ratio,
    });
  }

  @override
  void initState() {
    super.initState();
    _pointsRatioController.text = _getPointsRatio().toString();
  }

  @override
  void dispose() {
    _pointsRatioController.dispose();
    _targetPriceController.dispose();
    super.dispose();
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_confirmArchiveTitle'.tr,
                    message: 'store_confirmArchiveMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'store_archiveButton'.tr,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true && widget.product != null) {
      await widget.controller.archiveProduct(widget.product!);
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_confirmDeleteTitle'.tr,
                    message: 'store_confirmDeleteMessage'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'store_deleteButton'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      widget.controller.products.removeWhere((p) => p.id == widget.product!.id);
      await widget.controller.saveProducts();
      await widget.controller.saveToStorage();
      widget.controller.notifyUpdate();
      Navigator.pop(context);
    }
  }

  Future<void> _submit(Map<String, dynamic> values) async {
    final imageValue = values['image'];
    final imageUrl =
        imageValue is Map
            ? (imageValue['url'] as String?) ?? ''
            : (imageValue as String? ?? '');
    final priceValue = values['price'];
    final stockValue = values['stock'];

    final product =
        widget.product != null
            ? Product(
              id: widget.product!.id,
              name: values['name'] as String,
              description: values['description'] as String? ?? '',
              image: imageUrl.isEmpty ? widget.product!.image : imageUrl,
              stock: int.tryParse(stockValue?.toString() ?? '0') ?? 0,
              price: int.tryParse(priceValue?.toString() ?? '0') ?? 0,
              exchangeStart: widget.product!.exchangeStart,
              exchangeEnd: widget.product!.exchangeEnd,
              useDuration: widget.product!.useDuration,
            )
            : Product(
              id: const Uuid().v4(),
              name: values['name'] as String,
              description: values['description'] as String? ?? '',
              image: imageUrl,
              stock: int.tryParse(stockValue?.toString() ?? '0') ?? 0,
              price: int.tryParse(priceValue?.toString() ?? '0') ?? 0,
              exchangeStart: DateTime.now(),
              exchangeEnd: DateTime.now().add(const Duration(days: 30)),
              useDuration: 30,
            );

    if (widget.product != null) {
      widget.controller.products.removeWhere((p) => p.id == product.id);
    }
    widget.controller.addProduct(product);
    await widget.controller.saveProducts();
    Navigator.pop(context);
  }

  /// 显示积分计算器弹窗
  void _showPointsCalculator() {
    final double ratio = _getPointsRatio();
    _pointsRatioController.text = ratio.toString();
    _targetPriceController.clear();

    showDSDialog(
      context: context,
      barrierDismissible: true,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '积分计算器',
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      // 积分与人民币比率
                      DSInput(
                        controller: _pointsRatioController,
                        label: '积分 : 人民币 比率',
                        hint: '例如: 100 表示 100积分=1元',
                        prefix: DsIcon(
                          DsIconKind.hash,
                          size: 18,
                          color: theme.textSub,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      SizedBox(height: theme.spacing.md),
                      // 目标商品价格
                      DSInput(
                        controller: _targetPriceController,
                        label: '目标商品价格 (元)',
                        hint: '输入商品价格',
                        prefix: DsIcon(
                          DsIconKind.piggy,
                          size: 18,
                          color: theme.textSub,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      SizedBox(height: theme.spacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DSButton(
                              label: 'app_cancel'.tr,
                              variant: DSButtonVariant.outline,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          SizedBox(width: theme.spacing.md),
                          Expanded(
                            child: DSButton(
                              label: '计算并填入',
                              onPressed: () {
                                final ratio =
                                    double.tryParse(
                                      _pointsRatioController.text,
                                    ) ??
                                    100.0;
                                final targetPrice =
                                    double.tryParse(
                                      _targetPriceController.text,
                                    ) ??
                                    0.0;

                                if (targetPrice <= 0) {
                                  Toast.warning('请输入有效的价格');
                                  return;
                                }

                                // 计算积分 = 价格 * 比率
                                final points = (targetPrice * ratio).round();

                                // 保存比率配置
                                _savePointsRatio(ratio);

                                // 更新表单中的 price 字段
                                _formWrapperState?.patchValue({
                                  'price': points.toString(),
                                });

                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('store_addProductTitle'.tr),
        actions: [
          if (widget.product != null) ...[
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSIconButton(
                    icon: DsIconKind.download,
                    size: 38,
                    color: theme.surface,
                    iconColor: theme.text,
                    tooltip: 'store_archiveButton'.tr,
                    onPressed: _confirmArchive,
                  );
                },
              ),
            ),
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSIconButton(
                    icon: DsIconKind.trash,
                    size: 38,
                    color: theme.surface,
                    iconColor: theme.danger,
                    tooltip: 'store_deleteButton'.tr,
                    onPressed: _confirmDelete,
                  );
                },
              ),
            ),
          ],
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.check,
                  size: 38,
                  color: theme.primary,
                  tooltip: 'store_saveButton'.tr,
                  onPressed: () => _formWrapperState?.submitForm(),
                );
              },
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: FormBuilderWrapper(
                key: _formKey,
                config: FormConfig(
                  fields: [
                    // 图片选择
                    FormFieldConfig(
                      name: 'image',
                      type: FormFieldType.imagePicker,
                      initialValue: widget.product?.image,
                      extra: {
                        'previewWidth': double.infinity,
                        'previewHeight': 200.0,
                        'borderRadius': 12.0,
                        'showShadow': true,
                        'showLabel': false,
                      },
                    ),
                    // 商品名称
                    FormFieldConfig(
                      name: 'name',
                      type: FormFieldType.text,
                      labelText: 'store_productNameLabel'.tr,
                      initialValue: widget.product?.name ?? '',
                      required: true,
                      validationMessage: 'store_productNameRequired'.tr,
                    ),
                    // 价格（带计算器按钮）
                    FormFieldConfig(
                      name: 'price',
                      type: FormFieldType.number,
                      labelText: 'store_priceLabel'.tr,
                      initialValue: widget.product?.price.toString() ?? '0',
                      prefixIcon: Icons.stars,
                      suffixButtons: [
                        InputGroupButton(
                          icon: Icons.calculate,
                          tooltip: '积分计算器',
                          onPressed: _showPointsCalculator,
                        ),
                      ],
                    ),
                    // 库存
                    FormFieldConfig(
                      name: 'stock',
                      type: FormFieldType.number,
                      labelText: 'store_stockLabel'.tr,
                      initialValue: widget.product?.stock.toString() ?? '0',
                      prefixIcon: Icons.inventory_2,
                    ),
                    // 描述
                    FormFieldConfig(
                      name: 'description',
                      type: FormFieldType.textArea,
                      labelText: 'store_descriptionLabel'.tr,
                      initialValue: widget.product?.description ?? '',
                    ),
                  ],
                  onSubmit: _submit,
                  fieldSpacing: 16,
                  showSubmitButton: false,
                  showResetButton: false,
                ),
                onStateReady: (state) => _formWrapperState = state,
              ),
            ),
          );
        },
      ),
    );
  }
}
