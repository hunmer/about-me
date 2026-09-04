import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'dart:io' show File;
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/goods/dialogs/add_usage_record_dialog.dart';
import 'package:aboutme/plugins/goods/screens/goods_item_history_page.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class GoodsItemCard extends StatefulWidget {
  final GoodsItem item;
  final String? warehouseTitle;
  final String? warehouseId;
  final VoidCallback? onTap;

  const GoodsItemCard({
    super.key,
    required this.item,
    this.warehouseTitle,
    this.warehouseId,
    this.onTap,
  });

  @override
  State<GoodsItemCard> createState() => _GoodsItemCardState();
}

class _GoodsItemCardState extends State<GoodsItemCard> {
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _resolveImageUrl();
  }

  @override
  void didUpdateWidget(GoodsItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl ||
        oldWidget.item.thumbUrl != widget.item.thumbUrl) {
      _resolveImageUrl();
    }
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

  void _showMenu() {
    if (widget.warehouseId == null) return;

    SmoothBottomSheet.show(
      context: context,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.plus,
                        label: 'goods_addUsageRecord'.tr,
                        onTap: () async {
                          Navigator.pop(context); // Close menu
                          final result =
                              await showDSDialog<Map<String, dynamic>>(
                                context: context,
                                theme: DSThemeBridge.resolve(context),
                                builder:
                                    (context) => const DSThemeBridge(
                                      child: AddUsageRecordDialog(),
                                    ),
                              );
                          if (result != null) {
                            final updatedItem = widget.item.addUsageRecord(
                              result['date'],
                              note: result['note'],
                              duration: result['duration'],
                              location: result['location'],
                            );
                            await GoodsPlugin.instance.saveGoodsItem(
                              widget.warehouseId!,
                              updatedItem,
                            );
                          }
                        },
                      ),
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.clock,
                        label: 'goods_usageHistory'.tr,
                        onTap: () {
                          Navigator.pop(context); // Close menu
                          NavigationHelper.push(
                            context,
                            GoodsItemHistoryPage(
                              item: widget.item,
                              warehouseId: widget.warehouseId!,
                            ),
                          );
                        },
                      ),
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.trash,
                        label: 'goods_delete'.tr,
                        destructive: true,
                        onTap: () async {
                          Navigator.pop(context); // Close menu
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
                                          confirmVariant:
                                              DSButtonVariant.destructive,
                                          onCancel:
                                              () =>
                                                  Navigator.pop(context, false),
                                          onConfirm:
                                              () =>
                                                  Navigator.pop(context, true),
                                        ),
                                  ),
                                ),
                          );

                          if (confirm == true) {
                            await GoodsPlugin.instance.deleteGoodsItem(
                              widget.warehouseId!,
                              widget.item.id,
                            );
                          }
                        },
                      ),
                    ],
                  ),
            ),
          ),
    );
  }

  /// 底部操作行（自绘，随 DS 令牌着色）
  Widget _buildSheetAction(
    BuildContext context, {
    required DsIconKind icon,
    required String label,
    bool destructive = false,
    required VoidCallback onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final color = destructive ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: pressed ? theme.surfaceAlt : null,
          child: Row(
            children: [
              DsIcon(icon, size: 24, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.body.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // Calculate daily cost
    double? dailyCost;
    if (widget.item.totalPrice != null && widget.item.purchaseDate != null) {
      final days = DateTime.now().difference(widget.item.purchaseDate!).inDays;
      final effectiveDays = days < 1 ? 1 : days;
      dailyCost = widget.item.totalPrice! / effectiveDays;
    }

    // Usage stats
    final daysOwned =
        widget.item.purchaseDate != null
            ? DateTime.now().difference(widget.item.purchaseDate!).inDays
            : 0;
    final usageCount = widget.item.usageRecords.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.stroke.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: _showMenu,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                Stack(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            widget.item.imageUrl != null
                                ? _buildImage()
                                : _buildIcon(),
                      ),
                    ),
                    // Badge (using subItems count as a placeholder for quantity if any)
                    if (widget.item.subItems.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${widget.item.subItems.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  widget.item.title,
                  style: DsTypography.heading.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Daily Cost
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '¥',
                          style: DsTypography.caption.copyWith(
                            color: theme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'goods_dailyCost'.tr,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      dailyCost != null
                          ? '¥${dailyCost.toStringAsFixed(3)}/${'goods_day'.tr}'
                          : '-',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Category & Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            widget.item.icon ?? Icons.category_outlined,
                            size: 14,
                            color: theme.primary,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              widget.item.tags.isNotEmpty
                                  ? widget.item.tags.first
                                  : 'goods_noItems'.tr
                                      .replaceAll('没有物品', '未分类')
                                      .replaceAll(
                                        'No Items',
                                        'Uncategorized',
                                      ), // Fallback
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '¥${(widget.item.totalPrice ?? 0).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Divider
                Divider(height: 1, color: theme.stroke.withValues(alpha: 0.2)),

                const SizedBox(height: 8),

                // Usage Stats & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$daysOwned${'goods_days'.tr} / $usageCount${'goods_times'.tr}',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                        fontSize: 10,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'goods_inPlace'.tr,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      color: widget.item.iconColor ?? Colors.grey[200],
      width: double.infinity,
      height: double.infinity,
      child: Icon(
        widget.item.icon ?? Icons.inventory_2,
        size: 32,
        color: Colors.white,
      ),
    );
  }

  Widget _buildImage() {
    if (_resolvedImageUrl == null) {
      return _buildIcon();
    }

    final imageUrl = _resolvedImageUrl!;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // 网络图片
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('网络图片加载失败: $error');
          return _buildIcon();
        },
      );
    } else {
      // 本地图片
      try {
        final file = File(imageUrl);
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
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
}
