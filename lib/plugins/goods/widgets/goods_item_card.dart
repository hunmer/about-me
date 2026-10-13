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

  /// 图片真实宽高比（null表示未探测到，瀑布流退回固定高度）
  double? _imageAspect;

  /// 图片宽高比内存缓存（key: 图片路径/URL）
  static final Map<String, double> _aspectCache = {};

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
          if (url != null) {
            _probeImageAspect(url);
          }
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

  /// 探测图片真实宽高比（经ImageCache，不额外解码），结果内存缓存
  Future<void> _probeImageAspect(String url) async {
    final cached = _aspectCache[url];
    if (cached != null) {
      if (mounted && _imageAspect != cached) {
        setState(() => _imageAspect = cached);
      }
      return;
    }

    final ImageProvider provider =
        url.startsWith('http://') || url.startsWith('https://')
            ? NetworkImage(url)
            : FileImage(File(url));
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        final width = info.image.width;
        final height = info.image.height;
        final aspect = (width > 0 && height > 0) ? width / height : null;
        if (aspect != null) {
          _aspectCache[url] = aspect;
        }
        if (mounted && _imageAspect != aspect) {
          setState(() {
            _imageAspect = aspect;
          });
        }
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
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

    // 瀑布流错落（兜底）：未探测到图片宽高比时按物品ID确定性变化（150-220）
    final imageHeight = 150.0 + (widget.item.id.hashCode.abs() % 8) * 10.0;

    // 副标题：优先仓库名，其次首个标签
    final subtitle =
        (widget.warehouseTitle != null && widget.warehouseTitle!.isNotEmpty)
        ? widget.warehouseTitle!
        : (widget.item.tags.isNotEmpty ? widget.item.tags.first : '');

    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: _showMenu,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片区（优先按真实宽高比错落，形成瀑布流）
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildImageSection(imageHeight),
                    ),
                    // 子物品数量角标
                    if (widget.item.subItems.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: JellyBox(
                          width: 20,
                          height: 20,
                          color: Colors.black.withValues(alpha: 0.6),
                          radius: theme.radii.circle,
                          alignment: Alignment.center,
                          child: Text(
                            '${widget.item.subItems.length}',
                            style: DsTypography.caption.copyWith(
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

                // 标题
                Text(
                  widget.item.title,
                  style: DsTypography.heading.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // 空间名 + 价格
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '¥${(widget.item.totalPrice ?? 0).toStringAsFixed(0)}',
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w600,
                      ),
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

  /// 图片区域：探测到宽高比时用AspectRatio（clamp 0.7-1.4防极端比例），
  /// 否则退回固定高度兜底
  Widget _buildImageSection(double fallbackHeight) {
    final content =
        widget.item.imageUrl != null ? _buildImage() : _buildIcon();
    if (_imageAspect != null) {
      return AspectRatio(
        aspectRatio: _imageAspect!.clamp(0.7, 1.4),
        child: content,
      );
    }
    return SizedBox(
      height: fallbackHeight,
      width: double.infinity,
      child: content,
    );
  }

  Widget _buildIcon() {
    return Container(
      color: widget.item.iconColor ?? DSThemeBridge.resolve(context).surfaceAlt,
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
