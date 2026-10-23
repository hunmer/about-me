import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

/// Store 域业务：商品/归档商品/积分/用户物品/已使用物品五集合，
/// 文件格式与旧客户端一致（products.json 与 archived_products.json 均为
/// {products:[...]}，points.json 为 {value,logs}，user_items.json 与
/// used_items.json 为 {items:[...]}，行内字段为 snake_case）。
/// 主集合首次成功写前把原始文件快照到 migration_v1_backup.json
/// （used_items 流水不纳入快照）。
/// purchase/redeem 与 useItem 在单事务内完成多文件一致更新，
/// 业务校验失败（积分不足/库存不足/过期等）返回失败且全部不写入；
/// addPoints 的幂等由 SDK 事务层 clientMutationId 保证：
/// 同一 mutationId 重试直接返回首次结果，不重复加分。
PluginHandlers createStoreHandlers(PluginData data) {
  const plugin = 'store';

  Future<List<Map<String, dynamic>>> readRows(String file, String key) async {
    final raw = await data.read(plugin, file);
    if (raw == null) return [];
    final rows = raw is List ? raw : raw is Map ? raw[key] : null;
    if (rows is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final result = <Map<String, dynamic>>[];
    for (final e in rows) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/$file row');
      result.add(Map<String, dynamic>.from(e));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> readProducts() =>
      readRows('products.json', 'products');
  Future<List<Map<String, dynamic>>> readArchived() =>
      readRows('archived_products.json', 'products');
  Future<List<Map<String, dynamic>>> readUserItems() =>
      readRows('user_items.json', 'items');
  Future<List<Map<String, dynamic>>> readUsedItems() =>
      readRows('used_items.json', 'items');

  Future<(int, List<Map<String, dynamic>>)> readPoints() async {
    final raw = await data.read(plugin, 'points.json');
    if (raw == null) return (0, <Map<String, dynamic>>[]);
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    final value = raw['value'];
    if (value != null && value is! int) {
      throw const DomainFailure('CORRUPT_DATA', 'Invalid points value');
    }
    final logs = raw['logs'];
    if (logs == null) return (value as int? ?? 0, <Map<String, dynamic>>[]);
    if (logs is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final rows = <Map<String, dynamic>>[];
    for (final e in logs) {
      if (e is! Map || e['id'] is! String)
        throw const DomainFailure('CORRUPT_DATA', 'Invalid points log');
      rows.add(Map<String, dynamic>.from(e));
    }
    return (value as int? ?? 0, rows);
  }

  /// 入参行列表校验（整表保存动作用）。
  List<Map<String, dynamic>> rowsOf(dynamic value, String what) {
    if (value is! List)
      throw ArgumentError('$what 必须为数组');
    final rows = <Map<String, dynamic>>[];
    for (final e in value) {
      if (e is! Map || e['id'] is! String)
        throw const DomainFailure('CORRUPT_DATA', 'Invalid row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  Future<void> backup() async {
    if (await data.read(plugin, 'migration_v1_backup.json') != null) return;
    await data.write(plugin, 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'products': await data.read(plugin, 'products.json'),
      'archived_products': await data.read(plugin, 'archived_products.json'),
      'points': await data.read(plugin, 'points.json'),
      'user_items': await data.read(plugin, 'user_items.json'),
    });
  }

  Future<void> saveProducts(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'products.json', {'products': rows});
  }

  Future<void> saveArchived(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'archived_products.json', {'products': rows});
  }

  Future<void> savePoints(int value, List<Map<String, dynamic>> logs) async {
    await backup();
    await data.write(plugin, 'points.json', {'value': value, 'logs': logs});
  }

  Future<void> saveUserItems(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'user_items.json', {'items': rows});
  }

  // used_items 为使用流水（同 habits 记录分文件），不纳入首写备份。
  Future<void> saveUsedItems(List<Map<String, dynamic>> rows) async {
    await data.write(plugin, 'used_items.json', {'items': rows});
  }

  void checkId(dynamic value, String what) {
    if (value is! String || value.isEmpty) throw ArgumentError('$what required');
  }

  Map<String, dynamic> patchOf(Map<String, dynamic> p) => domainPatch(p)
    ..remove('id')
    ..remove('productId')
    ..remove('itemId');

  int intOf(dynamic value) => domainNumber(value).toInt();

  /// 兑换：扣库存 + 扣积分 + 写流水 + 加用户物品，单事务一致。
  Future<Map<String, dynamic>> runPurchase(Map<String, dynamic> p) async {
    final productId = p['productId'] ?? p['id'];
    checkId(productId, 'productId');
    final rows = await readProducts();
    final i = rows.indexWhere((e) => e['id'] == productId);
    if (i < 0) throw const DomainFailure('NOT_FOUND', 'Product not found');
    final product = rows[i];
    final stock = intOf(product['stock']);
    final price = intOf(product['price']);
    if (price < 0) throw const DomainFailure('CORRUPT_DATA', 'Invalid price');
    if (stock <= 0)
      throw const DomainFailure('INVALID_PARAMS', '库存不足');
    final now = DateTime.now();
    final start = DateTime.tryParse('${product['exchange_start'] ?? ''}');
    final end = DateTime.tryParse('${product['exchange_end'] ?? ''}');
    if (start == null || end == null)
      throw const DomainFailure('CORRUPT_DATA', 'Invalid exchange window');
    if (now.isBefore(start) || now.isAfter(end))
      throw const DomainFailure('INVALID_PARAMS', '不在兑换时间内');
    final (value, logs) = await readPoints();
    if (value < price)
      throw const DomainFailure('INVALID_PARAMS', '积分不足');
    rows[i] = {...product, 'stock': stock - 1};
    await saveProducts(rows);
    final log = <String, dynamic>{
      'id': generateUUID(),
      'type': '消耗',
      'value': price,
      'reason': '兑换商品: ${product['name']}',
      'timestamp': now.toIso8601String(),
    };
    final newValue = value - price;
    await savePoints(newValue, [...logs, log]);
    final userItems = await readUserItems();
    final item = <String, dynamic>{
      'id': p['itemId'] ?? generateUUID(),
      'product_id': productId,
      'remaining': 1,
      'expire_date': now
          .add(Duration(days: intOf(product['use_duration'])))
          .toIso8601String(),
      'purchase_date': now.toIso8601String(),
      'purchase_price': price,
    };
    userItems.add(item);
    await saveUserItems(userItems);
    return {
      'product': rows[i],
      'userItem': item,
      'value': newValue,
      'log': log,
    };
  }

  return {
    'getSnapshot': domainAction((_) async {
      final (value, logs) = await readPoints();
      return {
        'products': await readProducts(),
        'archivedProducts': await readArchived(),
        'value': value,
        'logs': logs,
        // 客户端空数据回落默认示例数据的判定依赖文件是否存在（而非值是否为 0）
        'pointsFileExists':
            await data.read(plugin, 'points.json') != null,
        'userItems': await readUserItems(),
        'usedItems': await readUsedItems(),
      };
    }),
    // ==================== 商品 ====================
    'getProducts': domainAction((p) async {
      final rows = await readProducts();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'createProduct': domainAction((p) async {
      final rows = await readProducts();
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Product exists');
      final now = DateTime.now();
      final product = <String, dynamic>{
        'description': '',
        'image': null,
        'category': null,
        'stock': 0,
        'price': 0,
        'exchange_start': now.toIso8601String(),
        'exchange_end':
            now.add(const Duration(days: 3650)).toIso8601String(),
        'use_duration': 0,
        ...patchOf(p),
        'id': id,
      };
      if (product['name'] is! String || (product['name'] as String).isEmpty)
        throw ArgumentError('name required');
      for (final key in ['stock', 'price', 'use_duration']) {
        product[key] = intOf(product[key]);
        if ((product[key] as int) < 0) throw ArgumentError('$key invalid');
      }
      for (final key in ['exchange_start', 'exchange_end']) {
        if (DateTime.tryParse('${product[key]}') == null)
          throw ArgumentError('$key invalid');
      }
      rows.add(product);
      await saveProducts(rows);
      return product;
    }),
    'updateProduct': domainAction((p) async {
      final rows = await readProducts();
      final i = domainIndex(rows, p['id']);
      rows[i] = {...rows[i], ...patchOf(p)};
      for (final key in ['stock', 'price', 'use_duration']) {
        if (rows[i].containsKey(key)) {
          rows[i][key] = intOf(rows[i][key]);
          if ((rows[i][key] as int) < 0) throw ArgumentError('$key invalid');
        }
      }
      await saveProducts(rows);
      return rows[i];
    }),
    'deleteProduct': domainAction((p) async {
      final rows = await readProducts();
      rows.removeAt(domainIndex(rows, p['id']));
      await saveProducts(rows);
      return {'id': p['id']};
    }),
    'saveProducts': domainAction((p) async {
      final rows = rowsOf(p['products'], 'products');
      await saveProducts(rows);
      return {'count': rows.length};
    }),
    'archiveProduct': domainAction((p) async {
      final rows = await readProducts();
      final archived = await readArchived();
      final product = rows.removeAt(domainIndex(rows, p['id']));
      if (archived.any((e) => e['id'] == product['id']))
        throw const DomainFailure('CONFLICT', 'Product already archived');
      archived.add(product);
      await saveProducts(rows);
      await saveArchived(archived);
      return product;
    }),
    'restoreProduct': domainAction((p) async {
      final archived = await readArchived();
      final rows = await readProducts();
      final product = archived.removeAt(domainIndex(archived, p['id']));
      if (rows.any((e) => e['id'] == product['id']))
        throw const DomainFailure('CONFLICT', 'Product exists');
      rows.add(product);
      await saveArchived(archived);
      await saveProducts(rows);
      return product;
    }),
    'getArchivedProducts': domainAction((p) async {
      final rows = await readArchived();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'saveArchivedProducts': domainAction((p) async {
      final rows = rowsOf(p['products'], 'products');
      await saveArchived(rows);
      return {'count': rows.length};
    }),
    // ==================== 积分 ====================
    'getPoints': domainAction((_) async {
      final (value, logs) = await readPoints();
      return {'value': value, 'logs': logs};
    }),
    'addPoints': domainAction((p) async {
      if (p['value'] == null && p['points'] == null)
        throw ArgumentError('value required');
      final reason = p['reason'];
      if (reason is! String || reason.isEmpty)
        throw ArgumentError('reason required');
      final value = intOf(p['value'] ?? p['points']);
      final (current, logs) = await readPoints();
      final log = <String, dynamic>{
        'id': generateUUID(),
        'type': value > 0 ? '获得' : '失去',
        'value': value,
        'reason': reason,
        'timestamp': p['timestamp'] ?? DateTime.now().toIso8601String(),
      };
      final newValue = current + value;
      await savePoints(newValue, [...logs, log]);
      return {'value': newValue, 'log': log};
    }),
    'savePoints': domainAction((p) async {
      if (p['value'] is! int) throw ArgumentError('value required');
      final logs = rowsOf(p['logs'], 'logs');
      await savePoints(p['value'] as int, logs);
      return {'count': logs.length};
    }),
    'clearPointsLogs': domainAction((_) async {
      final (value, _) = await readPoints();
      await savePoints(value, []);
      return {'value': value};
    }),
    // ==================== 兑换与使用 ====================
    'purchase': domainAction(runPurchase),
    'redeem': domainAction(runPurchase),
    'useItem': domainAction((p) async {
      final id = p['id'] ?? p['itemId'];
      checkId(id, 'id');
      final items = await readUserItems();
      final i = items.indexWhere((e) => e['id'] == id);
      if (i < 0) throw const DomainFailure('NOT_FOUND', 'User item not found');
      final item = items[i];
      final expire = DateTime.tryParse('${item['expire_date'] ?? ''}');
      if (expire == null)
        throw const DomainFailure('CORRUPT_DATA', 'Invalid expire_date');
      if (DateTime.now().isAfter(expire))
        throw const DomainFailure('INVALID_PARAMS', '物品已过期');
      // 使用记录冻结当时的基础数据：商品 → 归档 → 旧快照 → 空
      var snapshot = <String, dynamic>{};
      final live = (await readProducts());
      var j = live.indexWhere((e) => e['id'] == item['product_id']);
      if (j >= 0) {
        snapshot = Map<String, dynamic>.from(live[j]);
      } else {
        final archived = await readArchived();
        j = archived.indexWhere((e) => e['id'] == item['product_id']);
        if (j >= 0) {
          snapshot = Map<String, dynamic>.from(archived[j]);
        } else if (item['product_snapshot'] is Map) {
          snapshot = Map<String, dynamic>.from(item['product_snapshot'] as Map);
        }
      }
      final used = <String, dynamic>{
        'id': id,
        'product_id': item['product_id'],
        'use_date': DateTime.now().toIso8601String(),
        'product_snapshot': snapshot,
      };
      final usedRows = await readUsedItems();
      usedRows.add(used);
      await saveUsedItems(usedRows);
      final remaining = intOf(item['remaining']) - 1;
      if (remaining <= 0) {
        items.removeAt(i);
      } else {
        items[i] = {...item, 'remaining': remaining};
      }
      await saveUserItems(items);
      return {
        'usedItem': used,
        'userItem': remaining > 0 ? items[i] : null,
      };
    }),
    // ==================== 用户物品与使用记录 ====================
    'getUserItems': domainAction((p) async {
      var rows = await readUserItems();
      if (p['productId'] != null) {
        rows = rows.where((e) => e['product_id'] == p['productId']).toList();
      }
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'saveUserItems': domainAction((p) async {
      final rows = rowsOf(p['items'], 'items');
      await saveUserItems(rows);
      return {'count': rows.length};
    }),
    'deleteUserItem': domainAction((p) async {
      final rows = await readUserItems();
      rows.removeAt(domainIndex(rows, p['id']));
      await saveUserItems(rows);
      return {'id': p['id']};
    }),
    'clearUserItems': domainAction((_) async {
      await saveUserItems([]);
      return {'count': 0};
    }),
    'getUsedItems': domainAction((p) async {
      final rows = await readUsedItems();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'saveUsedItems': domainAction((p) async {
      final rows = rowsOf(p['items'], 'items');
      await saveUsedItems(rows);
      return {'count': rows.length};
    }),
  };
}
