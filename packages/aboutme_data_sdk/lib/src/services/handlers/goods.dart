import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Goods 插件专用处理器（移植自 nodejs handlers/goods.ts）。
//
// 数据格式：
// - warehouses.json: 仓库 ID 列表 {"warehouses": ["id1", "id2"]}
// - warehouse/{id}.json: 仓库详情 {"warehouse": {...}}
// - items.json: 物品列表 {"items": [...]}（旧格式兼容）

PluginHandlers createGoodsHandlers(PluginData data) {
  // 读取所有仓库
  Future<List<Map<String, dynamic>>> readAllWarehouses() async {
    final warehousesData = await data.read('goods', 'warehouses.json');
    if (warehousesData is! Map) return [];

    // 仓库 ID 列表
    final warehouseIds = warehousesData['warehouses'];
    if (warehouseIds is! List) return [];

    final warehouses = <Map<String, dynamic>>[];
    for (final id in warehouseIds) {
      final warehouseData = await data.read('goods', 'warehouse/$id.json');
      final warehouse = warehouseData is Map
          ? warehouseData['warehouse']
          : null;
      if (warehouse is Map<String, dynamic>) {
        warehouses.add(warehouse);
      }
    }

    return warehouses;
  }

  // 读取所有物品（从仓库中提取）
  Future<List<Map<String, dynamic>>> readAllItems() async {
    // 首先尝试从仓库中提取物品
    final warehouses = await readAllWarehouses();
    final allItems = <Map<String, dynamic>>[];

    for (final warehouse in warehouses) {
      final items = warehouse['items'];
      if (items is! List) continue;
      // 为每个物品添加 warehouseId
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          allItems.add({...item, 'warehouseId': warehouse['id']});
        }
      }
    }

    // 如果仓库中有物品，返回仓库中的物品
    if (allItems.isNotEmpty) {
      return allItems;
    }

    // 否则尝试从 items.json 读取（兼容旧格式）
    final content = await data.read('goods', 'items.json');
    if (content is! Map) return [];
    final items = content['items'];
    if (items is! List) return [];
    return List<Map<String, dynamic>>.from(items);
  }

  // 保存所有物品
  Future<void> saveAllItems(List<Map<String, dynamic>> items) {
    return data.write('goods', 'items.json', {'items': items});
  }

  return {
    // 获取仓库列表
    'getWarehouses': (data, params) async {
      try {
        final warehouses = await readAllWarehouses();
        return PluginResult.success({
          'data': warehouses,
          'total': warehouses.length,
        });
      } catch (e) {
        return PluginResult.failure('获取仓库失败: $e');
      }
    },

    // 获取物品列表
    'getList': (data, params) async {
      try {
        var items = await readAllItems();

        // 按仓库过滤
        final warehouseId = params['warehouseId'] as String?;
        if (warehouseId != null && warehouseId.isNotEmpty) {
          items = items.where((i) => i['warehouseId'] == warehouseId).toList();
        }

        return PluginResult.success(
          createPaginatedResult(
            items,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取物品失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final items = await readAllItems();
        final index = items.indexWhere((i) => i['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('物品不存在', 'NOT_FOUND');
        }

        return PluginResult.success(items[index]);
      } catch (e) {
        return PluginResult.failure('获取物品失败: $e');
      }
    },

    // 创建物品
    'create': (data, params) async {
      try {
        final items = await readAllItems();
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final quantity = params['quantity'];
        final newItem = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'quantity': quantity == null || quantity == 0 ? 1 : quantity,
          'createdAt': now,
          'updatedAt': now,
        };

        items.add(newItem);
        await saveAllItems(items);

        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建物品失败: $e');
      }
    },

    // 更新物品
    'update': (data, params) async {
      try {
        final items = await readAllItems();
        final index = items.indexWhere((i) => i['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('物品不存在', 'NOT_FOUND');
        }

        final updatedItem = <String, dynamic>{
          ...items[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        items[index] = updatedItem;

        await saveAllItems(items);
        return PluginResult.success(updatedItem);
      } catch (e) {
        return PluginResult.failure('更新物品失败: $e');
      }
    },

    // 删除物品
    'delete': (data, params) async {
      try {
        final items = await readAllItems();
        final initialLength = items.length;
        final filtered = items.where((i) => i['id'] != params['id']).toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('物品不存在', 'NOT_FOUND');
        }

        await saveAllItems(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除物品失败: $e');
      }
    },

    // 搜索物品
    'search': (data, params) async {
      try {
        var items = await readAllItems();

        final keyword = params['keyword'];
        final warehouseId = params['warehouseId'];

        if (warehouseId != null && warehouseId.toString().isNotEmpty) {
          items = items.where((i) => i['warehouseId'] == warehouseId).toList();
        }
        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          items = items
              .where(
                (i) =>
                    (i['name'] ?? '').toString().toLowerCase().contains(kw) ||
                    (i['description'] ?? '').toString().toLowerCase().contains(
                      kw,
                    ),
              )
              .toList();
        }

        return PluginResult.success({'data': items, 'total': items.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },
  };
}
