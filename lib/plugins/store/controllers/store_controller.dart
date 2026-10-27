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

    // 兑换为单事务命令：扣库存+扣积分+写流水+加用户物品，业务失败则全部不写入
    final result = await AboutmeDataService.instance.call('store', 'purchase', {
      'productId': product.id,
      'clientMutationId': 'store:purchase:${product.id}:${const Uuid().v4()}',
    });
    if (result['success'] != true) return false;
    final payload = Map<String, dynamic>.from(result['data'] as Map);

    // 应用服务端提交结果到内存
    _userPoints = payload['value'] as int;
    final logMap = payload['log'] as Map?;
    if (logMap != null && !_pointsLogs.any((l) => l.id == logMap['id'])) {
      _pointsLogs.add(PointsLog.fromJson(Map<String, dynamic>.from(logMap)));
    }
    final productMap = payload['product'] as Map?;
    final index = _products.indexOf(product);
    if (index >= 0 && productMap != null) {
      _products[index] = Product.fromJson(
        Map<String, dynamic>.from(productMap),
      );
    }

    // 添加用户物品（基础数据经 base 引用商品列表，不再快照复制）
    final newItem = UserItem.fromJson(
      Map<String, dynamic>.from(payload['userItem'] as Map),
    )..base = product;
    _userItems.add(newItem);

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

    // 使用为单事务命令：写使用记录 + 扣减剩余次数，业务失败则全部不写入
    final result = await AboutmeDataService.instance.call('store', 'useItem', {
      'id': item.id,
      'clientMutationId': 'store:use:${item.id}:${const Uuid().v4()}',
    });
    if (result['success'] != true) return false;
    final payload = Map<String, dynamic>.from(result['data'] as Map);

    // 应用服务端提交结果到内存
    _usedItems.add(
      UsedItem.fromJson(Map<String, dynamic>.from(payload['usedItem'] as Map)),
    );
    final remainingMap = payload['userItem'] as Map?;
    if (remainingMap == null) {
      _userItems.remove(item);
    } else {
      item.remaining = remainingMap['remaining'] as int;
    }
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
    await AboutmeDataService.instance.call('store', 'saveUsedItems', {
      'items': _usedItems.map((item) => item.toJson()).toList(),
    });
  }

  // 加载已使用物品
  Future<void> loadUsedItems() async {
    final result = await AboutmeDataService.instance.get(
      'store',
      'getUsedItems',
    );
    if (result['success'] != true) return;
    final itemsData = (result['data'] as Map)['data'];
    if (itemsData is List) {
      _usedItems.clear();
      _usedItems.addAll(
        itemsData
            .whereType<Map<String, dynamic>>()
            .map((item) => UsedItem.fromJson(item))
            .toList(),
      );
    }
  }

  // 添加积分（[clientMutationId] 提供时同一命令重试命中幂等缓存，
  // 返回首次结果并跳过重复入账与提醒）
  Future<void> addPoints(
    int value,
    String reason, {
    String? clientMutationId,
  }) async {
    final result = await AboutmeDataService.instance.call('store', 'addPoints', {
      'value': value,
      'reason': reason,
      if (clientMutationId != null) 'clientMutationId': clientMutationId,
    });
    if (result['success'] != true) {
      throw StateError('addPoints 失败: ${result['error']}');
    }
    final payload = Map<String, dynamic>.from(result['data'] as Map);
    final logMap = payload['log'] as Map?;
    final isReplay =
        logMap != null && _pointsLogs.any((l) => l.id == logMap['id']);
    _userPoints = payload['value'] as int;
    if (!isReplay && logMap != null) {
      _pointsLogs.add(PointsLog.fromJson(Map<String, dynamic>.from(logMap)));
    }
    _updateStreams();
    notifyListeners();

    // 触发积分变化事件（始终触发，供其他插件监听）
    _notifyPointsEvent(value, reason);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();

    // 检查是否启用积分变动通知（toast 提示；幂等重放不重复提示）
    final enablePointsNotification =
        plugin.settings['enablePointsNotification'] as bool? ?? true;
    if (enablePointsNotification && !isReplay) {
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

  // 新建商品（单行命令，避免整表覆盖并发修改）
  Future<bool> createProductRow(Product product) async {
    final res = await AboutmeDataService.instance.call(
      'store',
      'createProduct',
      product.toJson(),
    );
    if (res['success'] != true) {
      debugPrint('Failed to create product: ${res['error']}');
      return false;
    }
    final saved = Product.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
    _products.add(saved);
    _updateStreams();
    notifyListeners();
    _notifyProductEvent('added', saved);
    _notifyCacheUpdatedEvent();
    return true;
  }

  // 更新商品（单行命令，避免整表覆盖并发修改）
  Future<bool> updateProductRow(Product product) async {
    final res = await AboutmeDataService.instance.call(
      'store',
      'updateProduct',
      product.toJson(),
    );
    if (res['success'] != true) {
      debugPrint('Failed to update product: ${res['error']}');
      return false;
    }
    final saved = Product.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
    final index = _products.indexWhere((p) => p.id == saved.id);
    if (index >= 0) _products[index] = saved;
    _updateStreams();
    notifyListeners();
    _notifyProductEvent('updated', saved);
    _notifyCacheUpdatedEvent();
    return true;
  }

  // 删除商品（单行命令真删，不进存档）
  Future<bool> deleteProductRow(String id) async {
    final res = await AboutmeDataService.instance.call(
      'store',
      'deleteProduct',
      {'id': id},
    );
    if (res['success'] != true) {
      debugPrint('Failed to delete product: ${res['error']}');
      return false;
    }
    _products.removeWhere((p) => p.id == id);
    _updateStreams();
    notifyListeners();
    _notifyCacheUpdatedEvent();
    return true;
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

  // 存档产品（单事务命令，避免双整表覆盖并发修改）
  Future<void> archiveProduct(Product product) async {
    final res = await AboutmeDataService.instance.call(
      'store',
      'archiveProduct',
      {'id': product.id},
    );
    if (res['success'] != true) {
      debugPrint('Failed to archive product: ${res['error']}');
      return;
    }
    _products.removeWhere((p) => p.id == product.id);
    _archivedProducts.add(product);
    notifyListeners();

    // 触发商品归档事件
    _notifyProductEvent('archived', product);

    // 触发缓存更新事件
    _notifyCacheUpdatedEvent();
  }

  // 恢复存档产品（单事务命令，避免双整表覆盖并发修改）
  Future<void> restoreProduct(Product product) async {
    final res = await AboutmeDataService.instance.call(
      'store',
      'restoreProduct',
      {'id': product.id},
    );
    if (res['success'] != true) {
      debugPrint('Failed to restore product: ${res['error']}');
      return;
    }
    _archivedProducts.removeWhere((p) => p.id == product.id);
    _products.add(product);
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
    final snapshotResult = await AboutmeDataService.instance.get(
      'store',
      'getSnapshot',
    );
    if (snapshotResult['success'] != true) {
      debugPrint('Failed to load store snapshot: ${snapshotResult['error']}');
      return;
    }
    final snapshot = Map<String, dynamic>.from(snapshotResult['data'] as Map);
    final productsList = snapshot['products'] as List? ?? [];
    final archivedList = snapshot['archivedProducts'] as List? ?? [];
    final pointsValue = snapshot['value'] as int? ?? 0;
    final logsData = snapshot['logs'] as List? ?? [];
    final itemsData = snapshot['userItems'] as List? ?? [];
    final usedItemsData = snapshot['usedItems'] as List? ?? [];

    _products.clear();
    _archivedProducts.clear();
    _pointsLogs.clear();
    _userItems.clear();
    _usedItems.clear();

    // 检查是否有数据，没有则初始化默认数据
    // 注意：积分以文件是否存在判定（而非值是否为 0），与旧 readPath 行为一致
    final hasProducts = productsList.isNotEmpty;
    final hasPoints = snapshot['pointsFileExists'] == true;
    final hasUserItems = itemsData.isNotEmpty;

    // 首次打开无数据时保持为空，由引导页「示例数据选择」决定是否导入示例数据
    if (!hasProducts && !hasPoints && !hasUserItems) {
      debugPrint('No existing data found, keep empty for onboarding');
      return;
    }

    try {
      // 加载商品数据
      for (final productData in productsList) {
        if (productData is Map<String, dynamic>) {
          addProductFromJson(productData);
        }
      }

      // 加载存档商品
      for (final productData in archivedList) {
        if (productData is Map<String, dynamic>) {
          _archivedProducts.add(Product.fromJson(productData));
        }
      }
    } catch (e) {
      debugPrint('Failed to load products: $e');
      return;
    }

    // 加载积分数据
    _userPoints = pointsValue;
    _pointsLogs =
        logsData
            .whereType<Map<String, dynamic>>()
            .map((log) => PointsLog.fromJson(log))
            .toList();

    // 加载用户物品
    _userItems =
        itemsData
            .whereType<Map<String, dynamic>>()
            .map((item) => UserItem.fromJson(item))
            .toList();

    // 加载已使用物品
    _usedItems.addAll(
      usedItemsData
          .whereType<Map<String, dynamic>>()
          .map((item) => UsedItem.fromJson(item))
          .toList(),
    );

    // 更新流数据
    _updateStreams();
  }

  // 保存商品数据
  Future<void> saveProducts() async {
    await AboutmeDataService.instance.call('store', 'saveProducts', {
      'products': productsJson,
    });
  }

  // 保存存档商品数据
  Future<void> saveArchivedProducts() async {
    await AboutmeDataService.instance.call('store', 'saveArchivedProducts', {
      'products': archivedProductsJson,
    });
  }

  // 保存积分数据
  Future<void> savePoints() async {
    await AboutmeDataService.instance.call('store', 'savePoints', {
      'value': _userPoints,
      'logs': _pointsLogs.map((log) => log.toJson()).toList(),
    });
  }

  // 保存用户物品数据
  Future<void> saveUserItems() async {
    await AboutmeDataService.instance.call('store', 'saveUserItems', {
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

  // 初始化默认数据（导入示例商品、积分、用户物品）
  Future<void> initializeDefaultData() async {
    _products.addAll(getDefaultProducts());
    _userPoints = getDefaultPointsBalance();
    _pointsLogs.addAll(getDefaultPointsLogs());
    _userItems.addAll(getDefaultUserItems());
    _usedItems.addAll(getDefaultUsedItems());

    // 保存到存储
    await saveToStorage();

    // 更新流数据
    _updateStreams();
  }

  // 清空用户物品
  Future<void> clearUserItems() async {
    _userItems.clear();
    await AboutmeDataService.instance.call('store', 'clearUserItems');
    _updateStreams();
    notifyListeners();
  }

  // 清空积分记录
  Future<void> clearPointsLogs() async {
    _pointsLogs.clear();
    await AboutmeDataService.instance.call('store', 'clearPointsLogs');
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
