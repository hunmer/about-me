import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 商品卡片（手绘简约风，参考 goods_item_card）
class ProductCard extends StatelessWidget {
  final Product product;

  /// 兑换商品（点击卡片确认后触发）
  final VoidCallback? onExchange;

  /// 编辑商品（长按菜单触发）
  final VoidCallback? onLongPress;

  const ProductCard({
    super.key,
    required this.product,
    this.onExchange,
    this.onLongPress,
  });

  bool get _ended => DateTime.now().isAfter(product.exchangeEnd);

  bool get _notStarted => DateTime.now().isBefore(product.exchangeStart);

  Future<void> _confirmExchange(BuildContext context) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'store_redeemConfirmation'.tr,
            message: 'store_redeemConfirmMessage'.trParams({
              'name': product.name,
              'price': '${product.price}',
            }),
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_confirm'.tr,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
    if (confirm == true) onExchange?.call();
  }

  void _showMenu(BuildContext context) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onExchange != null)
                _buildSheetAction(
                  context,
                  icon: DsIconKind.gift,
                  label: 'store_redeem'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmExchange(context);
                  },
                ),
              if (onLongPress != null)
                _buildSheetAction(
                  context,
                  icon: DsIconKind.edit,
                  label: 'store_editProduct'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    onLongPress!();
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
    final soldOut = product.stock <= 0;
    final statusColor = _ended
        ? theme.danger
        : _notStarted
        ? theme.warning
        : soldOut
        ? theme.danger
        : theme.success;
    final statusLabel = _ended
        ? 'store_exchangeEnded'.tr
        : _notStarted
        ? 'store_notStarted'.tr
        : soldOut
        ? 'store_outOfStock'.tr
        : 'store_exchanging'.tr;

    final hasMenuActions = onExchange != null || onLongPress != null;

    // 瀑布流错落：按商品ID确定性变化（150-220）
    final imageHeight = 150.0 + (product.id.hashCode.abs() % 8) * 10.0;

    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExchange != null ? () => _confirmExchange(context) : null,
          onLongPress: hasMenuActions ? () => _showMenu(context) : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildImageSection(context, imageHeight),
                    ),
                    // 左上：兑换状态徽章
                    Positioned(
                      top: 6,
                      left: 6,
                      child: JellyBox(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        color: statusColor,
                        radius: theme.radii.circle,
                        child: Text(
                          statusLabel,
                          style: DsTypography.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // 右上：库存数量徽章
                    if (product.stock > 0)
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
                            '${product.stock}',
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
                  product.name,
                  style: DsTypography.heading.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 描述 + 价格
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.description,
                        style: DsTypography.caption.copyWith(
                          color: theme.textSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'store_pricePoints'.trParams({'price': '${product.price}'}),
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

  /// 图片区：网络图，无图/加载失败回退占位图标
  Widget _buildImageSection(BuildContext context, double height) {
    final theme = DSThemeBridge.resolve(context);
    Widget placeholder() => Container(
      color: theme.surfaceAlt,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: DsIcon(DsIconKind.cart, size: 32, color: theme.textSub),
    );

    final url = product.image;
    if (url == null || url.isEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: placeholder(),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      ),
    );
  }
}
