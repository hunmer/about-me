import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_selector_dialog.dart';

/// 物品子物品列表字段组件
///
/// 用于表单中显示和管理子物品列表
class GoodsSubItemsField extends StatelessWidget {
  /// 子物品列表
  final List<GoodsItem> subItems;

  /// 子物品变化回调
  final ValueChanged<List<GoodsItem>> onSubItemsChanged;

  /// 要排除的物品ID（避免选择自己或已选择的子物品）
  final String? excludeItemId;

  /// 是否启用
  final bool enabled;

  const GoodsSubItemsField({
    super.key,
    required this.subItems,
    required this.onSubItemsChanged,
    this.excludeItemId,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goods_subItemList'.tr,
          style: DsTypography.caption.copyWith(color: theme.textSub),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...subItems.map(
                (subItem) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 128,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 96,
                              width: double.infinity,
                              child: _buildSubItemImage(subItem),
                            ),
                            if (subItem.purchasePrice != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '¥${subItem.purchasePrice!.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            subItem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (enabled)
                InkWell(
                  onTap: () => _showAddSubItemDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 128,
                    height: 134,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.stroke,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DsIcon(
                          DsIconKind.plus,
                          size: 32,
                          color: theme.textSub,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'goods_add'.tr,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubItemImage(GoodsItem item) {
    if (item.imageUrl != null) {
      return FutureBuilder<String>(
        future: _getItemImageUrl(item),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final path = snapshot.data!;
            if (path.startsWith('http')) {
              return Image.network(path, fit: BoxFit.cover);
            } else {
              return Image.file(File(path), fit: BoxFit.cover);
            }
          }
          return Container(
            color: item.iconColor ?? Colors.grey[200],
            child: Icon(item.icon ?? Icons.inventory_2, color: Colors.white),
          );
        },
      );
    }
    return Container(
      color: item.iconColor ?? Colors.grey[200],
      child: Icon(item.icon ?? Icons.inventory_2, color: Colors.white),
    );
  }

  // 获取物品图片URL的工具方法
  Future<String> _getItemImageUrl(GoodsItem item) async {
    final thumbUrl = await item.getThumbUrl();
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      return thumbUrl;
    }

    final imageUrl = await item.getImageUrl();
    return imageUrl ?? '';
  }

  void _showAddSubItemDialog(BuildContext context) async {
    final excludeItemIds = subItems.map((e) => e.id).toList();

    final result = await showDSDialog<dynamic>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: GoodsItemSelectorDialog(
              excludeItemId: excludeItemId,
              excludeItemIds: excludeItemIds,
            ),
          ),
    );

    if (result != null) {
      if (result is GoodsItem) {
        onSubItemsChanged([...subItems, result]);
      } else if (result is List<GoodsItem>) {
        onSubItemsChanged([...subItems, ...result]);
      }
    }
  }
}
