import 'dart:async';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/store/models/used_item.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/plugins/store/models/product.dart';
import 'package:aboutme/plugins/store/models/user_item.dart';
import 'package:aboutme/plugins/store/models/points_log.dart';
import 'package:aboutme/plugins/store/sample_data.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:get/get.dart';

/// Store 缓存更新事件参数
class StoreCacheUpdatedEventArgs extends EventArgs {
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> archivedProducts;
  final List<Map<String, dynamic>> userItems;
  final List<Map<String, dynamic>> pointsLogs;
  final int userPoints;
  final DateTime cacheDate;

  StoreCacheUpdatedEventArgs({
    required this.products,
    required this.archivedProducts,
    required this.userItems,
    required this.pointsLogs,
    required this.userPoints,
    required this.cacheDate,
  }) : super('store_cache_updated');
}

class StoreController with ChangeNotifier {
  /// 通知外部监听者数据已更新
  void notifyUpdate() => notifyListeners();

  /// 数据同步事件订阅取消句柄
  VoidCallback? _cancelDataSync;

  List<Product> _products = [];
  final List<Product> _archivedProducts = [];
  List<UserItem> _userItems = [];
  List<PointsLog> _pointsLogs = [];
  int _userPoints = 0;
  late final BasePlugin plugin;

  // 添加流控制器
  final _productsStreamController = StreamController<int>.broadcast();
  final _userItemsStreamController = StreamController<int>.broadcast();
  final _pointsStreamController = StreamController<int>.broadcast();

  // 获取流
  Stream<int> get productsStream => _productsStreamController.stream;
  Stream<int> get userItemsStream => _userItemsStreamController.stream;
  Stream<int> get pointsStream => _pointsStreamController.stream;

  StoreController([BasePlugin? plugin]) {
    if (plugin != null) {
      this.plugin = plugin;
    } else {
      final pluginInstance = PluginManager.instance.getPlugin('store_plugin');
      if (pluginInstance == null) {
        throw FlutterError('StorePlugin not registered in PluginManager');
      }
      this.plugin = pluginInstance as BasePlugin;
    }

    // 初始化流数据
    _updateStreams();

    // 远端变更（REST/MCP/其它设备写入）→ 局部重载刷新
    _cancelDataSync = AboutmeDataService.instance.onPluginChanged(
      'store',
      reloadData,
    );
  }

  @override
  void dispose() {
    _cancelDataSync?.call();
    _productsStreamController.close();
    _userItemsStreamController.close();
    _pointsStreamController.close();
    super.dispose();
  }

  // ========== 事件通知 ==========

  /// 触发商品事件
  void _notifyProductEvent(String action, Product product) {
    final eventArgs = ItemEventArgs(
      eventName: 'store_product_$action',
      itemId: product.id,
      title: product.name,
      action: action,
    );
    EventManager.instance.broadcast('store_product_$action', eventArgs);
  }

  /// 触发用户物品事件
  void _notifyUserItemEvent(String action, UserItem userItem) {
    final productName = userItem.productName;
    final eventArgs = ItemEventArgs(
      eventName: 'store_user_item_$action',
      itemId: userItem.id,
      title: productName,
      action: action,
    );
    EventManager.instance.broadcast('store_user_item_$action', eventArgs);
  }

  /// 触发积分变化事件
  void _notifyPointsEvent(int value, String reason) {
    final eventArgs = ItemEventArgs(
      eventName: 'store_points_changed',
      itemId: '',  // 积分变化没有具体ID
      title: reason,
      action: 'changed',
    );
    EventManager.instance.broadcast('store_points_changed', eventArgs);
  }

  /// 触发缓存更新事件（携带最新数据）；
  /// 物品数据附带解析出的展示字段（product_name/product_image），
  /// 供直接消费原始 Map 的小组件使用
  void _notifyCacheUpdatedEvent() {
    final eventArgs = StoreCacheUpdatedEventArgs(
      products: productsJson,
      archivedProducts: archivedProductsJson,
      userItems:
          _userItems
              .map(
                (item) => {
                  ...item.toJson(),
                  'product_name': item.productName,
                  'product_image': item.productImage,
                },
              )
              .toList(),
      pointsLogs: _pointsLogs.map((log) => log.toJson()).toList(),
      userPoints: _userPoints,
      cacheDate: DateTime.now(),
    );
    EventManager.instance.broadcast('store_cache_updated', eventArgs);
  }

  // 更新所有流
  void _updateStreams() {
    _linkItemBases();
    _productsStreamController.add(_products.length);
    _userItemsStreamController.add(_userItems.length);
    _pointsStreamController.add(_userPoints);
  }

  /// 旧快照迁移：商品与归档都找不到时，用历史快照构建的临时基础数据
  final Map<String, Product> _extraItemBases = {};

  /// 为全部物品解析商品基础数据引用（商品列表 → 归档 → 旧快照临时数据）。
  /// 商品增删/归档后调用，保证物品侧始终读到最新基础数据。
  void _linkItemBases() {
    for (final item in _userItems) {
      item.base = _resolveItemBase(item);
    }
  }

  Product? _resolveItemBase(UserItem item) {
    final live =
        _products.firstWhereOrNull((p) => p.id == item.productId) ??
        _archivedProducts.firstWhereOrNull((p) => p.id == item.productId);
    if (live != null) return live;
    final snapshot = item.legacySnapshot;
    if (snapshot == null) return null;
    return _extraItemBases[item.productId] ??= Product.fromJson(snapshot);
  }

  // 获取商品列表
  List<Product> get products => _products;

  // 获取存档商品列表
  List<Product> get archivedProducts => _archivedProducts;

  // 获取可序列化的商品列表
  List<Map<String, dynamic>> get productsJson =>
      _products.map((p) => p.toJson()).toList();

  // 获取可序列化的存档商品列表
  List<Map<String, dynamic>> get archivedProductsJson =>
      _archivedProducts.map((p) => p.toJson()).toList();

  // 获取用户物品
  List<UserItem> get userItems => _userItems;

  // 获取积分记录
  List<PointsLog> get pointsLogs => _pointsLogs;
  final List<UsedItem> _usedItems = [];
  List<UsedItem> get usedItems => _usedItems;

  // 获取用户积分
  int get userPoints => _userPoints;
  int get currentPoints => _userPoints;

  // 获取按过期时间排序的物品列表
  List<UserItem> get sortedUserItems {
    return _userItems..sort((a, b) => a.expireDate.compareTo(b.expireDate));
  }

  // 获取商品总数
  int getGoodsCount() {
    return _products.length;
  }

  // 获取用户物品总数
  int getItemsCount() {
    return _userItems.length;
  }

  // 获取七天内到期的物品数量
  int getExpiringItemsCount() {
    final now = DateTime.now();
    final sevenDaysLater = now.add(const Duration(days: 7));
    return _userItems
        .where(
          (item) =>
              item.expireDate.isAfter(now) &&
              item.expireDate.isBefore(sevenDaysLater),
        )
        .length;
  }

  // 获取今日兑换次数
  int getTodayRedeemCount() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _userItems
        .where(
          (item) =>
              item.purchaseDate.isAfter(startOfDay) &&
              item.purchaseDate.isBefore(endOfDay),
        )
        .length;
  }

  // 获取今日获得的积分
  int getTodayPoints() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _pointsLogs
        .where(
          (log) =>
              log.timestamp.isAfter(startOfDay) &&
              log.timestamp.isBefore(endOfDay) &&
              log.type == '获得',
        )
        .fold(0, (sum, log) => sum + log.value);
  }

  // 添加商品
  Future<void> addProduct(Product product) async {
    _products.add(product);
    _updateStreams();

    // 触发商品添加事件
    _notifyProductEvent('added', product);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();

    // 同步小组件数据
    await _syncWidget();
  }

  // 从JSON添加商品
  Future<void> addProductFromJson(Map<String, dynamic> json) async {
    final product = Product.fromJson(json);
    _products.add(product);
    // 触发商品添加事件
    _notifyProductEvent('added', product);
  }

  // 兑换商品
  Future<bool> exchangeProduct(Product product) async {
    // 校验积分和库存
    if (_userPoints < product.price) return false;
    if (product.stock <= 0) return false;
    if (DateTime.now().isBefore(product.exchangeStart) ||
        DateTime.now().isAfter(product.exchangeEnd)) {
      return false;
    }

    // 执行兑换
    _userPoints -= product.price;
    final index = _products.indexOf(product);
    _products[index] = Product(
      id: product.id,
      name: product.name,
      description: product.description,
      image: product.image,
      category: product.category,
      stock: product.stock - 1,
      price: product.price,
      exchangeStart: product.exchangeStart,
      exchangeEnd: product.exchangeEnd,
      useDuration: product.useDuration,
    );

    // 添加用户物品（基础数据经 base 引用商品列表，不再快照复制）
    final newItem = UserItem(
      id: const Uuid().v4(),
      productId: product.id,
      remaining: 1,
      expireDate: DateTime.now().add(Duration(days: product.useDuration)),
      purchaseDate: DateTime.now(),
      purchasePrice: product.price,
    )..base = product;
    _userItems.add(newItem);

    // 添加积分记录
    _pointsLogs.add(
      PointsLog(
        id: const Uuid().v4(),
        type: '消耗',
        value: product.price,
        reason: '兑换商品: ${product.name}',
        timestamp: DateTime.now(),
      ),
    );

    await saveProducts();
    await savePoints();
    await saveUserItems();
    _updateStreams(); // 更新badge显示
    notifyListeners(); // 通知UI更新

    // 触发用户物品添加事件
    _notifyUserItemEvent('added', newItem);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();

    // 同步小组件数据
    await _syncWidget();

    return true;
  }

  // 使用物品
  Future<bool> useItem(UserItem item) async {
    if (DateTime.now().isAfter(item.expireDate)) return false;

    // 记录使用历史（使用记录冻结当时的基础数据快照）
    _usedItems.add(
      UsedItem(
        id: item.id,
        productId: item.productId,
        useDate: DateTime.now(),
        productSnapshot:
            item.base?.toJson() ?? Map<String, dynamic>.from(item.legacySnapshot ?? const {}),
      ),
    );

    item.use();
    if (item.remaining <= 0) {
      _userItems.remove(item);
    }
    await saveProducts();
    await savePoints();
    await saveUserItems();
    _updateStreams(); // 更新badge显示
    notifyListeners(); // 通知UI更新

    // 触发用户物品使用事件
    _notifyUserItemEvent('used', item);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();

    return true;
  }

  // 删除用户物品
  Future<void> deleteUserItem(UserItem item) async {
    _userItems.remove(item);
    await saveUserItems();
    _updateStreams();
    notifyListeners();

    // 触发用户物品删除事件
    _notifyUserItemEvent('deleted', item);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();
  }

  // 保存已使用物品
  Future<void> saveUsedItems() async {
    await AboutmeDataService.instance.writePath('store/used_items.json', {
      'items': _usedItems.map((item) => item.toJson()).toList(),
    });
  }

  // 加载已使用物品
  Future<void> loadUsedItems() async {
    final storedUsedItems = await AboutmeDataService.instance.readPath(
      'store/used_items.json',
    );
    if (storedUsedItems is Map<String, dynamic>) {
      final itemsData = storedUsedItems['items'];
      if (itemsData is List) {
        _usedItems.clear();
        _usedItems.addAll(
          (itemsData)
              .whereType<Map<String, dynamic>>()
              .map((item) => UsedItem.fromJson(item))
              .toList(),
        );
      }
    }
  }

  // 添加积分
  Future<void> addPoints(int value, String reason) async {
    _userPoints += value;
    _pointsLogs.add(
      PointsLog(
        id: const Uuid().v4(),
        type: value > 0 ? '获得' : '失去',
        value: value,
        reason: reason,
        timestamp: DateTime.now(),
      ),
    );
    await savePoints();
    _updateStreams();
    notifyListeners();

    // 触发积分变化事件（始终触发，供其他插件监听）
    _notifyPointsEvent(value, reason);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();

    // 检查是否启用积分变动通知（toast 提示）
    final enablePointsNotification =
        plugin.settings['enablePointsNotification'] as bool? ?? true;
    if (enablePointsNotification) {
      // 显示 toast 通知
      final message = value > 0
          ? '获得 $value 积分：$reason'
          : value < 0
              ? '消耗 ${-value} 积分：$reason'
              : '积分变动：$reason';
      toastService.showToast(message);
    }

    // 同步小组件数据
    await _syncWidget();
  }

  // 排序商品
  Future<void> sortProducts(String field, {bool ascending = true}) async {
    _products.sort((a, b) {
      int compareResult;
      switch (field) {
        case 'stock':
          compareResult = a.stock.compareTo(b.stock);
          break;
        case 'price':
          compareResult = a.price.compareTo(b.price);
          break;
        case 'exchangeEnd':
          compareResult = a.exchangeEnd.compareTo(b.exchangeEnd);
          break;
        default:
          compareResult = 0;
      }
      return ascending ? compareResult : -compareResult;
    });
    await saveProducts();
  }

  // 排序用户物品
  Future<void> sortUserItems(String field, {bool ascending = true}) async {
    _userItems.sort((a, b) {
      int compareResult;
      switch (field) {
        case 'remaining':
          compareResult = a.remaining.compareTo(b.remaining);
          break;
        case 'expireDate':
          compareResult = a.expireDate.compareTo(b.expireDate);
          break;
        default:
          compareResult = 0;
      }
      return ascending ? compareResult : -compareResult;
    });
    await saveUserItems();
  }

  // 存档产品
  Future<void> archiveProduct(Product product) async {
    // 从产品列表中移除
    _products.removeWhere((p) => p.id == product.id);
    // 添加到存档列表
    _archivedProducts.add(product);
    await saveProducts();
    await saveArchivedProducts();
    notifyListeners();

    // 触发商品归档事件
    _notifyProductEvent('archived', product);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();
  }

  // 恢复存档产品
  Future<void> restoreProduct(Product product) async {
    // 从存档列表中移除
    _archivedProducts.removeWhere((p) => p.id == product.id);
    // 添加到产品列表
    _products.add(product);
    await saveProducts();
    await saveArchivedProducts();
    notifyListeners();

    // 触发商品恢复事件
    _notifyProductEvent('restored', product);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();
  }

  /// 重新加载数据（供同步后刷新使用）
  Future<void> reloadData() async {
    await loadFromStorage();
    notifyListeners();
  }

  // 从存储加载数据
  Future<void> loadFromStorage() async {
    final storedProducts = await AboutmeDataService.instance.readPath(
      'store/products.json',
    );
    final storedArchivedProducts = await AboutmeDataService.instance.readPath(
      'store/archived_products.json',
    );
    final storedPoints = await AboutmeDataService.instance.readPath(
      'store/points.json',
    );
    final storedUserItems = await AboutmeDataService.instance.readPath(
      'store/user_items.json',
    );
    await loadUsedItems();

    _products.clear();
    _archivedProducts.clear();
    _pointsLogs.clear();
    _userItems.clear();

    // 检查是否有数据，没有则初始化默认数据
    // 注意：readPath 对不存在的文件返回空 Map {}，需排除（否则 hasPoints
    // 恒为 true，删除数据文件后永远不会回落默认数据）
    final hasProducts =
        storedProducts is Map<String, dynamic> &&
        storedProducts['products'] is List &&
        (storedProducts['products'] as List).isNotEmpty;
    final hasPoints =
        storedPoints is Map<String, dynamic> && storedPoints.isNotEmpty;
    final hasUserItems =
        storedUserItems is Map<String, dynamic> &&
        storedUserItems['items'] is List;

    if (!hasProducts && !hasPoints && !hasUserItems) {
      debugPrint('No existing data found, initializing with default data');
      await initializeDefaultData();
      return;
    }

    try {
      // 加载商品数据
      if (storedProducts is Map<String, dynamic>) {
        final productsList =
            storedProducts['products'] is List
                ? storedProducts['products'] as List
                : [];
        for (final productData in productsList) {
          if (productData is Map<String, dynamic>) {
            addProductFromJson(productData);
          }
        }
      }

      // 加载存档商品
      if (storedArchivedProducts is Map<String, dynamic>) {
        final archivedList =
            storedArchivedProducts['products'] is List
                ? storedArchivedProducts['products'] as List
                : [];
        for (final productData in archivedList) {
          if (productData is Map<String, dynamic>) {
            _archivedProducts.add(Product.fromJson(productData));
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load products: $e');
      await initializeDefaultData();
      return;
    }

    // 加载积分数据
    if (storedPoints is Map<String, dynamic>) {
      _userPoints =
          storedPoints['value'] is int ? storedPoints['value'] as int : 0;
      final logsData = storedPoints['logs'];
      if (logsData is List) {
        _pointsLogs =
            (logsData)
                .whereType<Map<String, dynamic>>()
                .map((log) => PointsLog.fromJson(log))
                .toList();
      }
    }

    // 加载用户物品
    if (storedUserItems is Map<String, dynamic>) {
      final itemsData = storedUserItems['items'];
      if (itemsData is List) {
        _userItems =
            (itemsData)
                .whereType<Map<String, dynamic>>()
                .map((item) => UserItem.fromJson(item))
                .toList();
      }
    }

    // 更新流数据
    _updateStreams();
  }

  // 保存商品数据
  Future<void> saveProducts() async {
    await AboutmeDataService.instance.writePath('store/products.json', {
      'products': productsJson,
    });
  }

  // 保存存档商品数据
  Future<void> saveArchivedProducts() async {
    await AboutmeDataService.instance.writePath('store/archived_products.json', {
      'products': archivedProductsJson,
    });
  }

  // 保存积分数据
  Future<void> savePoints() async {
    await AboutmeDataService.instance.writePath('store/points.json', {
      'value': _userPoints,
      'logs': _pointsLogs.map((log) => log.toJson()).toList(),
    });
  }

  // 保存用户物品数据
  Future<void> saveUserItems() async {
    await AboutmeDataService.instance.writePath('store/user_items.json', {
      'items': _userItems.map((item) => item.toJson()).toList(),
    });
  }

  // 完整保存所有数据
  Future<void> saveToStorage() async {
    await saveProducts();
    await saveArchivedProducts();
    await savePoints();
    await saveUserItems();
    await saveUsedItems();
    _updateStreams();
  }

  // 初始化默认数据
  Future<void> initializeDefaultData() async {
    // 加载默认示例数据
    final defaultData = StoreDefaultData.getAllData();

    // 加载默认商品
    final productsData = defaultData['products'] as Map<String, dynamic>;
    final productsList = productsData['products'] as List;
    for (final productData in productsList) {
      if (productData is Map<String, dynamic>) {
        addProductFromJson(productData);
      }
    }

    // 加载默认积分
    final pointsData = defaultData['points'] as Map<String, dynamic>;
    _userPoints = pointsData['value'] as int;
    final logsList = pointsData['logs'] as List;
    for (final logData in logsList) {
      if (logData is Map<String, dynamic>) {
        _pointsLogs.add(PointsLog.fromJson(logData));
      }
    }

    // 加载默认用户物品
    final userItemsData = defaultData['user_items'] as Map<String, dynamic>;
    final itemsList = userItemsData['items'] as List;
    for (final itemData in itemsList) {
      if (itemData is Map<String, dynamic>) {
        _userItems.add(UserItem.fromJson(itemData));
      }
    }

    // 加载默认已使用物品
    final usedItemsData = defaultData['used_items'] as Map<String, dynamic>;
    final usedItemsList = usedItemsData['items'] as List;
    for (final itemData in usedItemsList) {
      if (itemData is Map<String, dynamic>) {
        _usedItems.add(UsedItem.fromJson(itemData));
      }
    }

    // 保存到存储
    await saveToStorage();

    // 更新流数据
    _updateStreams();
  }

  // 清空用户物品
  Future<void> clearUserItems() async {
    _userItems.clear();
    await saveUserItems();
    _updateStreams();
    notifyListeners();
  }

  // 清空积分记录
  Future<void> clearPointsLogs() async {
    _pointsLogs.clear();
    await savePoints();
    _updateStreams();
    notifyListeners();
  }

  // 应用价格筛选
  void applyPriceFilter(double minPrice, double maxPrice) {
    _products =
        _products
            .where((p) => p.price >= minPrice && p.price <= maxPrice)
            .toList();
    notifyListeners();
  }

  // 应用筛选条件
  void applyFilters({
    String? name,
    String? priceRange,
    DateTimeRange? dateRange,
  }) {
    if (name != null && name.isNotEmpty) {
      _products =
          _products
              .where((p) => p.name.toLowerCase().contains(name.toLowerCase()))
              .toList();
    }

    if (priceRange != null && priceRange.isNotEmpty) {
      final parts = priceRange.split('-');
      if (parts.length == 2) {
        final min = int.tryParse(parts[0]);
        final max = int.tryParse(parts[1]);
        if (min != null && max != null) {
          _products =
              _products.where((p) => p.price >= min && p.price <= max).toList();
        }
      }
    }

    if (dateRange != null) {
      _products =
          _products
              .where(
                (p) =>
                    !p.exchangeEnd.isBefore(dateRange.start) &&
                    !p.exchangeStart.isAfter(dateRange.end),
              )
              .toList();
    }
    notifyListeners();
  }

  // 同步小组件数据
  Future<void> _syncWidget() async {
    await PluginWidgetSyncHelper.instance.syncStore();
  }
}
