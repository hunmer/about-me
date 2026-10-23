import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

// Goods 域业务（与客户端真实布局一致）：
// - warehouses.json: 仓库 ID 列表 {"warehouses": ["id1", "id2"]}
// - warehouse/{id}.json: 仓库详情 {"warehouse": {id, title, iconData,
//   iconColor, imageUrl, items: [...]}}，物品（含嵌套 subItems）内嵌在
//   所属仓库文件中，单物品命令只改写该仓库文件。
// - preferences.json: 视图偏好 {"warehouseSortPreferences": {...}}。
PluginHandlers createGoodsHandlers(PluginData data) {
  const plugin = 'goods';

  Future<List<String>> readWarehouseIds() async {
    final raw = await data.read(plugin, 'warehouses.json');
    if (raw == null) return [];
    if (raw is! Map || raw['warehouses'] is! List) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected warehouses list');
    }
    final ids = <String>[];
    for (final id in raw['warehouses'] as List) {
      if (id is! String || id.isEmpty) {
        throw const DomainFailure('CORRUPT_DATA', 'Invalid warehouse id');
      }
      ids.add(id);
    }
    return ids;
  }

  List<Map<String, dynamic>> normalizeItems(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) {
      throw const DomainFailure('CORRUPT_DATA', 'Invalid warehouse items');
    }
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map || entry['id'] is! String) {
        throw const DomainFailure('CORRUPT_DATA', 'Invalid item');
      }
      final item = Map<String, dynamic>.from(entry);
      final sub = item['subItems'];
      if (sub != null && sub is! List) {
        throw const DomainFailure('CORRUPT_DATA', 'Invalid subItems');
      }
      item['subItems'] = normalizeItems(sub);
      items.add(item);
    }
    return items;
  }

  // 解析 warehouse/{id}.json，物品数组（含嵌套 subItems）规范化为
  // Map<String, dynamic>；结构损坏抛 CORRUPT_DATA。
  Map<String, dynamic> parseWarehouseDoc(dynamic raw) {
    if (raw is! Map || raw['warehouse'] is! Map) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected warehouse object');
    }
    final warehouse = Map<String, dynamic>.from(raw['warehouse'] as Map);
    if (warehouse['id'] is! String) {
      throw const DomainFailure('CORRUPT_DATA', 'Invalid warehouse');
    }
    warehouse['items'] = normalizeItems(warehouse['items']);
    return warehouse;
  }

  // 读取指定仓库；明细文件缺失视为仓库不存在（索引未同步的残留）。
  Future<Map<String, dynamic>> readWarehouse(String id) async {
    final raw = await data.read(plugin, 'warehouse/$id.json');
    if (raw == null) {
      throw const DomainFailure('NOT_FOUND', 'Warehouse not found');
    }
    return parseWarehouseDoc(raw);
  }

  Future<void> writeWarehouse(String id, Map<String, dynamic> warehouse) =>
      data.write(plugin, 'warehouse/$id.json', {'warehouse': warehouse});

  // 遍历所有仓库明细（索引中登记但文件缺失的跳过），返回解析后的仓库。
  Future<List<Map<String, dynamic>>> readAllWarehouseDocs() async {
    final result = <Map<String, dynamic>>[];
    for (final id in await readWarehouseIds()) {
      final raw = await data.read(plugin, 'warehouse/$id.json');
      if (raw == null) continue;
      result.add(parseWarehouseDoc(raw));
    }
    return result;
  }

  // 递归展平物品（含子物品），附加所属仓库 ID。
  List<Map<String, dynamic>> flattenItems(
    List<Map<String, dynamic>> items,
    String warehouseId,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      result.add({...item, 'warehouseId': warehouseId});
      result.addAll(flattenItems(
        List<Map<String, dynamic>>.from(item['subItems'] as List),
        warehouseId,
      ));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> readAllItems() async {
    final result = <Map<String, dynamic>>[];
    for (final warehouse in await readAllWarehouseDocs()) {
      result.addAll(
        flattenItems(
          List<Map<String, dynamic>>.from(warehouse['items'] as List),
          warehouse['id'] as String,
        ),
      );
    }
    return result;
  }

  // 在物品树（含嵌套子物品）中按 id merge 更新，返回是否命中。
  bool replaceItemRecursive(
    List<Map<String, dynamic>> items,
    String id,
    Map<String, dynamic> patch,
  ) {
    for (var i = 0; i < items.length; i++) {
      if (items[i]['id'] == id) {
        items[i] = {...items[i], ...patch};
        return true;
      }
      final sub = List<Map<String, dynamic>>.from(items[i]['subItems'] as List);
      if (sub.isNotEmpty && replaceItemRecursive(sub, id, patch)) {
        items[i]['subItems'] = sub; // 子层级浅拷贝需回写
        return true;
      }
    }
    return false;
  }

  // 在物品树中按 id 删除（含嵌套子物品），返回是否命中。
  bool removeItemRecursive(List<Map<String, dynamic>> items, String id) {
    final before = items.length;
    items.removeWhere((item) => item['id'] == id);
    if (items.length < before) return true;
    for (final item in items) {
      final sub = List<Map<String, dynamic>>.from(item['subItems'] as List);
      if (sub.isNotEmpty && removeItemRecursive(sub, id)) {
        item['subItems'] = sub; // 子层级浅拷贝需回写
        return true;
      }
    }
    return false;
  }

  // 存储格式统一为客户端物品字段（title/notes）；REST 入参的
  // name/description 映射后剔除。
  Map<String, dynamic> itemPatch(Map<String, dynamic> params) {
    final patch = domainPatch(params)
      ..remove('warehouseId')
      ..remove('createdAt');
    if (patch['title'] == null && patch['name'] != null) {
      patch['title'] = patch['name'];
    }
    if (patch['notes'] == null && patch['description'] != null) {
      patch['notes'] = patch['description'];
    }
    patch.remove('name');
    patch.remove('description');
    return patch;
  }

  Future<Map<String, dynamic>> readPreferences() async {
    final raw = await data.read(plugin, 'preferences.json');
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    }
    return Map<String, dynamic>.from(raw);
  }

  return {
    // 获取仓库列表（含内嵌物品）
    'getWarehouses': domainAction((_) async {
      final warehouses = await readAllWarehouseDocs();
      return {'data': warehouses, 'total': warehouses.length};
    }),

    // 获取物品列表（递归含子物品，附加 warehouseId）
    'getList': domainAction((p) async {
      var items = await readAllItems();
      final warehouseId = p['warehouseId'];
      if (warehouseId is String && warehouseId.isNotEmpty) {
        items = items
            .where((i) => i['warehouseId'] == warehouseId)
            .toList();
      }
      return createPaginatedResult(
        items,
        offset: p['offset'] as int?,
        count: p['count'] as int?,
      );
    }),

    // 根据 ID 获取物品
    'getById': domainAction((p) async {
      final items = await readAllItems();
      final index = items.indexWhere((i) => i['id'] == p['id']);
      if (index < 0) {
        throw const DomainFailure('NOT_FOUND', 'Item not found');
      }
      return items[index];
    }),

    // 创建物品：写入所属仓库 items 顶层
    'create': domainAction((p) async {
      final warehouseId = p['warehouseId'];
      if (warehouseId is! String || warehouseId.isEmpty) {
        throw ArgumentError('warehouseId required');
      }
      final warehouse = await readWarehouse(warehouseId);
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      final patch = itemPatch(p);
      final now = jsIsoDateTime(DateTime.now());
      final item = <String, dynamic>{
        'imageUrl': null,
        'thumbUrl': null,
        'iconData': null,
        'iconColor': null,
        'tags': <dynamic>[],
        'purchaseDate': null,
        'expirationDate': null,
        'purchasePrice': null,
        'status': null,
        'usageRecords': <dynamic>[],
        'customFields': <dynamic>[],
        'notes': null,
        'subItems': <dynamic>[],
        ...patch,
        'id': id,
        'quantity': patch.containsKey('quantity') ? patch['quantity'] : 1,
        'createdAt': now,
        'updatedAt': now,
      };
      if (item['title'] is! String || (item['title'] as String).isEmpty) {
        throw ArgumentError('title required');
      }
      (warehouse['items'] as List).add(item);
      await writeWarehouse(warehouseId, warehouse);
      return item;
    }),

    // 更新物品：按 id 在所有仓库物品树中递归 merge
    'update': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final patch = itemPatch(p)
        ..remove('id')
        ..['updatedAt'] = jsIsoDateTime(DateTime.now());
      for (final warehouse in await readAllWarehouseDocs()) {
        final items = List<Map<String, dynamic>>.from(
          warehouse['items'] as List,
        );
        if (replaceItemRecursive(items, id, patch)) {
          final wid = warehouse['id'] as String;
          warehouse['items'] = items;
          await writeWarehouse(wid, warehouse);
          final flat = flattenItems(items, wid);
          return flat.firstWhere(
            (i) => i['id'] == id,
            orElse: () => throw StateError('unreachable'),
          );
        }
      }
      throw const DomainFailure('NOT_FOUND', 'Item not found');
    }),

    // 删除物品：按 id 在所有仓库物品树中递归删除
    'delete': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      for (final warehouse in await readAllWarehouseDocs()) {
        final items = List<Map<String, dynamic>>.from(
          warehouse['items'] as List,
        );
        if (removeItemRecursive(items, id)) {
          final wid = warehouse['id'] as String;
          warehouse['items'] = items;
          await writeWarehouse(wid, warehouse);
          return {'id': id, 'warehouseId': wid};
        }
      }
      throw const DomainFailure('NOT_FOUND', 'Item not found');
    }),

    // 创建仓库：写索引 + 明细文件
    'createWarehouse': domainAction((p) async {
      final ids = await readWarehouseIds();
      final id = p['id'] is String && (p['id'] as String).isNotEmpty
          ? p['id'] as String
          : generateUUID();
      if (ids.contains(id)) {
        throw const DomainFailure('CONFLICT', 'Warehouse exists');
      }
      final now = jsIsoDateTime(DateTime.now());
      final warehouse = <String, dynamic>{
        'title': '未命名仓库',
        'iconData': null,
        'iconColor': null,
        'imageUrl': null,
        ...domainPatch(p)
          ..remove('name')
          ..remove('description')
          ..remove('title'),
        if (p['title'] != null) 'title': p['title'],
        if (p['title'] == null && p['name'] != null) 'title': p['name'],
        'id': id,
        'items': <dynamic>[],
        'createdAt': now,
        'updatedAt': now,
      };
      if (warehouse['title'] == null ||
          (warehouse['title'] as String).isEmpty) {
        warehouse['title'] = '未命名仓库';
      }
      ids.add(id);
      await data.write(plugin, 'warehouses.json', {'warehouses': ids});
      await writeWarehouse(id, warehouse);
      return warehouse;
    }),

    // 更新仓库元数据（改名/图标等）；不触碰内嵌物品
    'updateWarehouse': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final warehouse = await readWarehouse(id);
      final patch = domainPatch(p)
        ..remove('id')
        ..remove('name')
        ..remove('description')
        ..remove('items')
        ..remove('createdAt');
      if (patch['title'] == null) {
        patch.remove('title');
        if (p['name'] != null) patch['title'] = p['name'];
      }
      patch['updatedAt'] = jsIsoDateTime(DateTime.now());
      warehouse.addAll(patch);
      await writeWarehouse(id, warehouse);
      return warehouse;
    }),

    // 删除仓库：更新索引 + 删除明细文件
    'deleteWarehouse': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final ids = await readWarehouseIds();
      if (!ids.contains(id)) {
        throw const DomainFailure('NOT_FOUND', 'Warehouse not found');
      }
      ids.remove(id);
      await data.write(plugin, 'warehouses.json', {'warehouses': ids});
      await data.delete(plugin, 'warehouse/$id.json');
      return {'id': id};
    }),

    // 清空仓库物品（仓库元数据保留）
    'clearWarehouse': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final warehouse = await readWarehouse(id);
      warehouse['items'] = <dynamic>[];
      warehouse['updatedAt'] = jsIsoDateTime(DateTime.now());
      await writeWarehouse(id, warehouse);
      return {'id': id};
    }),

    // 搜索物品（title/notes 关键词，可选仓库过滤）
    'search': domainAction((p) async {
      var items = await readAllItems();
      final keyword = p['keyword'];
      final warehouseId = p['warehouseId'];
      if (warehouseId is String && warehouseId.isNotEmpty) {
        items = items
            .where((i) => i['warehouseId'] == warehouseId)
            .toList();
      }
      if (keyword is String && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        items = items
            .where(
              (i) =>
                  '${i['title'] ?? ''}'.toLowerCase().contains(kw) ||
                  '${i['notes'] ?? ''}'.toLowerCase().contains(kw),
            )
            .toList();
      }
      return {'data': items, 'total': items.length};
    }),

    // 视图偏好
    'getPreferences': domainAction((_) => readPreferences()),
    'updatePreferences': domainAction((p) async {
      final preferences = await readPreferences();
      preferences.addAll(domainPatch(p));
      await data.write(plugin, 'preferences.json', preferences);
      return preferences;
    }),
  };
}
