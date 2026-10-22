/// 用户物品选择器公共小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 单物品卡（图片整幅 + rough 墨线框，或纸底面板）/ 物品列表
/// （图标徽章 + 剩余次数徽章 + 过期状态）。
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 用户物品数据模型
class UserItemData {
  final String id;
  final String productName;
  final String? productImage;
  final int purchasePrice;
  final int remaining;
  final String expireDate;
  final int remainingDays;
  final bool isExpired;
  final bool isExpiringSoon;

  UserItemData({
    required this.id,
    required this.productName,
    this.productImage,
    required this.purchasePrice,
    required this.remaining,
    required this.expireDate,
    required this.remainingDays,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  factory UserItemData.fromJson(Map<String, dynamic> json) {
    return UserItemData(
      id: json['id'] as String,
      productName: json['productName'] as String,
      productImage: json['productImage'] as String?,
      purchasePrice: (json['purchasePrice'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      expireDate: json['expireDate'] as String,
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
      isExpired: json['isExpired'] as bool? ?? false,
      isExpiringSoon: json['isExpiringSoon'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'productImage': productImage,
      'purchasePrice': purchasePrice,
      'remaining': remaining,
      'expireDate': expireDate,
      'remainingDays': remainingDays,
      'isExpired': isExpired,
      'isExpiringSoon': isExpiringSoon,
    };
  }
}

/// 用户物品选择器小组件
class StoreUserItemSelectorCardWidget extends StatefulWidget {
  /// 物品列表
  final List<UserItemData> items;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const StoreUserItemSelectorCardWidget({
    super.key,
    required this.items,
    required this.size,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory StoreUserItemSelectorCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final itemsList = (props['items'] as List<dynamic>?)
            ?.map((e) => UserItemData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return StoreUserItemSelectorCardWidget(
      items: itemsList,
      size: size,
    );
  }

  @override
  State<StoreUserItemSelectorCardWidget> createState() =>
      _StoreUserItemSelectorCardWidgetState();
}

class _StoreUserItemSelectorCardWidgetState
    extends State<StoreUserItemSelectorCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final items = widget.items;

    if (items.isEmpty) {
      return _buildEmptyWidget(context, theme);
    }

    // 单个物品显示详情，多个物品显示列表
    if (items.length == 1) {
      return _buildSingleItem(context, theme, items.first);
    } else {
      return _buildItemList(context, theme, items);
    }
  }

  /// 构建单个物品布局
  Widget _buildSingleItem(
    BuildContext context,
    AppThemeData theme,
    UserItemData item,
  ) {
    return FutureBuilder<String?>(
      future: _getImagePath(item.productImage),
      builder: (context, imageSnapshot) {
        final hasImage =
            imageSnapshot.hasData &&
            imageSnapshot.data != null &&
            imageSnapshot.data!.isNotEmpty;
        final radius = BorderRadius.circular(16 * widget.size.scale);

        // 手绘纸卡：有图走整幅图片 + rough 墨线框，无图走纸底面板
        return WiredDraw(
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child:
                hasImage
                    ? ClipRRect(
                      borderRadius: radius,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image(
                              image: ImageUtils.createImageProvider(
                                imageSnapshot.data,
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          // 压暗蒙层（图片展示逻辑保留）
                          Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildSingleItemContent(
                                theme,
                                item,
                                hasImage: true,
                              ),
                            ),
                          ),
                          // rough 墨线框叠在图片之上
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: dsSketchDecoration(
                                  theme: theme,
                                  radius: radius,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : DsSketchPanel(
                      theme: theme,
                      radius: radius,
                      padding: const EdgeInsets.all(16),
                      child: _buildSingleItemContent(
                        theme,
                        item,
                        hasImage: false,
                      ),
                    ),
          ),
        );
      },
    );
  }

  /// 单个物品内容
  Widget _buildSingleItemContent(
    AppThemeData theme,
    UserItemData item, {
    required bool hasImage,
  }) {
    final expireColor = _getExpireColor(theme, item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 物品名称和剩余次数（在同一行）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.productName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: hasImage ? Colors.white : theme.text,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 剩余次数（标题右侧）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(8),
                fillColor:
                    hasImage ? Colors.white.withValues(alpha: 0.2) : null,
              ),
              child: Text(
                '${item.remaining} ${'store_times'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  color: hasImage ? Colors.white : theme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        // 底部区域：价格（左）和过期信息（右）
        Row(
          children: [
            // 价格信息
            Row(
              children: [
                WiredIcon(
                  icon: Icons.monetization_on,
                  size: 16,
                  color: theme.warning,
                  drawConfig: theme.wired.drawConfig,
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.purchasePrice} ${'store_points'.tr}',
                  style: TextStyle(fontSize: 12, color: theme.warning),
                ),
              ],
            ),
            const Spacer(),
            // 过期信息（右下角）
            Text(
              item.isExpired
                  ? 'store_itemExpired'.tr
                  : '${'store_expireIn'.tr} ${item.remainingDays} ${'store_days'.tr}',
              style: TextStyle(fontSize: 12, color: expireColor),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建物品列表布局
  Widget _buildItemList(
    BuildContext context,
    AppThemeData theme,
    List<UserItemData> items,
  ) {
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
                    '我的物品',
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
                  return _buildItemListItem(context, theme, items[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建物品列表项
  Widget _buildItemListItem(
    BuildContext context,
    AppThemeData theme,
    UserItemData item,
  ) {
    final expireColor = _getExpireColor(theme, item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 物品图标：墨线徽章
          Container(
            width: 48,
            height: 48,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(8),
              fillColor: theme.surfaceAlt,
            ),
            child: WiredIcon(
              icon: Icons.inventory_2,
              color: theme.primary,
              size: 24,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
          const SizedBox(width: 12),
          // 物品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: theme.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 剩余次数徽章
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(6),
                        fillColor: theme.surfaceAlt,
                      ),
                      child: Text(
                        '${item.remaining}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    WiredIcon(
                      icon: Icons.monetization_on,
                      size: 14,
                      color: theme.warning,
                      drawConfig: theme.wired.drawConfig,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.purchasePrice} ${'store_points'.tr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.warning,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.isExpired
                          ? 'store_itemExpired'.tr
                          : '${item.remainingDays} ${'store_days'.tr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: expireColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyWidget(BuildContext context, AppThemeData theme) {
    return WiredDraw(
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(16 * widget.size.scale),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WiredIcon(
                icon: Icons.inventory_2,
                size: 48,
                color: theme.textSub,
                drawConfig: theme.wired.drawConfig,
              ),
              const SizedBox(height: 8),
              Text(
                '暂无物品',
                style: TextStyle(fontSize: 14, color: theme.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取过期颜色
  Color _getExpireColor(AppThemeData theme, UserItemData item) {
    if (item.isExpired) {
      return theme.danger;
    } else if (item.isExpiringSoon) {
      return theme.warning;
    } else {
      return theme.success;
    }
  }

  /// 获取图片路径
  Future<String?> _getImagePath(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('/') || imagePath.startsWith('http')) {
      return imagePath;
    }
    return ImageUtils.getAbsolutePath(imagePath);
  }
}
