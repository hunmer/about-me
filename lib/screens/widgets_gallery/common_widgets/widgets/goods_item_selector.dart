/// 物品选择器公共小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 单物品卡（图片整幅 + rough 墨线框，或纸底面板）/ 物品列表
/// （数据色图标徽章 + 墨线箭头）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';

/// 物品选择器公共小组件
///
/// 支持通过 props 配置单个或多个物品
/// 支持点击导航到物品详情
class GoodsItemSelectorWidget extends StatefulWidget {
  /// 物品 ID 列表
  final List<String> itemIds;

  /// 小组件尺寸
  final HomeWidgetSize size;

  /// 自定义标题（可选）
  final String? title;

  /// 是否显示列表模式（默认为 false，显示网格模式）
  final bool showListMode;

  /// 仓库 ID（用于导航）
  final List<String>? warehouseIds;

  const GoodsItemSelectorWidget({
    super.key,
    required this.itemIds,
    required this.size,
    this.title,
    this.showListMode = false,
    this.warehouseIds,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory GoodsItemSelectorWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemIds =
        (props['itemIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final warehouseIds =
        (props['warehouseIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();
    final showListMode = props['showListMode'] as bool? ?? false;

    return GoodsItemSelectorWidget(
      itemIds: itemIds,
      size: size,
      title: props['title'] as String?,
      showListMode: showListMode,
      warehouseIds: warehouseIds,
    );
  }

  @override
  State<GoodsItemSelectorWidget> createState() =>
      _GoodsItemSelectorWidgetState();
}

class _GoodsItemSelectorWidgetState extends State<GoodsItemSelectorWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    // 获取插件
    final plugin = PluginManager.instance.getPlugin('goods') as GoodsPlugin?;
    if (plugin == null) {
      return _buildErrorWidget(context, '插件不可用');
    }

    // 获取物品数据
    final List<GoodsItemData> items = [];

    if (widget.itemIds.isNotEmpty) {
      // 模式1：指定了具体的物品ID
      for (var i = 0; i < widget.itemIds.length; i++) {
        final itemId = widget.itemIds[i];
        final findResult = plugin.findGoodsItemById(itemId);

        if (findResult != null) {
          items.add(
            GoodsItemData(
              item: findResult.item,
              warehouseId: findResult.warehouseId,
            ),
          );
        }
      }
    } else if (widget.warehouseIds != null && widget.warehouseIds!.isNotEmpty) {
      // 模式2：未指定物品ID，但有仓库ID，显示仓库中的所有物品
      for (final warehouseId in widget.warehouseIds!) {
        final warehouse = plugin.getWarehouse(warehouseId);
        if (warehouse != null) {
          // 递归获取仓库中的所有物品（包括子物品）
          _collectAllItems(warehouse.items, warehouse.id, items);
        }
      }
    }

    if (items.isEmpty) {
      return _buildErrorWidget(context, '未找到物品');
    }

    // 根据显示模式和数量选择布局
    if (widget.showListMode || items.length > 1) {
      return _buildListLayout(context, theme, items);
    } else {
      return _buildSingleItemLayout(context, theme, items.first);
    }
  }

  /// 递归收集所有物品（包括子物品）
  void _collectAllItems(
    List<GoodsItem> itemList,
    String warehouseId,
    List<GoodsItemData> result,
  ) {
    for (final item in itemList) {
      result.add(GoodsItemData(item: item, warehouseId: warehouseId));
      if (item.subItems.isNotEmpty) {
        _collectAllItems(item.subItems, warehouseId, result);
      }
    }
  }

  /// 构建单个物品布局
  Widget _buildSingleItemLayout(
    BuildContext context,
    AppThemeData theme,
    GoodsItemData itemData,
  ) {
    final item = itemData.item;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final isLarge = widget.size is LargeSize;
    final radius = BorderRadius.circular(16 * widget.size.scale);

    final content =
        isLarge
            ? _buildLargeItemContent(context, theme, item, hasImage)
            : _buildMediumItemContent(context, theme, item, hasImage);

    // 手绘纸卡：有图走整幅图片 + rough 墨线框，无图走纸底面板
    return WiredDraw(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap:
              () => _navigateToItemDetail(
                context,
                item.id,
                itemData.warehouseId,
                item.title,
              ),
          child:
              hasImage
                  ? _buildImageCard(theme, radius, item, content)
                  : DsSketchPanel(
                    theme: theme,
                    radius: radius,
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
        ),
      ),
    );
  }

  /// 图片卡：整幅图片 + 压暗蒙层（保证白字可读）+ rough 墨线框
  Widget _buildImageCard(
    AppThemeData theme,
    BorderRadius radius,
    GoodsItem item,
    Widget content,
  ) {
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image(
              image: ImageUtils.createImageProvider(item.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
          // 压暗蒙层（图片展示逻辑保留）
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          ),
          Positioned.fill(
            child: Padding(padding: const EdgeInsets.all(16), child: content),
          ),
          // rough 墨线框叠在图片之上
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: dsSketchDecoration(theme: theme, radius: radius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建大尺寸物品内容
  Widget _buildLargeItemContent(
    BuildContext context,
    AppThemeData theme,
    GoodsItem item,
    bool hasImage,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 物品图片或图标（居中）
        Center(
          child: _buildItemImageWidget(theme, item, hasImage: hasImage),
        ),
        const SizedBox(height: 16),
        // 标题（居中）
        Text(
          item.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: hasImage ? Colors.white : theme.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (item.purchasePrice != null) ...[
          const SizedBox(height: 8),
          // 价格（居中）
          Text(
            '¥${item.purchasePrice!.toStringAsFixed(2)}',
            style: TextStyle(
              color: hasImage ? Colors.white : theme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// 构建中等尺寸物品内容
  Widget _buildMediumItemContent(
    BuildContext context,
    AppThemeData theme,
    GoodsItem item,
    bool hasImage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 物品图片或图标
            _buildItemImageWidget(theme, item, hasImage: hasImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: hasImage ? Colors.white : theme.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.purchasePrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '¥${item.purchasePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: hasImage ? Colors.white : theme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建物品图片组件
  Widget _buildItemImageWidget(
    AppThemeData theme,
    GoodsItem item, {
    bool hasImage = false,
  }) {
    final effectiveColor = item.iconColor ?? theme.primary;
    final icon = item.icon ?? Icons.inventory_2;

    // 数据色图标徽章：实底 + 墨线描边
    return Container(
      width: 64,
      height: 64,
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(12),
        fillColor: effectiveColor,
      ),
      child: WiredIcon(
        icon: icon,
        size: 32,
        color: theme.onPrimary,
        drawConfig: theme.wired.drawConfig,
      ),
    );
  }

  /// 构建列表布局（多个物品）
  Widget _buildListLayout(
    BuildContext context,
    AppThemeData theme,
    List<GoodsItemData> items,
  ) {
    final title = widget.title ?? '物品列表';

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16 * widget.size.scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  WiredIcon(
                    icon: Icons.inventory_2,
                    color: theme.primary,
                    size: 20,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length}个物品',
                    style: TextStyle(fontSize: 12, color: theme.textSub),
                  ),
                ],
              ),
            ),
            // 物品列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final itemData = items[index];
                  return _buildListItem(context, theme, itemData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建列表项
  Widget _buildListItem(
    BuildContext context,
    AppThemeData theme,
    GoodsItemData itemData,
  ) {
    final item = itemData.item;

    return InkWell(
      onTap:
          () => _navigateToItemDetail(
            context,
            item.id,
            itemData.warehouseId,
            item.title,
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 图标：数据色徽章
            Container(
              width: 40,
              height: 40,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(8),
                fillColor: item.iconColor ?? theme.primary,
              ),
              child: WiredIcon(
                icon: item.icon ?? Icons.inventory_2,
                color: theme.onPrimary,
                size: 20,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
            const SizedBox(width: 12),
            // 标题和价格
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: theme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.purchasePrice != null)
                    Text(
                      '¥${item.purchasePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primary,
                      ),
                    ),
                ],
              ),
            ),
            DsIcon(DsIconKind.chevronRight, color: theme.textSub),
          ],
        ),
      ),
    );
  }

  /// 构建错误小组件
  Widget _buildErrorWidget(BuildContext context, String message) {
    final theme = AppTheme.of(context);
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WiredIcon(
                icon: Icons.error_outline,
                color: theme.danger,
                size: 24,
                drawConfig: theme.wired.drawConfig,
              ),
              const SizedBox(width: 8),
              Text(message, style: TextStyle(color: theme.danger)),
            ],
          ),
        ),
      ),
    );
  }

  /// 导航到物品详情页面
  void _navigateToItemDetail(
    BuildContext context,
    String itemId,
    String? warehouseId,
    String itemTitle,
  ) {
    if (warehouseId == null) {
      debugPrint('仓库ID为空');
      return;
    }

    NavigationHelper.pushNamed(
      context,
      '/goods/item_detail',
      arguments: {
        'itemId': itemId,
        'warehouseId': warehouseId,
        'itemTitle': itemTitle,
      },
    );
  }
}

/// 物品数据包装类
class GoodsItemData {
  final GoodsItem item;
  final String warehouseId;

  GoodsItemData({required this.item, required this.warehouseId});
}
