/// 商品选择器公共小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 单商品卡（图片整幅 + rough 墨线框，或纸底面板）/ 商品列表
/// （图标徽章 + 价格/库存状态）。
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 商品数据模型
class ProductData {
  final String id;
  final String name;
  final String description;
  final int price;
  final int stock;
  final String? image;

  ProductData({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.image,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    return ProductData(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'image': image,
    };
  }
}

/// 商品选择器小组件
class StoreProductSelectorCardWidget extends StatefulWidget {
  /// 商品列表
  final List<ProductData> products;

  /// 小组件尺寸
  final HomeWidgetSize size;

  const StoreProductSelectorCardWidget({
    super.key,
    required this.products,
    required this.size,
  });

  /// 从 props 创建实例（用于公共小组件系统）
  factory StoreProductSelectorCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final productsList = (props['products'] as List<dynamic>?)
            ?.map((e) => ProductData.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return StoreProductSelectorCardWidget(
      products: productsList,
      size: size,
    );
  }

  @override
  State<StoreProductSelectorCardWidget> createState() =>
      _StoreProductSelectorCardWidgetState();
}

class _StoreProductSelectorCardWidgetState
    extends State<StoreProductSelectorCardWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final products = widget.products;

    if (products.isEmpty) {
      return _buildEmptyWidget(context, theme);
    }

    // 单个商品显示详情，多个商品显示列表
    if (products.length == 1) {
      return _buildSingleProduct(context, theme, products.first);
    } else {
      return _buildProductList(context, theme, products);
    }
  }

  /// 构建单个商品布局
  Widget _buildSingleProduct(
    BuildContext context,
    AppThemeData theme,
    ProductData product,
  ) {
    return FutureBuilder<String?>(
      future: _getImagePath(product.image),
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
                                color: Colors.black.withValues(alpha: 0.2),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _buildSingleProductContent(
                                  theme,
                                  product,
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
                        child: _buildSingleProductContent(
                          theme,
                          product,
                          hasImage: false,
                        ),
                      ),
          ),
        );
      },
    );
  }

  /// 单个商品内容
  Widget _buildSingleProductContent(
    AppThemeData theme,
    ProductData product, {
    required bool hasImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 商品名称
        Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: hasImage ? Colors.white : theme.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // 商品描述
        if (product.description.isNotEmpty) ...[
          Text(
            product.description,
            style: TextStyle(
              fontSize: 12,
              color: hasImage ? Colors.white70 : theme.textSub,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        // 底部信息栏 - 价格和库存
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
              '${product.price} ${'store_points'.tr}',
              style: TextStyle(
                color: theme.warning,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            // 库存状态
            Text(
              product.stock > 0
                  ? '${'store_stockLabel'.tr}: ${product.stock}'
                  : 'store_outOfStock'.tr,
              style: TextStyle(
                color:
                    hasImage
                        ? (product.stock > 0 ? Colors.white70 : Colors.white60)
                        : (product.stock > 0 ? theme.success : theme.textSub),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建商品列表布局
  Widget _buildProductList(
    BuildContext context,
    AppThemeData theme,
    List<ProductData> products,
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
                    icon: Icons.shopping_bag,
                    color: theme.primary,
                    size: 20,
                    drawConfig: theme.wired.drawConfig,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '商品列表',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${products.length}个商品',
                    style: TextStyle(fontSize: 12, color: theme.textSub),
                  ),
                ],
              ),
            ),
            // 商品列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildProductListItem(
                    context,
                    theme,
                    products[index],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建商品列表项
  Widget _buildProductListItem(
    BuildContext context,
    AppThemeData theme,
    ProductData product,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 商品图标：墨线徽章
          Container(
            width: 48,
            height: 48,
            decoration: dsSketchDecoration(
              theme: theme,
              radius: BorderRadius.circular(8),
              fillColor: theme.surfaceAlt,
            ),
            child: WiredIcon(
              icon: Icons.shopping_bag,
              color: theme.primary,
              size: 24,
              drawConfig: theme.wired.drawConfig,
            ),
          ),
          const SizedBox(width: 12),
          // 商品信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: theme.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      '${product.price} ${'store_points'.tr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.warning,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      product.stock > 0
                          ? '${'store_stockLabel'.tr}: ${product.stock}'
                          : 'store_outOfStock'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: product.stock > 0 ? theme.success : theme.textSub,
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
                icon: Icons.shopping_bag,
                size: 48,
                color: theme.textSub,
                drawConfig: theme.wired.drawConfig,
              ),
              const SizedBox(height: 8),
              Text(
                '暂无商品',
                style: TextStyle(fontSize: 14, color: theme.textSub),
              ),
            ],
          ),
        ),
      ),
    );
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
