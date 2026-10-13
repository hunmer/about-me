import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'warehouse_detail_screen.dart';
import 'package:aboutme/plugins/goods/widgets/warehouse_card.dart';
import 'package:aboutme/plugins/goods/widgets/warehouse_form.dart';

class WarehouseListScreen extends StatefulWidget {
  const WarehouseListScreen({super.key, this.onWarehouseTap});

  final Function(String warehouseId)? onWarehouseTap;

  @override
  State<WarehouseListScreen> createState() => _WarehouseListScreenState();
}

class _WarehouseListScreenState extends State<WarehouseListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    GoodsPlugin.instance.addListener(_onWarehousesChanged);

    // 设置路由上下文
    _updateRouteContext();
  }

  /// 更新路由上下文,使"询问当前上下文"功能能获取到当前页面状态
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: "/goods/warehouses",
      title: '物品 - 所有仓库',
      params: {},
    );
  }

  @override
  void dispose() {
    GoodsPlugin.instance.removeListener(_onWarehousesChanged);
    super.dispose();
  }

  void _onWarehousesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 根据搜索关键词过滤仓库列表
  List<dynamic> _filterWarehouses(List<dynamic> warehouses) {
    if (_searchQuery.isEmpty) {
      return warehouses;
    }

    return warehouses.where((warehouse) {
      return warehouse.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = GoodsPlugin.instance.warehouses;
    final filteredWarehouses = _filterWarehouses(warehouses);

    return SuperCupertinoNavigationWrapper(
      title: Text('goods_allWarehouses'.tr),
      largeTitle: 'goods_allWarehouses'.tr,
      body:
          filteredWarehouses.isEmpty && _searchQuery.isNotEmpty
              ? _buildEmptySearchView()
              : ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  96 + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: filteredWarehouses.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final warehouse = filteredWarehouses[index];
                  return WarehouseCard(
                    warehouse: warehouse,
                    onTap: () {
                      if (widget.onWarehouseTap != null) {
                        widget.onWarehouseTap!(warehouse.id);
                      } else {
                        NavigationHelper.push(
                          context,
                          WarehouseDetailScreen(warehouse: warehouse),
                        );
                      }
                    },
                    onEdit: () {
                      _showEditWarehouse(context, warehouse);
                    },
                    onDelete: () {
                      _showDeleteWarehouseDialog(context, warehouse);
                    },
                  );
                },
              ),
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'goods_searchWarehouse'.tr,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
    );
  }

  /// 显示编辑仓库表单（smooth_sheets 底部弹层）
  void _showEditWarehouse(BuildContext context, dynamic warehouse) {
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: DSThemeBridge.resolve(context).background,
      builder: (context) => WarehouseForm(
        warehouse: warehouse,
        inSheet: true,
        onSave: (updatedWarehouse) async {
          await GoodsPlugin.instance.saveWarehouse(updatedWarehouse);
          if (context.mounted) {
            setState(() {});
          }
        },
        onDelete: () async {
          await GoodsPlugin.instance.deleteWarehouse(warehouse.id);
          if (context.mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  /// 显示删除仓库确认对话框
  void _showDeleteWarehouseDialog(BuildContext context, dynamic warehouse) {
    showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'goods_confirmDelete'.tr,
                    message: 'goods_confirmDeleteWarehouseMessage'.trParams({
                      'warehouseName': warehouse.title,
                    }),
                    cancelText: 'goods_cancel'.tr,
                    confirmText: 'goods_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () async {
                      Navigator.pop(context, true);
                      await GoodsPlugin.instance.deleteWarehouse(warehouse.id);
                      if (context.mounted) {
                        setState(() {});
                      }
                    },
                  ),
            ),
          ),
    );
  }

  /// 构建空搜索结果视图
  Widget _buildEmptySearchView() {
    return DSThemeBridge(
      child: DSEmptyState(
        emoji: '🔍',
        title: '未找到匹配的仓库',
        message: '请尝试其他搜索关键词',
      ),
    );
  }
}
