import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/widgets/swipe_action/swipe_action_wrapper.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';

class GoodsItemListTile extends StatefulWidget {
  final GoodsItem item;
  final String? warehouseTitle;
  final String? warehouseId;
  final VoidCallback? onTap;

  const GoodsItemListTile({
    super.key,
    required this.item,
    this.warehouseTitle,
    this.warehouseId,
    this.onTap,
  });

  @override
  State<GoodsItemListTile> createState() => _GoodsItemListTileState();
}

class _GoodsItemListTileState extends State<GoodsItemListTile> {
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _resolveImageUrl();
  }

  Future<void> _resolveImageUrl() async {
    if (widget.item.imageUrl != null) {
      try {
        // 优先使用缩略图进行预览
        final url =
            await widget.item.getThumbUrl() ?? await widget.item.getImageUrl();
        if (mounted) {
          setState(() {
            _resolvedImageUrl = url;
          });
        }
      } catch (e) {
        debugPrint('获取图片URL失败: $e');
        if (mounted) {
          setState(() {
            _resolvedImageUrl = null;
          });
        }
      }
    }
  }

  /// 删除物品
  Future<void> _deleteItem() async {
    if (widget.warehouseId == null) return;

    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'goods_confirmDelete'.tr,
                    message: 'goods_confirmDeleteItem'.tr,
                    cancelText: 'goods_cancel'.tr,
                    confirmText: 'goods_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
            ),
          ),
    );

    if (confirm == true) {
      await GoodsPlugin.instance.deleteGoodsItem(
        widget.warehouseId!,
        widget.item.id,
      );
      if (mounted) {
        Get.snackbar(
          'goods_delete'.tr,
          '${widget.item.title} 已被删除',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final listTile = Pressable(
      onPressed: widget.onTap,
      builder:
          (context, states) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color:
                states.contains(WidgetState.pressed) ? theme.surfaceAlt : null,
            child: Row(
              children: [
                _buildLeading(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: DsTypography.body.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildSubtitle(context),
                    ],
                  ),
                ),
                if (widget.item.purchasePrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '¥${widget.item.purchasePrice!.toStringAsFixed(2)}',
                    style: DsTypography.body.copyWith(color: theme.textSub),
                  ),
                ],
              ],
            ),
          ),
    );

    // 如果没有 warehouseId，返回普通的 ListTile
    if (widget.warehouseId == null) {
      return listTile;
    }

    // 有 warehouseId 时，包装 SwipeAction
    return SwipeActionWrapper(
      key: ValueKey(widget.item.id),
      leadingActions: [SwipeActionPresets.edit(onTap: widget.onTap ?? () {})],
      trailingActions: [SwipeActionPresets.delete(onTap: _deleteItem)],
      child: listTile,
    );
  }

  Widget _buildLeading() {
    if (widget.item.imageUrl != null && _resolvedImageUrl != null) {
      final imageUrl = _resolvedImageUrl!;
      return SizedBox(width: 48, height: 48, child: _buildImage(imageUrl));
    }
    return _buildIcon();
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 网络图片
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('网络图片加载失败: $error');
          return _buildIcon();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const DSThemeBridge(child: Center(child: DSLoadingDots()));
        },
      );
    } else {
      // 本地图片
      try {
        final file = File(imageUrl);
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('本地图片加载失败: $error\n路径: $imageUrl');
            return _buildIcon();
          },
        );
      } catch (e) {
        debugPrint('创建File对象失败: $e\n路径: $imageUrl');
        return _buildIcon();
      }
    }
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.item.iconColor ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(widget.item.icon ?? Icons.inventory_2, color: Colors.white),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final List<Widget> content = [];

    // Add tags
    if (widget.item.tags.isNotEmpty) {
      content.add(
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children:
              widget.item.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                );
              }).toList(),
        ),
      );
    }

    // Add warehouse info
    if (widget.warehouseTitle != null) {
      if (content.isNotEmpty) {
        content.add(const SizedBox(height: 4));
      }
      content.add(
        Row(
          children: [
            DsIcon(DsIconKind.store, size: 12, color: theme.textSub),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.warehouseTitle!,
                style: DsTypography.caption.copyWith(color: theme.textSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Add last used date
    if (widget.item.lastUsedDate != null) {
      if (content.isNotEmpty) {
        content.add(const SizedBox(height: 4));
      }
      content.add(
        Row(
          children: [
            DsIcon(DsIconKind.clock, size: 12, color: theme.textSub),
            const SizedBox(width: 4),
            Text(
              '最后使用: ${widget.item.lastUsedDate.toString().split(' ')[0]}',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }
}
