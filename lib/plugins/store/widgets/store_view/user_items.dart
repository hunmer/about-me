import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/store/widgets/user_item_card.dart';
import 'package:aboutme/plugins/store/widgets/user_item_detail_page.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class UserItems extends StatefulWidget {
  final StoreController controller;
  final int initialStatusIndex;

  const UserItems({
    super.key,
    required this.controller,
    this.initialStatusIndex = 0,
  });

  @override
  State<UserItems> createState() => _UserItemsState();
}

class _UserItemsState extends State<UserItems> {
  final Map<String, dynamic> _multiFilters = {}; // 多条件过滤值
  String _searchQuery = ''; // 搜索查询文本

  @override
  void initState() {
    super.initState();
    // 兼容旧的状态索引参数：1 可使用 / 2 已过期
    if (widget.initialStatusIndex == 1) {
      _multiFilters['status'] = 'usable';
    } else if (widget.initialStatusIndex == 2) {
      _multiFilters['status'] = 'expired';
    }
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems() {
    final statusOptions = {
      'usable': 'store_usable'.tr,
      'expired': 'store_expired'.tr,
    };

    return [
      FilterItem(
        id: 'status',
        title: 'store_itemStatus'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return DSThemeBridge(
            child: FilterBuilders.buildSingleChoiceFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              options: statusOptions,
              allItemsKey: 'all',
              allItemsLabel: 'store_all'.tr,
            ),
          );
        },
        getBadge:
            (value) => FilterBuilders.singleChoiceBadge(value, statusOptions),
      ),
    ];
  }

  /// 应用多条件过滤
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters
            ..clear()
            ..addAll(filters);
        });
      }
    });
  }

  /// 处理搜索文本变化
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// 搜索过滤物品（按名称和描述）
  List<UserItem> _searchItems(List<UserItem> items) {
    if (_searchQuery.isEmpty) return items;

    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      final name = item.productName.toLowerCase();
      final description =
          (item.productSnapshot['description'] ?? '').toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.userItems.isEmpty) {
      return _buildEmptyView();
    }

    return _buildMyItemsView();
  }

  Widget _buildEmptyView() {
    return SuperCupertinoNavigationWrapper(
      title: Text('store_myItems'.tr),
      largeTitle: 'store_myItems'.tr,
      body: Center(
        child: DSThemeBridge(
          child: DSEmptyState(
            emoji: '🎁',
            title: 'store_noItems'.tr,
            message: 'store_emptyItemsHint'.tr,
          ),
        ),
      ),
      enableLargeTitle: true,
      // 即使没有物品也启用搜索栏，让用户可以搜索（虽然不会有结果）
      enableSearchBar: true,
      searchPlaceholder: 'store_searchItemPlaceholder'.tr,
      onSearchChanged: _onSearchChanged,
      // 提供空的搜索结果页面
      searchBody: _buildSearchResultsView(),
    );
  }

  Widget _buildMyItemsView() {
    final items = _getFilteredItems();
    final groupedItems = _groupItems(items);

    return SuperCupertinoNavigationWrapper(
      title: Text('store_myItems'.tr),
      largeTitle: 'store_myItems'.tr,
      body:
          groupedItems.isEmpty
              ? Center(
                child: DSThemeBridge(
                  child: DSEmptyState(
                    emoji: '🎁',
                    title: 'store_noItemsForFilter'.tr,
                  ),
                ),
              )
              : _buildGroupGrid(groupedItems),
      // 启用搜索栏
      enableSearchBar: true,
      searchPlaceholder: 'store_searchItemPlaceholder'.tr,
      onSearchChanged: _onSearchChanged,
      // 搜索结果页面
      searchBody: _buildSearchResultsView(),
      enableLargeTitle: true,
      // 多条件过滤栏（状态筛选从 header 迁入）
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,
      initialMultiFilters: _multiFilters.isNotEmpty ? _multiFilters : null,
    );
  }

  /// 构建搜索结果页面
  Widget _buildSearchResultsView() {
    // 获取所有物品并应用搜索过滤
    final allItems = widget.controller.userItems;
    final filteredItems = _searchItems(allItems);
    final groupedItems = _groupItems(filteredItems);

    // 如果没有搜索查询，显示提示
    if (_searchQuery.isEmpty) {
      return Center(
        child: DSThemeBridge(
          child: DSEmptyState(
            emoji: '🔍',
            title: 'store_searchItemsHint'.tr,
          ),
        ),
      );
    }

    // 如果搜索结果为空，显示空状态
    if (groupedItems.isEmpty) {
      return Center(
        child: DSThemeBridge(
          child: DSEmptyState(
            emoji: '🔍',
            title: 'store_noSearchResults'.tr,
            message: 'store_tryOtherKeywords'.tr,
          ),
        ),
      );
    }

    // 显示搜索结果
    return _buildGroupGrid(groupedItems);
  }

  /// 物品分组网格（主视图与搜索结果共用）
  Widget _buildGroupGrid(List<ItemGroup> groupedItems) {
    return MasonryGridView.count(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      itemCount: groupedItems.length,
      itemBuilder: (context, index) =>
          _buildGroupCard(context, groupedItems[index]),
    );
  }

  /// 单个物品分组卡片：点击进详情，长按菜单提供使用/查看商品/删除
  Widget _buildGroupCard(BuildContext context, ItemGroup group) {
    final controller = widget.controller;
    return UserItemCard(
      item: group.item,
      count: group.count,
      onTap: () {
        // 获取同类型的所有物品
        final sameTypeItems = controller.userItems
            .where((item) => item.productId == group.item.productId)
            .toList();

        NavigationHelper.push(
          context,
          UserItemDetailPage(controller: controller, items: sameTypeItems),
        ).then((_) {
          if (mounted) setState(() {});
        });
      },
      onUse: () async {
        // 优先使用最早过期的物品
        final itemToUse = controller.sortedUserItems.firstWhere(
          (item) => item.productId == group.item.productId,
        );

        if (await controller.useItem(itemToUse)) {
          setState(() {});
          Toast.success('store_useSuccess'.tr);
        } else {
          Toast.error('store_itemExpired'.tr);
        }
      },
      onDelete: () async {
        // 删除同类型最早过期的物品
        final itemToDelete = controller.sortedUserItems.firstWhere(
          (item) => item.productId == group.item.productId,
        );
        await controller.deleteUserItem(itemToDelete);
        setState(() {});
        Toast.success('app_deleteSuccess'.tr);
      },
      onViewProduct: () {
        // 从商品快照恢复 Product 对象查看信息
        final product = controller.products.firstWhereOrNull(
          (p) => p.id == group.item.productId,
        );
        if (product != null) {
          NavigationHelper.push(
            context,
            AddProductPage(controller: controller, product: product),
          ).then((_) {
            if (mounted) setState(() {});
          });
        } else {
          Toast.warning('store_productNotFound'.tr);
        }
      },
    );
  }

  List<UserItem> _getFilteredItems() {
    final now = DateTime.now();
    final status = _multiFilters['status'] as String?;
    return widget.controller.userItems.where((item) {
      switch (status) {
        case 'usable': // 可使用
          return item.expireDate.isAfter(now);
        case 'expired': // 已过期
          return item.expireDate.isBefore(now);
        default: // 全部
          return true;
      }
    }).toList();
  }

  List<ItemGroup> _groupItems(List<UserItem> items) {
    final groups = <String, ItemGroup>{};

    for (final item in items) {
      final key = '${item.productId}_${item.purchasePrice}';
      if (groups.containsKey(key)) {
        groups[key]!.count++;
      } else {
        groups[key] = ItemGroup(item: item, count: 1);
      }
    }

    return groups.values.toList();
  }
}

class ItemGroup {
  final UserItem item;
  int count;

  ItemGroup({required this.item, required this.count});
}
