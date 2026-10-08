import 'package:get/get.dart';
import 'package:aboutme/plugins/goods/screens/warehouse_list_screen.dart';
import 'package:aboutme/plugins/goods/screens/goods_list_screen.dart';
import 'package:aboutme/plugins/goods/widgets/warehouse_form.dart';
import 'package:aboutme/plugins/goods/widgets/goods_item_form/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';

/// Goods 插件的底部栏组件
/// 提供仓库视图和物品视图的切换功能
class GoodsBottomBar extends StatefulWidget {
  final GoodsPlugin plugin;

  const GoodsBottomBar({super.key, required this.plugin});

  @override
  State<GoodsBottomBar> createState() => _GoodsBottomBarState();
}

class _GoodsBottomBarState extends State<GoodsBottomBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentPage;
  String? _filterWarehouseId;
  final GlobalKey _bottomBarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentPage = 0;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation?.addListener(() {
      final value = _tabController.animation!.value.round();
      if (value != _currentPage && mounted) {
        setState(() {
          _currentPage = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 创建新仓库
  Future<void> _createWarehouse() async {
    await NavigationHelper.push(
      context,
      WarehouseForm(
        onSave: (warehouse) async {
          try {
            await widget.plugin.saveWarehouse(warehouse);
            if (mounted) {
              Toast.success('goods_warehouseCreated'.tr);
            }
          } catch (e) {
            if (mounted) {
              Toast.error('${'goods_createWarehouseFailed'.tr}: $e');
            }
          }
        },
      ),
    );
  }

  /// 处理仓库点击事件
  void _handleWarehouseTap(String warehouseId) {
    setState(() {
      _filterWarehouseId = warehouseId;
    });
    // 切换到物品视图 (tab index 1)
    _tabController.animateTo(1);
  }

  /// 添加物品
  Future<void> _addItem() async {
    // 如果没有仓库，提示先创建仓库
    if (widget.plugin.warehouses.isEmpty) {
      Toast.info('goods_createWarehouseFirst'.tr);
      return;
    }

    // 跳转到物品创建表单
    GoodsItemForm.show(
      context: context,
      onSubmit: (item) async {
        try {
          // 选择第一个仓库（实际应用中应该让用户选择）
          final warehouseId = widget.plugin.warehouses.first.id;
          await widget.plugin.saveGoodsItem(warehouseId, item);
          if (mounted) {
            Toast.success('goods_itemCreated'.tr);
          }
        } catch (e) {
          if (mounted) {
            Toast.error('${'goods_createItemFailed'.tr}: $e');
          }
        }
      },
    );
  }

  /// 构建 FAB
  Widget _buildFab() {
    return DSThemeBridge(
      // DSFab 内部取 AppTheme，需包桥
      child: DSFab(
        color: widget.plugin.color, // 使用插件主题色
        iconColor: widget.plugin.color.computeLuminance() < 0.5
            ? Colors.white
            : Colors.black,
        icon: _currentPage == 0 ? DsIconKind.store : DsIconKind.plus,
        onPressed: () {
          if (_currentPage == 0) {
            // Tab0: 添加仓库
            _createWarehouse();
          } else {
            // Tab1: 添加物品
            _addItem();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      currentIndex: _currentPage,
      tabController: _tabController,
      bottomBarKey: _bottomBarKey,
      body: (context, controller) => TabBarView(
        controller: _tabController,
        dragStartBehavior: DragStartBehavior.start,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Tab0: 仓库视图
          WarehouseListScreen(onWarehouseTap: _handleWarehouseTap),
          // Tab1: 物品视图
          GoodsListScreen(
            key: ValueKey('goods_list_${_filterWarehouseId ?? "all"}'),
            initialFilterWarehouseId: _filterWarehouseId,
          ),
        ],
      ),
      fab: _buildFab(),
      items: [
        DSNavItem(icon: DsIconKind.layers, label: 'goods_warehouseTab'.tr),
        DSNavItem(icon: DsIconKind.gift, label: 'goods_itemsTab'.tr),
      ],
    );
  }
}
