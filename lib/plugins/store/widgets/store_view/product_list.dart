import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/plugins/store/models/category.dart';
import 'package:aboutme/plugins/store/widgets/add_product_page.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/store/widgets/product_card.dart';
import 'package:aboutme/plugins/store/controllers/store_controller.dart';
import 'package:aboutme/plugins/store/widgets/store_view/product_detail_page.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ProductList extends StatefulWidget {
  final StoreController controller;

  const ProductList({super.key, required this.controller});

  @override
  State<ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  int _sortIndex = 0; // 0:默认, 1:库存, 2:价格, 3:兑换期限
  String _searchQuery = ''; // 搜索查询关键词
  Map<String, dynamic> _multiFilters = {}; // 多条件过滤值
  bool _isListView = false; // 视图模式：false=网格, true=列表

  @override
  void initState() {
    super.initState();
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

  /// 搜索商品（根据名称和描述）
  List<Product> _searchProducts(String query, List<Product> products) {
    if (query.isEmpty) return products;

    final lowercaseQuery = query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(lowercaseQuery) ||
          product.description.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// 处理搜索文本变化
  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 去重处理
    final uniqueProducts =
        widget.controller.products
            .fold<Map<String, Product>>({}, (map, product) {
              if (!map.containsKey(product.id)) {
                map[product.id] = product;
              }
              return map;
            })
            .values
            .toList();

    // 应用多条件过滤
    final filteredBase = uniqueProducts.where(_passesMultiFilters).toList();

    // 应用排序
    final sortedProducts = _applySort(filteredBase);

    // 应用搜索筛选
    final filteredProducts = _searchProducts(_searchQuery, sortedProducts);

    // 跳转商品详情页（Hero 路由：卡片图片飞入详情大图）
    void openDetail(Product product) {
      NavigationHelper.pushHero(
        context,
        ProductDetailPage(controller: widget.controller, product: product),
      );
    }

    // 打开编辑页
    void openEdit(Product product) {
      NavigationHelper.push(
        context,
        AddProductPage(controller: widget.controller, product: product),
      ).then((_) {
        if (mounted) setState(() {});
      });
    }

    // 空状态（列表/网格共用）
    Widget buildEmptyState() => Center(
      child: DSThemeBridge(
        child: DSEmptyState(
          emoji: '🛒',
          title:
              _searchQuery.isEmpty && _multiFilters.isEmpty
                  ? 'store_noProducts'.tr
                  : 'store_noMatchingProducts'.tr,
        ),
      ),
    );

    // 构建商品列表Widget
    Widget buildProductItems(List<Product> products) {
      if (products.isEmpty) return buildEmptyState();

      // 列表视图：横排卡片（左图右信息+圆形箭头，参考 food_scanner_ui）
      if (_isListView) {
        return HandDrawnListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: products.length,
          tiltKeyOf: (index) => products[index].id,
          itemBuilder: (context, index) {
            final product = products[index];
            // 挂载即播墨线描画入场（design.md §10）；key 上移保持条目状态
            return WiredDraw(
              key: ValueKey(product.id),
              child: _ProductListCard(
                product: product,
                onTap: () => openDetail(product),
                onLongPress: () => openEdit(product),
              ),
            );
          },
        );
      }

      // 网格视图（瀑布流）
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
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          // 点击卡片=进入详情，长按菜单=兑换/编辑（卡片内部处理）
          // 挂载即播墨线描画入场（design.md §10）；key 上移保持条目状态
          // 手绘便签贴条容器在 WiredDraw 外层
          return HandDrawnStickyItem(
            tiltKey: product.id,
            child: WiredDraw(
              key: ValueKey(product.id),
              child: ProductCard(
                product: product,
                onTap: () => openDetail(product),
                onExchange: () async {
                  if (await widget.controller.exchangeProduct(product)) {
                    if (mounted) setState(() {});
                    Toast.success('store_redeemSuccess'.tr);
                  } else {
                    Toast.error('store_redeemFailed'.tr);
                  }
                },
                onLongPress: () => openEdit(product),
              ),
            ),
          );
        },
      );
    }

    return SuperCupertinoNavigationWrapper(
      title: Text('store_productList'.tr),
      largeTitle: 'store_productList'.tr,
      body: buildProductItems(filteredProducts),
      searchBody: buildProductItems(filteredProducts), // 搜索结果页面
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'store_searchProductPlaceholder'.tr,
      onSearchChanged: _handleSearchChanged,
      // 多条件过滤栏，尾部为视图切换 + 排序入口
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _applyMultiFilters,
      multiFilterBarTrailing: _buildTrailingActions(),
    );
  }

  /// 排序选项 i18n key，索引与 [_sortIndex] 对应
  static const List<String> _sortLabels = [
    'store_defaultSort',
    'store_sortByStock',
    'store_sortByPrice',
    'store_sortByExpiryDate',
  ];

  /// 构建多条件过滤项
  List<FilterItem> _buildFilterItems() {
    final exchangeOptions = {
      'ongoing': 'store_exchanging'.tr,
      'upcoming': 'store_notStarted'.tr,
      'ended': 'store_exchangeEnded'.tr,
    };
    final stockOptions = {
      'inStock': 'store_inStock'.tr,
      'outOfStock': 'store_outOfStock'.tr,
    };

    // 分类选项：从商品数据动态收集
    final categoryOptions = <String, String>{};
    for (final product in widget.controller.products) {
      final category = product.category;
      if (category != null && category.isNotEmpty) {
        categoryOptions[category] = StoreCategories.labelOf(category);
      }
    }

    return [
      // 0. 分类
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

      // 1. 兑换状态
      FilterItem(
        id: 'exchangeStatus',
        title: 'store_exchangeStatus'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return DSThemeBridge(
            child: FilterBuilders.buildSingleChoiceFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              options: exchangeOptions,
              allItemsKey: 'all',
              allItemsLabel: 'store_all'.tr,
            ),
          );
        },
        getBadge:
            (value) => FilterBuilders.singleChoiceBadge(value, exchangeOptions),
      ),

      // 2. 库存
      FilterItem(
        id: 'stock',
        title: 'store_stockStatus'.tr,
        type: FilterType.tagsSingle,
        builder: (context, currentValue, onChanged) {
          return DSThemeBridge(
            child: FilterBuilders.buildSingleChoiceFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              options: stockOptions,
              allItemsKey: 'all',
              allItemsLabel: 'store_all'.tr,
            ),
          );
        },
        getBadge:
            (value) => FilterBuilders.singleChoiceBadge(value, stockOptions),
      ),

      // 3. 价格区间（积分）
      FilterItem(
        id: 'priceRange',
        title: 'store_priceRange'.tr,
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return _buildPriceRangeFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final range = value as Map<String, double?>;
          final min = range['min'];
          final max = range['max'];
          if (min != null && max != null) return '$min - $max';
          if (min != null) return '≥ $min';
          if (max != null) return '≤ $max';
          return null;
        },
      ),
    ];
  }

  /// 构建价格区间过滤器（积分），过滤面板内 DS 组件需经 DSThemeBridge 提供主题
  Widget _buildPriceRangeFilter({
    required BuildContext context,
    required dynamic currentValue,
    required ValueChanged<dynamic> onChanged,
  }) {
    final range =
        (currentValue as Map<String, double?>?) ?? {'min': null, 'max': null};
    final minController = TextEditingController(
      text: range['min']?.toString() ?? '',
    );
    final maxController = TextEditingController(
      text: range['max']?.toString() ?? '',
    );

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store_priceRange'.tr,
                  style: DsTypography.heading.copyWith(color: theme.text),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DSInput(
                        controller: minController,
                        label: 'store_minPrice'.tr,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newRange = Map<String, double?>.from(range);
                          newRange['min'] = double.tryParse(value);
                          onChanged(newRange);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('-'),
                    ),
                    Expanded(
                      child: DSInput(
                        controller: maxController,
                        label: 'store_maxPrice'.tr,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newRange = Map<String, double?>.from(range);
                          newRange['max'] = double.tryParse(value);
                          onChanged(newRange);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 应用多条件过滤
  void _applyMultiFilters(Map<String, dynamic> filters) {
    // addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters = filters;
        });
      }
    });
  }

  /// 检查商品是否通过所有多条件过滤
  bool _passesMultiFilters(Product product) {
    if (_multiFilters.isEmpty) return true;

    // 0. 分类
    final category = _multiFilters['category'] as String?;
    if (category != null && product.category != category) return false;

    // 1. 兑换状态
    final exchangeStatus = _multiFilters['exchangeStatus'] as String?;
    if (exchangeStatus != null) {
      final now = DateTime.now();
      switch (exchangeStatus) {
        case 'ongoing': // 兑换中：当前时间在兑换起止时间内
          if (now.isBefore(product.exchangeStart) ||
              now.isAfter(product.exchangeEnd)) {
            return false;
          }
        case 'upcoming': // 未开始
          if (!now.isBefore(product.exchangeStart)) return false;
        case 'ended': // 已结束
          if (!now.isAfter(product.exchangeEnd)) return false;
      }
    }

    // 2. 库存
    final stock = _multiFilters['stock'] as String?;
    if (stock != null) {
      if (stock == 'inStock' && product.stock <= 0) return false;
      if (stock == 'outOfStock' && product.stock > 0) return false;
    }

    // 3. 价格区间
    if (_multiFilters['priceRange'] != null) {
      final range = _multiFilters['priceRange'] as Map<String, double?>;
      final min = range['min'];
      final max = range['max'];
      if (min != null && product.price < min) return false;
      if (max != null && product.price > max) return false;
    }

    return true;
  }

  /// 过滤栏尾部动作：视图切换（网格/列表）+ 排序入口
  /// （DSPopover 经根 Overlay 展示需 DSThemeBridge 包裹）
  Widget _buildTrailingActions() {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 视图切换：图标显示待切换的目标模式
              Pressable(
                onPressed:
                    () => setState(() => _isListView = !_isListView),
                builder: (context, states) => JellyBox(
                  width: 36,
                  height: 36,
                  radius: theme.radii.circle,
                  color: theme.surfaceAlt,
                  child: Center(
                    child: DsIcon(
                      _isListView ? DsIconKind.grid : DsIconKind.list,
                      size: 18,
                      color: theme.textSub,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DSPopover(
                width: 170,
                contentBuilder: (context, close) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, label) in _sortLabels.indexed)
                        SmoothSheetAction(
                          icon: _sortIndex == index
                              ? DsIconKind.check
                              : DsIconKind.sort,
                          label: label.tr,
                          onTap: () {
                            close();
                            setState(() {
                              _sortIndex = index;
                            });
                          },
                        ),
                    ],
                  );
                },
                child: JellyBox(
                  width: 36,
                  height: 36,
                  radius: theme.radii.circle,
                  color: theme.surfaceAlt,
                  child: Center(
                    child: DsIcon(DsIconKind.sort, size: 18, color: theme.textSub),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Product> _applySort(List<Product> products) {
    switch (_sortIndex) {
      case 1: // 库存
        return products..sort((a, b) => a.stock.compareTo(b.stock));
      case 2: // 价格
        return products..sort((a, b) => b.price.compareTo(a.price));
      case 3: // 兑换期限
        return products..sort((a, b) => b.exchangeEnd.compareTo(a.exchangeEnd));
      default: // 默认
        return products;
    }
  }
}

/// 列表视图横排商品卡：左侧商品图 + 右侧信息（名称/状态/分类/价格）+ 圆形箭头
/// 布局参考 food_scanner_ui 的历史列表卡，视觉沿用应用手绘便签风
class _ProductListCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ProductListCard({required this.product, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final now = DateTime.now();
    final ended = now.isAfter(product.exchangeEnd);
    final notStarted = now.isBefore(product.exchangeStart);
    final soldOut = product.stock <= 0;
    final statusColor =
        ended || soldOut
            ? theme.danger
            : notStarted
            ? theme.warning
            : theme.success;
    final statusLabel = ended
        ? 'store_exchangeEnded'.tr
        : notStarted
        ? 'store_notStarted'.tr
        : soldOut
        ? 'store_outOfStock'.tr
        : 'store_exchanging'.tr;
    final hasCategory = product.category != null && product.category!.isNotEmpty;

    return DsSketchPanel(
      theme: theme,
      radius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 左侧商品图：Hero 与详情大图联动，点击全屏预览
                _buildImage(context, theme),
                const SizedBox(width: 12),

                // 中部信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.name,
                        style: DsTypography.heading.copyWith(
                          color: theme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // 元信息行：状态点+状态、分类、价格
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: DsTypography.caption.copyWith(
                                  color: theme.text,
                                ),
                              ),
                            ],
                          ),
                          if (hasCategory)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DsIcon(
                                  DsIconKind.tag,
                                  size: 12,
                                  color: theme.textSub,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  StoreCategories.labelOf(product.category!),
                                  style: DsTypography.caption.copyWith(
                                    color: theme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          Text(
                            'store_pricePoints'.trParams({
                              'price': '${product.price}',
                            }),
                            style: DsTypography.caption.copyWith(
                              color: theme.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 右侧圆形箭头
                JellyBox(
                  width: 28,
                  height: 28,
                  color: theme.surfaceAlt,
                  radius: theme.radii.circle,
                  child: Center(
                    child: DsIcon(
                      DsIconKind.chevronRight,
                      size: 16,
                      color: theme.textSub,
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

  /// 左侧商品图：有图时包 Hero 与详情页大图联动；
  /// 点击全屏预览（SVG 无 ImageProvider，不拦截、透传到整卡跳详情）
  Widget _buildImage(BuildContext context, AppThemeData theme) {
    final url = product.image;
    final hasImage = url != null && url.isNotEmpty;
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 76,
        height: 92,
        child: AdaptiveImage(
          imagePath: hasImage ? url : null,
          fit: BoxFit.cover,
          errorImage: _imagePlaceholder(theme),
          defaultImage: _imagePlaceholder(theme),
        ),
      ),
    );
    if (hasImage) {
      image = Hero(
        tag: ProductDetailPage.imageHeroTag(product.id),
        child: image,
      );
    }
    final previewable = hasImage && !AdaptiveImage.isSvgImage(url);
    return GestureDetector(
      onTap:
          previewable
              ? () => showDsImageViewer(
                context,
                image: ImageUtils.createImageProvider(url),
              )
              : null,
      child: image,
    );
  }

  Widget _imagePlaceholder(AppThemeData theme) => Container(
    color: theme.surfaceAlt,
    width: double.infinity,
    height: double.infinity,
    alignment: Alignment.center,
    child: DsIcon(DsIconKind.cart, size: 28, color: theme.textSub),
  );
}
