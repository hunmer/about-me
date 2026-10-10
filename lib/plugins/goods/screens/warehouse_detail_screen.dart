import 'package:get/get.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/models/warehouse.dart';
import 'package:aboutme/plugins/goods/widgets/warehouse_form.dart';
import 'package:aboutme/plugins/goods/models/goods_item.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_card.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_list_tile.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_form/goods_item_form.dart';
import 'package:aboutme/plugins/goods/screens/goods_item_detail_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class WarehouseDetailScreen extends StatefulWidget {
  final Warehouse warehouse;

  const WarehouseDetailScreen({super.key, required this.warehouse});

  @override
  State<WarehouseDetailScreen> createState() => _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends State<WarehouseDetailScreen> {
  bool _isGridView = true;
  late String _sortBy; // none, price, lastUsed
  late Warehouse _warehouse;

  @override
  void initState() {
    super.initState();
    _warehouse = widget.warehouse;
    // 从插件中获取该仓库的排序偏好
    _sortBy = GoodsPlugin.instance.getSortPreference(_warehouse.id);

    // 设置路由上下文
    _updateRouteContext();

    // 监听物品添加事件
    EventManager.instance.subscribe('goods_item_added', (args) {
      if (args is GoodsItemAddedEventArgs &&
          args.warehouseId == _warehouse.id) {
        _refreshWarehouse();
      }
    });

    // 监听物品删除事件
    EventManager.instance.subscribe('goods_item_deleted', (args) {
      if (args is GoodsItemDeletedEventArgs &&
          args.warehouseId == _warehouse.id) {
        _refreshWarehouse();
      }
    });
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前仓库信息
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: "/goods/warehouse_detail",
      title: '物品 - 仓库: ${_warehouse.title}',
      params: {'warehouseId': _warehouse.id, 'warehouseName': _warehouse.title},
    );
  }

  Future<void> _refreshWarehouse() async {
    final updatedWarehouse = GoodsPlugin.instance.getWarehouse(_warehouse.id);
    if (updatedWarehouse != null && mounted) {
      setState(() {
        _warehouse = updatedWarehouse;
      });
      // 更新路由上下文
      _updateRouteContext();
    }
  }

  void _showAddItemDialog() {
    GoodsItemForm.show(
      context: context,
      onSubmit: (GoodsItem item) async {
        await GoodsPlugin.instance.saveGoodsItem(_warehouse.id, item);
        await _refreshWarehouse();
      },
    );
  }

  void _showMoreOptions() {
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
                        icon: DsIconKind.edit,
                        label: 'goods_editWarehouseTitle'.tr,
                        onTap: () {
                          Navigator.pop(context);
                          // 实现仓库编辑功能
                          NavigationHelper.push(
                            context,
                            WarehouseForm(
                              warehouse: _warehouse,
                              onSave: (warehouse) async {
                                await GoodsPlugin.instance.saveWarehouse(
                                  warehouse,
                                );
                                if (context.mounted) {
                                  await _refreshWarehouse();
                                }
                              },
                              onDelete: () async {
                                await GoodsPlugin.instance.deleteWarehouse(
                                  _warehouse.id,
                                );
                                if (context.mounted) {
                                  // 连退两页：关闭表单页和详情页
                                  Navigator.pop(context); // 关闭表单
                                  Navigator.pop(context); // 关闭详情
                                }
                              },
                            ),
                          );
                        },
                      ),
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.trash,
                        label: 'goods_clearWarehouseTitle'.tr,
                        onTap: () async {
                          final confirm = await showDSDialog<bool>(
                            context: context,
                            theme: DSThemeBridge.resolve(context),
                            builder:
                                (context) => DSThemeBridge(
                                  child: Builder(
                                    builder:
                                        (context) => DSDialog(
                                          title:
                                              'goods_confirmClearWarehouse'.tr,
                                          message:
                                              'goods_confirmClearWarehouseMessage'
                                                  .tr,
                                          cancelText: 'app_cancel'.tr,
                                          confirmText: 'app_ok'.tr,
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

                          if (confirm == true && context.mounted) {
                            await GoodsPlugin.instance.clearWarehouse(
                              _warehouse.id,
                            );
                            Navigator.pop(context);
                            await _refreshWarehouse();
                          }
                        },
                      ),
                      _buildSheetAction(
                        context,
                        icon: DsIconKind.trash,
                        label: 'goods_deleteWarehouseTitle'.tr,
                        destructive: true,
                        onTap: () async {
                          final confirm = await showDSDialog<bool>(
                            context: context,
                            theme: DSThemeBridge.resolve(context),
                            builder:
                                (context) => DSThemeBridge(
                                  child: Builder(
                                    builder:
                                        (context) => DSDialog(
                                          title: 'goods_confirmDelete'.tr,
                                          message:
                                              'goods_confirmDeleteWarehouseMessage'
                                                  .trParams({
                                                    'name': _warehouse.title,
                                                  }),
                                          cancelText: 'app_cancel'.tr,
                                          confirmText: 'app_delete'.tr,
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

                          if (confirm == true && context.mounted) {
                            await GoodsPlugin.instance.deleteWarehouse(
                              _warehouse.id,
                            );
                            // 关闭底部菜单
                            Navigator.pop(context);
                            // 返回上一页
                            Navigator.pop(context);
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

  List<GoodsItem> _getSortedItems() {
    final items = List<GoodsItem>.from(_warehouse.items);
    switch (_sortBy) {
      case 'price':
        items.sort(
          (a, b) => (b.purchasePrice ?? 0).compareTo(a.purchasePrice ?? 0),
        );
        break;
      case 'lastUsed':
        items.sort(
          (a, b) => (b.lastUsedDate ?? DateTime(1970)).compareTo(
            a.lastUsedDate ?? DateTime(1970),
          ),
        );
        break;
    }
    return items;
  }

  void _showEditItemDialog(GoodsItem item) {
    GoodsItemForm.show(
      context: context,
      initialData: item,
      onSubmit: (item) async {
        await GoodsPlugin.instance.saveGoodsItem(_warehouse.id, item);
        await _refreshWarehouse();
      },
      onDelete: (item) async {
        await GoodsPlugin.instance.deleteGoodsItem(_warehouse.id, item.id);
        await _refreshWarehouse();
      },
    );
  }

  @override
  void dispose() {
    // 取消事件订阅
    EventManager.instance.unsubscribe('goods_item_added');
    EventManager.instance.unsubscribe('goods_item_deleted');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _getSortedItems();
    final theme = DSThemeBridge.resolve(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_warehouse.title),
            const SizedBox(width: 8),
            Text(
              '(${items.length})',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ),
        actions: [
          // 视图切换按钮(DS 按钮自带 DSThemeBridge 提供 AppTheme)
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: _isGridView ? DsIconKind.list : DsIconKind.grid,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: '切换视图',
                );
              },
            ),
          ),
          // 排序按钮(DSPopover 经根 Overlay 展示,需 DSThemeBridge 包裹)
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSPopover(
                  width: 190,
                  contentBuilder: (popoverContext, close) {
                    final popoverTheme = DSThemeBridge.resolve(popoverContext);
                    Widget menuRow(String value, String label) {
                      return Pressable(
                        onPressed: () async {
                          close();
                          setState(() {
                            _sortBy = value;
                          });
                          // 保存排序偏好
                          await GoodsPlugin.instance.saveSortPreference(
                            _warehouse.id,
                            value,
                          );
                        },
                        builder: (context, states) {
                          final pressed = states.contains(WidgetState.pressed);
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: popoverTheme.spacing.sm,
                              vertical: popoverTheme.spacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: pressed ? popoverTheme.surfaceAlt : null,
                              borderRadius: popoverTheme.radii.sm,
                            ),
                            child: Row(
                              children: [
                                DsIcon(
                                  _sortBy == value
                                      ? DsIconKind.check
                                      : DsIconKind.sort,
                                  size: 18,
                                  color: popoverTheme.text,
                                ),
                                SizedBox(width: popoverTheme.spacing.sm),
                                Text(
                                  label,
                                  style: DsTypography.body.copyWith(
                                    color: popoverTheme.text,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        menuRow('none', 'goods_sortByDefault'.tr),
                        menuRow('price', 'goods_sortByPrice'.tr),
                        menuRow('lastUsed', 'goods_sortByLastUsedTime'.tr),
                      ],
                    );
                  },
                  child: JellyBox(
                    width: 40,
                    height: 40,
                    radius: theme.radii.circle,
                    color: theme.surfaceAlt,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.sort,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 更多选项按钮
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.more,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: _showMoreOptions,
                );
              },
            ),
          ),
        ],
      ),
      body:
          _isGridView
              ? Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final cardWidth =
                            (constraints.maxWidth - 16) / 2; // 2列布局，减去一个spacing

                        return SizedBox(
                          width: cardWidth,
                          child: GoodsItemCard(
                            item: item,
                            warehouseId: _warehouse.id,
                            onTap:
                                () => NavigationHelper.push(
                                  context,
                                  GoodsItemDetailScreen(
                                    itemId: item.id,
                                    warehouseId: _warehouse.id,
                                  ),
                                ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              )
              : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GoodsItemListTile(
                    item: item,
                    warehouseId: _warehouse.id,
                    onTap: () => _showEditItemDialog(item),
                  );
                },
              ),
      floatingActionButton: DSFab(
        icon: DsIconKind.plus,
        onPressed: _showAddItemDialog,
      ),
    );
  }
}
