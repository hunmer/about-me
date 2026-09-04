import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';

class GoodsItemSelectorDialog extends StatefulWidget {
  final String? excludeItemId; // 要排除的物品ID（避免选择自己或已选择的子物品）
  final List<String>? excludeItemIds; // 要排除的物品ID列表
  final String? defaultCategory; // 默认选择的分类

  const GoodsItemSelectorDialog({
    super.key,
    this.excludeItemId,
    this.excludeItemIds,
    this.defaultCategory,
  });

  @override
  State<GoodsItemSelectorDialog> createState() =>
      _GoodsItemSelectorDialogState();
}

class _GoodsItemSelectorDialogState extends State<GoodsItemSelectorDialog> {
  String _searchQuery = '';
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  List<String> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.defaultCategory;
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 加载所有可用的分类（从物品的tags中提取）
  void _loadCategories() {
    final Set<String> categories = {};

    // 从所有物品的标签中收集分类
    for (final warehouse in GoodsPlugin.instance.warehouses) {
      for (final item in warehouse.items) {
        categories.addAll(item.tags);

        // 递归获取子物品的标签
        _collectTagsFromSubItems(item, categories);
      }
    }

    setState(() {
      _availableCategories = categories.toList()..sort();
    });
  }

  // 递归收集子物品的标签
  void _collectTagsFromSubItems(GoodsItem item, Set<String> categories) {
    for (final subItem in item.subItems) {
      categories.addAll(subItem.tags);
      _collectTagsFromSubItems(subItem, categories);
    }
  }

  // 获取可选择的物品列表
  List<GoodsItem> _getSelectableItems() {
    final allItems =
        GoodsPlugin.instance.warehouses
            .expand((warehouse) => warehouse.items)
            .where((item) {
              // 排除指定的物品
              if (widget.excludeItemId != null &&
                  item.id == widget.excludeItemId) {
                return false;
              }
              if (widget.excludeItemIds != null &&
                  widget.excludeItemIds!.contains(item.id)) {
                return false;
              }

              // 分类过滤
              if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
                if (!item.tags.contains(_selectedCategory)) {
                  return false;
                }
              }

              // 搜索过滤
              if (_searchQuery.isNotEmpty) {
                final searchLower = _searchQuery.toLowerCase();
                final titleLower = item.title.toLowerCase();
                return titleLower.contains(searchLower);
              }

              return true;
            })
            .toList();

    return allItems;
  }

  // 递归添加子物品
  // ignore: unused_element
  void _addSubItemsRecursively(GoodsItem item, List<GoodsItem> result) {
    for (final subItem in item.subItems) {
      result.add(subItem);
      _addSubItemsRecursively(subItem, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final items = _getSelectableItems();

    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.lg),
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'goods_selectItem'.tr,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
              DSIconButton(
                icon: DsIconKind.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 分类选择器
          DSSelect<String>(
            items: [
              DSSelectItem(value: '', label: 'goods_allCategories'.tr),
              ..._availableCategories.map(
                (category) => DSSelectItem(value: category, label: category),
              ),
            ],
            value: _selectedCategory ?? '',
            hint: 'goods_filterByCategory'.tr,
            onChanged: (value) {
              setState(() {
                _selectedCategory =
                    (value == '' || value == null) ? null : value;
              });
            },
          ),
          const SizedBox(height: 12),
          DSInput(
            controller: _searchController,
            hint: 'goods_searchItems'.tr,
            prefix: DsIcon(DsIconKind.search, size: 18, color: theme.textSub),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemRow(context, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, GoodsItem item) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () => Navigator.of(context).pop(item),
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.md,
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 20, color: item.iconColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  item.title,
                  style: DsTypography.body.copyWith(color: theme.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.purchasePrice != null)
                Text(
                  'goods_price'.tr,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
            ],
          ),
        );
      },
    );
  }
}
