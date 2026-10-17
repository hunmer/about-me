import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/plugins/store/models/category.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/collection_shelf.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

/// 我的物品（手绘收集册：物品分层站立在货架上，点击 Q 弹后弹出舞台详情）
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

    // 分类选项：从全部物品动态收集（快照缺分类时回落当前商品数据）
    final categoryOptions = <String, String>{};
    for (final item in widget.controller.userItems) {
      final category = item.productCategory;
      if (category != null && category.isNotEmpty) {
        categoryOptions[category] = StoreCategories.labelOf(category);
      }
    }

    return [
      // 分类
      if (categoryOptions.isNotEmpty)
        FilterItem(
          id: 'category',
          title: 'store_categoryLabel'.tr,
          type: FilterType.tagsSingle,
          builder: (context, currentValue, onChanged) {
            return DSThemeBridge(
              child: FilterBuilders.buildSingleChoiceFilter(
                context: context,
                currentValue: currentValue,
                onChanged: onChanged,
                options: categoryOptions,
                allItemsKey: 'all',
                allItemsLabel: 'store_all'.tr,
              ),
            );
          },
          getBadge:
              (value) => FilterBuilders.singleChoiceBadge(
                value,
                categoryOptions,
              ),
        ),

      // 状态
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
      final description = item.productDescription.toLowerCase();
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

  /// 物品展示柜视图（主视图与搜索结果共用）：每 4 组一层，多层相连成整柜；
  /// 层高按全部物品的层数均分（过滤/搜索结果沿用同一层高，不拉伸），
  /// 物品过多（低于每层净高下限）时回退滚动
  Widget _buildGroupGrid(List<ItemGroup> groupedItems) {
    final theme = DSThemeBridge.resolve(context);
    const slotsPerShelf = 3;

    final rows = <List<ItemGroup>>[
      for (var i = 0; i < groupedItems.length; i += slotsPerShelf)
        groupedItems.sublist(
          i,
          math.min(i + slotsPerShelf, groupedItems.length),
        ),
    ];

    // 层高基准：全部物品（未过滤）的分组层数
    final totalGroups = _groupItems(widget.controller.userItems).length;
    final referenceRows = math.max(
      1,
      (totalGroups + slotsPerShelf - 1) ~/ slotsPerShelf,
    );

    final bottomPadding = 16 + MediaQuery.paddingOf(context).bottom;
    final padding = EdgeInsets.fromLTRB(16, 16, 16, bottomPadding);

    Widget buildCase() => CollectionShelfCase(
      theme: theme,
      seed: 1,
      referenceRowCount: referenceRows,
      rows: [
        for (final row in rows) [for (final group in row) _buildShelfSlot(group)],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 按基准层高估算整柜实际高度：能塞下就静态展示，塞不下改滚动
        final slotH = CollectionShelfCase.resolveSlotHeight(
          constraints.maxHeight,
          referenceRows,
        );
        final caseHeight = rows.length * (slotH + CollectionShelfCase.counterHeight);
        final canFill =
            constraints.maxHeight.isFinite &&
            caseHeight + 32 + bottomPadding <= constraints.maxHeight;

        final child = buildCase();
        if (canFill) return Padding(padding: padding, child: child);
        return SingleChildScrollView(padding: padding, child: child);
      },
    );
  }

  /// 单个货架槽位：点击 Q 弹后弹出舞台详情（使用/查看商品/删除）
  Widget _buildShelfSlot(ItemGroup group) {
    return CollectionShelfSlot(
      semanticLabel: group.item.productName.isEmpty
          ? 'store_productRemoved'.tr
          : group.item.productName,
      onTap: () => _openStageDialog(group),
      child: _ItemShelfArt(
        item: group.item,
        count: group.count,
        showCountBadge: true,
        showNameBadge: true,
      ),
    );
  }

  /// 舞台详情弹窗：展台物品 + 状态徽章 + 使用/查看商品/删除
  Future<void> _openStageDialog(ItemGroup group) async {
    final item = group.item;
    final theme = DSThemeBridge.resolve(context);

    final expired = DateTime.now().isAfter(item.expireDate);
    final daysLeft = item.expireDate.difference(DateTime.now()).inDays;
    final expiringSoon = !expired && daysLeft <= 7;
    final statusColor = expired
        ? theme.danger
        : expiringSoon
        ? theme.warning
        : theme.success;
    final statusLabel = expired
        ? 'store_expired'.tr
        : expiringSoon
        ? 'store_expiringSoon'.tr
        : 'store_daysLeft'.trParams({'days': '$daysLeft'});

    final description = item.productDescription;
    final meta =
        '${'store_validUntilDate'.trParams({
          'date': _formatDate(item.expireDate),
        })} · ${'store_remainingTimes'.trParams({'count': '${item.remaining}'})}';

    await showCollectionStageDialog(
      context: context,
      title: item.productName.isEmpty
          ? 'store_productRemoved'.tr
          : item.productName,
      chipLabel: statusLabel,
      chipColor: statusColor,
      art: _ItemShelfArt(item: item, size: 116),
      description: description.isEmpty ? meta : '$description\n$meta',
      // 已过期物品不可使用（不显示主操作）
      actionLabel: expired ? null : 'store_use'.tr,
      onAction: () => _useGroupItem(group),
      secondaryActions: [
        CollectionStageAction(
          icon: DsIconKind.store,
          onTap: () => _viewProduct(group),
        ),
        CollectionStageAction(
          icon: DsIconKind.trash,
          destructive: true,
          onTap: () => _deleteGroupItem(group),
        ),
      ],
    );
    if (mounted) setState(() {});
  }

  /// 使用物品（优先使用最早过期的同类物品）
  Future<void> _useGroupItem(ItemGroup group) async {
    final controller = widget.controller;
    final itemToUse = controller.sortedUserItems.firstWhere(
      (item) => item.productId == group.item.productId,
    );

    if (await controller.useItem(itemToUse)) {
      if (mounted) setState(() {});
      Toast.success('store_useSuccess'.tr);
    } else {
      Toast.error('store_itemExpired'.tr);
    }
  }

  /// 删除物品（删除同类型最早过期的物品）
  Future<void> _deleteGroupItem(ItemGroup group) async {
    final controller = widget.controller;
    final itemToDelete = controller.sortedUserItems.firstWhere(
      (item) => item.productId == group.item.productId,
    );
    await controller.deleteUserItem(itemToDelete);
    if (mounted) setState(() {});
    Toast.success('app_deleteSuccess'.tr);
  }

  /// 查看商品信息（从商品快照恢复 Product 对象）
  void _viewProduct(ItemGroup group) {
    final controller = widget.controller;
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
  }

  List<UserItem> _getFilteredItems() {
    final now = DateTime.now();
    final status = _multiFilters['status'] as String?;
    final category = _multiFilters['category'] as String?;
    return widget.controller.userItems.where((item) {
      // 分类
      if (category != null) {
        if (item.productCategory != category) {
          return false;
        }
      }
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

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

class ItemGroup {
  final UserItem item;
  int count;

  ItemGroup({required this.item, required this.count});
}

/// 货架/舞台上的物品造型：封面图（支持 SVG）站立摆放；
/// 过期物品转为灰度剪影（对应收集册「未解锁剪影」的表现）
class _ItemShelfArt extends StatelessWidget {
  const _ItemShelfArt({
    required this.item,
    this.size,
    this.count = 1,
    this.showCountBadge = false,
    this.showNameBadge = false,
  });

  final UserItem item;

  /// 造型边长；null = 随所在格子自适应（取格宽/格高较小者）
  final double? size;
  final int count;
  final bool showCountBadge;

  /// 物品上方是否显示名称徽章（货架槽位用，舞台弹窗已有标题不重复）
  final bool showNameBadge;

  @override
  Widget build(BuildContext context) {
    // 名称徽章占用的纵向空间（预留后造型仍能落在格子内）
    const nameBadgeSpace = 22.0;
    if (size != null) return _buildArt(context, size!);
    return LayoutBuilder(
      builder: (context, constraints) => _buildArt(
        context,
        math.min(
          constraints.maxWidth,
          constraints.maxHeight - (showNameBadge ? nameBadgeSpace : 0),
        ),
      ),
    );
  }

  Widget _buildArt(BuildContext context, double size) {
    final theme = DSThemeBridge.resolve(context);
    final expired = DateTime.now().isAfter(item.expireDate);

    Widget placeholder() =>
        DsIcon(DsIconKind.gift, size: size * 0.5, color: theme.textSub);

    Widget art = AdaptiveImage(
      imagePath: item.productImage.isEmpty ? null : item.productImage,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorImage: placeholder(),
      defaultImage: placeholder(),
    );

    if (expired) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 0.9, 0,
        ]),
        child: art,
      );
    }

    Widget artStack;
    if (!showCountBadge || count <= 1) {
      artStack = SizedBox(
        width: size,
        height: size,
        child: Center(child: art),
      );
    } else {
      artStack = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Center(child: art)),
            // 右上：同类物品数量徽章
            Positioned(
              top: -4,
              right: -8,
              child: JellyBox(
                width: 20,
                height: 20,
                color: theme.ink.withValues(alpha: 0.6),
                radius: theme.radii.circle,
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: DsTypography.caption.copyWith(
                    color: theme.paper,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!showNameBadge) return artStack;

    // 物品上方：名称徽章（过期物品弱化显示）
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size),
          child: JellyBox(
            color: theme.paper,
            radius: theme.radii.circle,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    item.productName.isEmpty
                        ? 'store_productRemoved'.tr
                        : item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(
                      color: expired ? theme.textSub : theme.text,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),
        artStack,
      ],
    );
  }
}
