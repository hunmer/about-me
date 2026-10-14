import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/plugins/store/widgets/user_item_card.dart';
import 'package:aboutme/plugins/store/widgets/user_item_detail_page.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// 商品物品列表页面 - 显示特定商品的所有已兑换物品
class ProductItemsPage extends StatefulWidget {
  final String productId;
  final String productName;
  final StoreController controller;
  final bool autoUse; // 是否自动弹出使用对话框
  final bool autoBuy; // 是否自动弹出购买对话框

  const ProductItemsPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.controller,
    this.autoUse = false,
    this.autoBuy = false,
  });

  @override
  State<ProductItemsPage> createState() => _ProductItemsPageState();
}

class _ProductItemsPageState extends State<ProductItemsPage> {
  int _statusIndex = 0; // 0: 全部, 1: 可使用, 2: 已过期
  bool _hasShownAutoUseDialog = false; // 防止重复弹出
  bool _hasShownAutoBuyDialog = false; // 防止重复弹出

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);

    // 自动购买逻辑
    if (widget.autoBuy && !_hasShownAutoBuyDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasShownAutoBuyDialog = true;
        _showBuyDialog();
      });
    }
    // 自动使用逻辑
    else if (widget.autoUse && !_hasShownAutoUseDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasShownAutoUseDialog = true;
        _showUseDialog();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// 弹出使用对话框（使用已有的 onUse 逻辑）
  void _showUseDialog() {
    final availableItems =
        _getFilteredItems()
            .where((item) => item.expireDate.isAfter(DateTime.now()))
            .toList();

    if (availableItems.isEmpty) {
      Toast.warning('暂无可使用的物品');
      return;
    }

    // 使用 UserItemCard 的 onUse 逻辑
    final itemToUse = availableItems.first;

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_useConfirmationTitle'.tr,
                    message: 'store_useConfirmationMessage'.tr.replaceFirst(
                      '%s',
                      itemToUse.productName,
                    ),
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                    onCancel: () => Navigator.pop(context),
                    onConfirm: () async {
                      Navigator.pop(context);
                      if (await widget.controller.useItem(itemToUse)) {
                        Toast.success('store_useSuccess'.tr);
                      } else {
                        Toast.error('store_itemExpired'.tr);
                      }
                      setState(() {});
                    },
                  ),
            ),
          ),
    );
  }

  /// 弹出购买对话框
  void _showBuyDialog() {
    // 获取商品信息
    final product = widget.controller.products.firstWhereOrNull(
      (p) => p.id == widget.productId,
    );

    if (product == null) {
      Toast.warning('store_productNotFound'.tr);
      return;
    }

    // 检查库存
    if (product.stock <= 0) {
      Toast.error('store_outOfStock'.tr);
      return;
    }

    // 检查积分是否足够
    if (widget.controller.userPoints < product.price) {
      Toast.error('store_insufficientPoints'.tr);
      return;
    }

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'store_redeemConfirmation'.tr,
                    message: 'store_redeemConfirmationMessage'.tr
                        .replaceFirst('%s', product.name)
                        .replaceFirst('%d', '${product.price}'),
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'app_ok'.tr,
                    onCancel: () => Navigator.pop(context),
                    onConfirm: () async {
                      Navigator.pop(context);
                      if (await widget.controller.exchangeProduct(product)) {
                        setState(() {});
                        Toast.success('store_redeemSuccess'.tr);
                      } else {
                        Toast.error('store_redeemFailed'.tr);
                      }
                    },
                  ),
            ),
          ),
    );
  }

  List<UserItem> _getFilteredItems() {
    final now = DateTime.now();
    return widget.controller.userItems.where((item) {
      // 首先按商品ID筛选
      if (item.productId != widget.productId) return false;

      // 然后按状态筛选
      switch (_statusIndex) {
        case 1: // 可使用
          return item.expireDate.isAfter(now);
        case 2: // 已过期
          return item.expireDate.isBefore(now);
        default: // 全部
          return true;
      }
    }).toList();
  }

  List<_ItemGroup> _groupItems(List<UserItem> items) {
    final groups = <String, _ItemGroup>{};

    for (final item in items) {
      final key = '${item.productId}_${item.purchasePrice}';
      if (groups.containsKey(key)) {
        groups[key]!.count++;
      } else {
        groups[key] = _ItemGroup(item: item, count: 1);
      }
    }

    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final items = _getFilteredItems();
    final groupedItems = _groupItems(items);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.productName),
            Text(
              '${'store_itemQuantity'.tr}: ${items.length}',
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
          ],
        ),
        actions: [
          // 查看商品详情
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.info,
                  size: 38,
                  color: theme.surface,
                  iconColor: theme.text,
                  tooltip: 'store_viewProductInfo'.tr,
                  onPressed: () {
                    final product = widget.controller.products.firstWhereOrNull(
                      (p) => p.id == widget.productId,
                    );
                    if (product != null) {
                      NavigationHelper.push(
                        context,
                        AddProductPage(
                          controller: widget.controller,
                          product: product,
                        ),
                      );
                    } else {
                      Toast.warning('store_productNotFound'.tr);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Column(
              children: [
                // 状态筛选栏
                _buildStatusFilter(theme),
                Container(
                  height: 1,
                  color: theme.stroke.withValues(alpha: 0.4),
                ),
                // 物品列表
                Expanded(
                  child:
                      groupedItems.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                DsIcon(
                                  DsIconKind.gift,
                                  size: 64,
                                  color: theme.textSub,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'store_noItems'.tr,
                                  style: DsTypography.body.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : _buildGrid(groupedItems, items),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(List<_ItemGroup> groupedItems, List<UserItem> items) {
    return MasonryGridView.count(
      padding: const EdgeInsets.all(8),
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 16,
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final group = groupedItems[index];
        return HandDrawnStickyItem(
          tiltKey: group.item.id,
          child: GestureDetector(
            onTap: () {
            final sameTypeItems =
                items
                    .where((item) => item.productId == group.item.productId)
                    .toList();

            NavigationHelper.push(
              context,
              UserItemDetailPage(
                controller: widget.controller,
                items: sameTypeItems,
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: UserItemCard(
            item: group.item,
            count: group.count,
            onUse: () async {
              final itemToUse = items.firstWhere(
                (item) => item.productId == group.item.productId,
              );

              if (await widget.controller.useItem(itemToUse)) {
                setState(() {});
                Toast.success('store_useSuccess'.tr);
              } else {
                Toast.error('store_itemExpired'.tr);
              }
            },
            onDelete: () async {
              final itemToDelete = items.firstWhere(
                (item) => item.productId == group.item.productId,
              );
              await widget.controller.deleteUserItem(itemToDelete);
              setState(() {});
              Toast.success('app_deleteSuccess'.tr);
            },
            onViewProduct: () {
              final product = widget.controller.products.firstWhereOrNull(
                (p) => p.id == group.item.productId,
              );
              if (product != null) {
                NavigationHelper.push(
                  context,
                  AddProductPage(
                    controller: widget.controller,
                    product: product,
                  ),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              } else {
                Toast.warning('store_productNotFound'.tr);
              }
            },
          ),
          ),
        );
      },
    );
  }

  Widget _buildStatusFilter(AppThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'store_itemStatus'.tr,
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip(0, 'store_all'.tr),
                  const SizedBox(width: 8),
                  _buildStatusChip(1, 'store_usable'.tr),
                  const SizedBox(width: 8),
                  _buildStatusChip(2, 'store_expired'.tr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int index, String label) {
    final isSelected = _statusIndex == index;
    return DSChip(
      label: label,
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusIndex = index;
          });
        }
      },
    );
  }
}

class _ItemGroup {
  final UserItem item;
  int count;

  _ItemGroup({required this.item, required this.count});
}
