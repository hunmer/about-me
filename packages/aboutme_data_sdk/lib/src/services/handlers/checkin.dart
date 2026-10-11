import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Checkin 插件专用处理器（移植自 nodejs handlers/checkin.ts）。
//
// 数据格式：items.json 文件包含打卡项目列表，每个项目有嵌套的 checkInRecords

PluginHandlers createCheckinHandlers(PluginData data) {
  // 读取所有打卡项目
  Future<List<Map<String, dynamic>>> readAllItems() async {
    final content = await data.read('checkin', 'items.json');
    if (content is! Map) return [];
    final items = content['items'];
    if (items is! List) return [];
    return List<Map<String, dynamic>>.from(items);
  }

  // 保存所有打卡项目
  Future<void> saveAllItems(List<Map<String, dynamic>> items) {
    return data.write('checkin', 'items.json', {'items': items});
  }

  return {
    // 获取打卡项目列表
    'getList': (data, params) async {
      try {
        final items = await readAllItems();

        return PluginResult.success(
          createPaginatedResult(
            items,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取打卡项目失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final items = await readAllItems();
        final index = items.indexWhere((i) => i['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('打卡项目不存在', 'NOT_FOUND');
        }

        return PluginResult.success(items[index]);
      } catch (e) {
        return PluginResult.failure('获取打卡项目失败: $e');
      }
    },

    // 创建打卡项目
    'create': (data, params) async {
      try {
        final items = await readAllItems();
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final newItem = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'checkInRecords': params['checkInRecords'] ?? <String, dynamic>{},
          'createdAt': now,
          'updatedAt': now,
        };

        items.add(newItem);
        await saveAllItems(items);

        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建打卡项目失败: $e');
      }
    },

    // 更新打卡项目
    'update': (data, params) async {
      try {
        final items = await readAllItems();
        final index = items.indexWhere((i) => i['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('打卡项目不存在', 'NOT_FOUND');
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
        return PluginResult.failure('更新打卡项目失败: $e');
      }
    },

    // 删除打卡项目
    'delete': (data, params) async {
      try {
        final items = await readAllItems();
        final initialLength = items.length;
        final filtered = items.where((i) => i['id'] != params['id']).toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('打卡项目不存在', 'NOT_FOUND');
        }

        await saveAllItems(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除打卡项目失败: $e');
      }
    },

    // 添加签到记录
    'addRecord': (data, params) async {
      try {
        final itemId = params['id'];
        final date = params['date'];
        final note = params['note'];
        final items = await readAllItems();
        final index = items.indexWhere((i) => i['id'] == itemId);

        if (index == -1) {
          return const PluginResult.failure('打卡项目不存在', 'NOT_FOUND');
        }

        final item = items[index];
        final existingRecords = item['checkInRecords'];
        final checkInRecords = existingRecords is Map
            ? Map<String, dynamic>.from(existingRecords)
            : <String, dynamic>{};

        final now = jsIsoDateTime(DateTime.now());
        final newRecord = <String, dynamic>{
          'id': generateUUID(),
          'checkinTime': now,
          if (note != null) 'note': note,
        };

        final dateKey = date.toString();
        var dateRecords = checkInRecords[dateKey];
        if (dateRecords is! List) {
          dateRecords = <dynamic>[];
          checkInRecords[dateKey] = dateRecords;
        }
        dateRecords.add(newRecord);

        final updatedItem = <String, dynamic>{
          ...item,
          'checkInRecords': checkInRecords,
          'updatedAt': now,
        };
        items[index] = updatedItem;

        await saveAllItems(items);
        return PluginResult.success(newRecord);
      } catch (e) {
        return PluginResult.failure('签到失败: $e');
      }
    },

    // 获取统计
    'getStats': (data, params) async {
      try {
        final items = await readAllItems();
        final totalItems = items.length;

        var totalCheckins = 0;
        for (final item in items) {
          final records = item['checkInRecords'];
          if (records is! Map) continue;
          for (final dateRecords in records.values) {
            if (dateRecords is List) {
              totalCheckins += dateRecords.length;
            }
          }
        }

        // 今日统计（toISOString 为 UTC 日期）
        final today = jsIsoDateTime(DateTime.now()).split('T')[0];
        var todayCheckins = 0;
        var todayCompletedItems = 0;

        for (final item in items) {
          final records = item['checkInRecords'];
          final todayRecords = records is Map && records[today] is List
              ? records[today] as List
              : <dynamic>[];
          todayCheckins += todayRecords.length;
          if (todayRecords.isNotEmpty) {
            todayCompletedItems++;
          }
        }

        final completionRate = totalItems > 0
            ? todayCompletedItems / totalItems
            : 0;

        // 按分组统计
        final groupStats = <String, int>{};
        for (final item in items) {
          final groupValue = item['group']?.toString();
          final group = groupValue != null && groupValue.isNotEmpty
              ? groupValue
              : 'default';
          groupStats[group] = (groupStats[group] ?? 0) + 1;
        }

        return PluginResult.success({
          'totalCheckins': totalCheckins,
          'todayCheckins': todayCheckins,
          'totalItems': totalItems,
          'todayCompletedItems': todayCompletedItems,
          'completionRate': completionRate,
          'groupStats': groupStats,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}
