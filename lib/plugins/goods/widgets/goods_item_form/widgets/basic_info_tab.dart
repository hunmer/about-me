import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/form_fields/index.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_form/controllers/form_controller.dart';
import 'package:aboutme/plugins/goods/widgets/goods_sub_items_field.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 物品基本信息标签页
///
/// 使用 FormBuilderWrapper 进行声明式表单管理
class BasicInfoTab extends StatelessWidget {
  final GoodsItemFormController controller;
  final Function() onStateChanged;

  const BasicInfoTab({
    super.key,
    required this.controller,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 分类选项
    final categories = [
      OptionItem(
        id: 'electronics',
        icon: Icons.devices,
        label: 'goods_categoryElectronics'.tr,
      ),
      OptionItem(
        id: 'household',
        icon: Icons.lightbulb,
        label: 'goods_categoryHousehold'.tr,
      ),
      OptionItem(
        id: 'clothing',
        icon: Icons.checkroom,
        label: 'goods_categoryClothing'.tr,
      ),
      OptionItem(
        id: 'books',
        icon: Icons.menu_book,
        label: 'goods_categoryBooks'.tr,
      ),
      OptionItem(
        id: 'other',
        icon: Icons.category,
        label: 'goods_categoryOther'.tr,
      ),
    ];

    // 状态选项
    final statuses = [
      OptionItem(
        id: 'normal',
        icon: Icons.check_circle_outline,
        label: 'goods_statusNormal'.tr,
      ),
      OptionItem(
        id: 'damaged',
        icon: Icons.broken_image,
        label: 'goods_statusDamaged'.tr,
      ),
      OptionItem(
        id: 'lent',
        icon: Icons.ios_share,
        label: 'goods_statusLent'.tr,
      ),
      OptionItem(id: 'sold', icon: Icons.sell, label: 'goods_statusSold'.tr),
    ];

    // 确定当前选中的分类
    String selectedCategory = 'other';
    for (var cat in categories) {
      if (controller.tags.contains(cat.id)) {
        selectedCategory = cat.id;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 图片上传部分 - 保持自定义 UI
        _buildImageUploadSection(context),
        const SizedBox(height: 24),

        // 物品名称
        FormFieldGroup(
          children: [
            TextInputField(
              controller: controller.nameController,
              labelText: 'goods_productName'.tr,
              hintText: 'goods_enterProductName'.tr,
              prefixIcon: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DsIcon(DsIconKind.tag, size: 20, color: theme.textSub);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'goods_pleaseEnterProductName'.tr;
                }
                return null;
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 购买日期和到期日期
        FormFieldGroup(
          children: [
            _buildDateCard(
              context,
              'goods_purchaseDate'.tr,
              Icons.calendar_today,
              controller.purchaseDate,
              (date) {
                if (date != null) {
                  controller.purchaseDate = date;
                  onStateChanged();
                }
              },
            ),
            _buildDateCard(
              context,
              'goods_expirationDate'.tr,
              Icons.event_busy,
              controller.expirationDate,
              (date) {
                controller.expirationDate = date;
                onStateChanged();
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 价格和数量
        Row(
          children: [
            Expanded(
              child: TextInputField(
                controller: controller.priceController,
                labelText: 'goods_price'.tr,
                hintText: '¥ 0.00',
                keyboardType: TextInputType.number,
                prefixIcon: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return DsIcon(
                      DsIconKind.piggy,
                      size: 20,
                      color: theme.textSub,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextInputField(
                controller: controller.stockController,
                labelText: 'goods_quantity'.tr,
                keyboardType: TextInputType.number,
                prefixIcon: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return DsIcon(
                      DsIconKind.hash,
                      size: 20,
                      color: theme.textSub,
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 分类选择器
        OptionSelectorField(
          options: categories,
          selectedId: selectedCategory,
          labelText: 'goods_category'.tr,
          onSelectionChanged: (optionId) {
            // 清除旧分类标签
            controller.tags.removeWhere(
              (t) => categories.any((c) => c.id == t),
            );
            // 添加新分类标签
            controller.tags.add(optionId);
            onStateChanged();
          },
        ),

        const SizedBox(height: 16),

        // 状态选择器
        OptionSelectorField(
          options: statuses,
          selectedId: controller.status,
          labelText: 'goods_usageStatus'.tr,
          useHorizontalScroll: false,
          gridColumns: 4,
          onSelectionChanged: (optionId) {
            controller.status = optionId;
            onStateChanged();
          },
        ),

        const SizedBox(height: 16),

        // 自定义字段
        CustomFieldsField(
          fields: controller.customFields,
          onFieldsChanged: (fields) {
            controller.customFields = fields;
            onStateChanged();
          },
          labelText: 'goods_customFields'.tr,
          addButtonText: 'goods_addField'.tr,
          addDialogTitle: 'goods_addCustomField'.tr,
          editDialogTitle: 'goods_editCustomField'.tr,
          fieldNameLabel: 'goods_fieldName'.tr,
          fieldNameHint: 'goods_enterFieldName'.tr,
          fieldValueLabel: 'goods_fieldValue'.tr,
          fieldValueHint: 'goods_enterFieldValue'.tr,
          deleteConfirmTitle: 'goods_confirmDelete'.tr,
          deleteConfirmContent: 'goods_confirmDeleteCustomField'.tr,
        ),

        const SizedBox(height: 16),

        // 子物品列表
        GoodsSubItemsField(
          subItems: controller.subItems,
          excludeItemId: controller.initialData?.id,
          onSubItemsChanged: (items) {
            controller.subItems.clear();
            controller.subItems.addAll(items);
            onStateChanged();
          },
        ),

        const SizedBox(height: 80), // Space for FAB/Bottom Bar
      ],
    );
  }

  Widget _buildImageUploadSection(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return InkWell(
      onTap: () => _pickAndCropImage(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: theme.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.stroke, style: BorderStyle.solid),
        ),
        child:
            controller.imagePath != null
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildImage(context),
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DsIcon(DsIconKind.camera, size: 48, color: theme.textSub),
                    const SizedBox(height: 8),
                    Text(
                      'goods_uploadItemImage'.tr,
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildDateCard(
    BuildContext context,
    String label,
    IconData icon,
    DateTime? date,
    Function(DateTime?) onDateSelected,
  ) {
    return DatePickerField(
      date: date,
      formattedDate: date != null ? DateFormat('yyyy-MM-dd').format(date) : '',
      placeholder: 'goods_selectDate'.tr,
      icon: icon,
      inline: true,
      labelText: label,
      onTap: () => _showDatePicker(context, date, onDateSelected),
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    DateTime? initialDate,
    Function(DateTime?) onDateSelected,
  ) async {
    final picked = await showDSDatePickerDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      initial: initialDate ?? DateTime.now(),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Widget _buildImage(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    Widget buildBrokenPlaceholder() =>
        DsIcon(DsIconKind.image, color: theme.textSub);

    // 缩略图文件可能未生成（如平台不支持压缩），不存在时回退原图
    Future<String?> resolveDisplayPath() async {
      final candidates = [controller.thumbPath, controller.imagePath];
      for (final candidatePath in candidates) {
        if (candidatePath == null || candidatePath.isEmpty) continue;
        if (candidatePath.startsWith('http://') ||
            candidatePath.startsWith('https://')) {
          return candidatePath;
        }
        final absolutePath = await ImageUtils.getAbsolutePath(candidatePath);
        if (absolutePath.isNotEmpty && await File(absolutePath).exists()) {
          return absolutePath;
        }
      }
      return null;
    }

    return FutureBuilder<String?>(
      future: resolveDisplayPath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final displayPath = snapshot.data!;
          if (displayPath.startsWith('http://') ||
              displayPath.startsWith('https://')) {
            return Image.network(
              displayPath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder:
                  (context, error, stackTrace) => buildBrokenPlaceholder(),
            );
          }
          return Image.file(
            File(displayPath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder:
                (context, error, stackTrace) => buildBrokenPlaceholder(),
          );
        }
        return buildBrokenPlaceholder();
      },
    );
  }

  Future<void> _pickAndCropImage(BuildContext context) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (context) => ImagePickerDialog(
              initialUrl: controller.imagePath,
              saveDirectory: 'goods/goods_images',
              enableCrop: true,
              cropAspectRatio: 1,
              enableCompression: true,
              compressionQuality: 85,
            ),
      );

      if (result != null && result['url'] != null) {
        final path = result['url'];
        final thumbPath = result['thumbUrl'] as String?;
        if (path.isNotEmpty) {
          if (controller.imagePath != null) {
            await ImageUtils.deleteImage(controller.imagePath);
          }
          if (controller.thumbPath != null) {
            await ImageUtils.deleteImage(controller.thumbPath);
          }

          controller.imagePath = path;
          controller.thumbPath = thumbPath;
          onStateChanged();
        }
      }
    } catch (e) {
      if (context.mounted) {
        toastService.showToast('goods_selectImageFailed'.tr);
      }
      debugPrint('选择图片时出错: $e');
    }
  }
}
