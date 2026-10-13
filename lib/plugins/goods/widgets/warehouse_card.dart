import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/warehouse.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/plugins/goods/widgets/warehouse_action_sheet.dart';

class WarehouseCard extends StatelessWidget {
  final Warehouse warehouse;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WarehouseCard({
    super.key,
    required this.warehouse,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () {
            if (onEdit != null || onDelete != null) {
              WarehouseActionSheet.show(
                context: context,
                onEdit: onEdit ?? () {},
                onDelete: onDelete ?? () {},
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCoverImage(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          warehouse.title,
                          style: DsTypography.heading.copyWith(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              warehouse.icon,
                              size: 18,
                              color: warehouse.iconColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${warehouse.items.length} 件物品',
                              style: DsTypography.body.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '总价值',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: dsSketchDecoration(
                                theme: theme,
                                fillColor: theme.primary,
                                radius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '¥${_formatCurrency(_calculateTotalValue())}',
                                style: DsTypography.caption.copyWith(
                                  color: theme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (warehouse.imageUrl == null || warehouse.imageUrl!.isEmpty) {
      return _buildDefaultCover();
    }

    return AdaptiveImage(
      imagePath: warehouse.imageUrl,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      borderRadius: 8,
    );
  }

  Widget _buildDefaultCover() {
    // 手绘风格无渐变装饰：纯色实底（design.md §9.3）
    return Container(
      color: warehouse.iconColor.withAlpha(204), // 0.8 * 255 ≈ 204
      child: Center(
        child: Icon(
          warehouse.icon,
          size: 48,
          color: Colors.white.withAlpha(204), // 0.8 * 255 ≈ 204
        ),
      ),
    );
  }

  double _calculateTotalValue() {
    double total = 0;
    for (var item in warehouse.items) {
      if (item.purchasePrice != null) {
        total += item.purchasePrice!;
      }
      // 计算子物品的价值
      if (item.subItems.isNotEmpty) {
        for (var subItem in item.subItems) {
          if (subItem.purchasePrice != null) {
            total += subItem.purchasePrice!;
          }
        }
      }
    }
    return total;
  }

  String _formatCurrency(double value) {
    // 使用NumberFormat格式化货币，如果有intl包
    try {
      return NumberFormat('#,##0.00', 'zh_CN').format(value);
    } catch (e) {
      // 如果没有intl包或发生错误，使用简单格式化
      return value.toStringAsFixed(2);
    }
  }
}
