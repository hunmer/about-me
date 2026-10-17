import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

/// 我的物品卡片（手绘简约风，参考 goods_item_card）
class UserItemCard extends StatelessWidget {
  final UserItem item;

  /// 同类物品数量（图上右上角徽章）
  final int count;

  /// 点击卡片（如进入详情）；为 null 时回退为"使用确认"
  final VoidCallback? onTap;

  /// 使用物品（长按菜单触发）
  final VoidCallback? onUse;

  /// 删除物品（长按菜单触发）
  final VoidCallback? onDelete;

  /// 查看商品信息（长按菜单触发）
  final VoidCallback? onViewProduct;

  const UserItemCard({
    super.key,
    required this.item,
    this.count = 1,
    this.onTap,
    this.onUse,
    this.onDelete,
    this.onViewProduct,
  });

  bool get _expired => DateTime.now().isAfter(item.expireDate);

  int get _daysLeft => item.expireDate.difference(DateTime.now()).inDays;

  bool get _expiringSoon => !_expired && _daysLeft <= 7;

  Future<void> _confirmUse(BuildContext context) async {
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'store_confirmUse'.tr,
            message: 'store_confirmUseMessage'.trParams({
              'productName': item.productName,
            }),
            cancelText: 'app_cancel'.tr,
            confirmText: 'app_confirm'.tr,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ),
      ),
    );
    if (confirm == true) onUse?.call();
  }

  void _showMenu(BuildContext context) {
    SmoothBottomSheet.show(
      context: context,
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onUse != null && !_expired)
                _buildSheetAction(
                  context,
                  icon: DsIconKind.check,
                  label: 'store_use'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmUse(context);
                  },
                ),
              if (onViewProduct != null)
                _buildSheetAction(
                  context,
                  icon: DsIconKind.store,
                  label: 'store_viewProductInfo'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    onViewProduct!();
                  },
                ),
              if (onDelete != null)
                _buildSheetAction(
                  context,
                  icon: DsIconKind.trash,
                  label: 'store_deleteButton'.tr,
                  destructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    onDelete!();
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

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final statusColor = _expired
        ? theme.danger
        : _expiringSoon
        ? theme.warning
        : theme.success;
    final statusLabel = _expired
        ? 'store_expired'.tr
        : _expiringSoon
        ? 'store_expiringSoon'.tr
        : 'store_daysLeft'.trParams({'days': '$_daysLeft'});

    final hasMenuActions =
        (onUse != null && !_expired) ||
        onViewProduct != null ||
        onDelete != null;

    // 瀑布流错落：按物品ID确定性变化（150-220）
    final imageHeight = 150.0 + (item.id.hashCode.abs() % 8) * 10.0;

    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ??
              ((onUse != null && !_expired)
                  ? () => _confirmUse(context)
                  : null),
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
                    // 左上：过期状态徽章
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
                    // 右上：同类物品数量徽章
                    if (count > 1)
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
                            '$count',
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
                  item.productName.isEmpty
                      ? 'store_productRemoved'.tr
                      : item.productName,
                  style: DsTypography.heading.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 到期日期 + 剩余次数
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'store_validUntilDate'.trParams({
                          'date': _formatDate(item.expireDate),
                        }),
                        style: DsTypography.caption.copyWith(
                          color: statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'store_remainingTimes'.trParams({
                        'count': '${item.remaining}',
                      }),
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

  /// 图片区：网络图/资源图（含 SVG），无图/加载失败回退占位图标
  Widget _buildImageSection(BuildContext context, double height) {
    final theme = DSThemeBridge.resolve(context);
    Widget placeholder() => Container(
      color: theme.surfaceAlt,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: DsIcon(DsIconKind.gift, size: 32, color: theme.textSub),
    );

    final imageUrl = item.productImage;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AdaptiveImage(
        imagePath: imageUrl.isEmpty ? null : imageUrl,
        fit: BoxFit.cover,
        errorImage: placeholder(),
        defaultImage: placeholder(),
      ),
    );
  }
}
