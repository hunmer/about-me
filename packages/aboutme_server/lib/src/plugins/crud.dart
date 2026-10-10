import 'package:aboutme_data_sdk/io.dart';

import 'types.dart';
import 'utils.dart';

/// 通用 CRUD 处理器（数据格式 {resourceName: [...items]}），
/// 供无专用 handler 的插件使用，语义与 nodejs crud.ts 一致。
PluginHandlers createCrudHandlers(
  PluginDataStore store,
  String pluginId,
  String resourceName, [
  String dataFile = 'data.json',
]) {
  Future<List<Map<String, dynamic>>> readItems(
    String userId,
    String encryptionKey,
  ) async {
    final data = await store.readPluginData(
      userId,
      pluginId,
      dataFile,
      encryptionKey,
    );
    if (data is List) return List<Map<String, dynamic>>.from(data);
    if (data is Map && data[resourceName] is List) {
      return List<Map<String, dynamic>>.from(data[resourceName]);
    }
    return [];
  }

  Future<void> writeItems(
    String userId,
    String encryptionKey,
    List<Map<String, dynamic>> items,
  ) {
    return store.writePluginData(
      userId,
      pluginId,
      dataFile,
      {resourceName: items},
      encryptionKey,
    );
  }

  return {
    'getList': (userId, encryptionKey, params) async {
      try {
        final items = await readItems(userId, encryptionKey);
        return PluginResult.success(
          createPaginatedResult(
            items,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('读取数据失败: $e');
      }
    },
    'getById': (userId, encryptionKey, params) async {
      try {
        final items = await readItems(userId, encryptionKey);
        final item = items.where((i) => i['id'] == params['id']).firstOrNull;
        if (item == null) {
          return const PluginResult.failure('项目不存在', 'NOT_FOUND');
        }
        return PluginResult.success(item);
      } catch (e) {
        return PluginResult.failure('读取数据失败: $e');
      }
    },
    'create': (userId, encryptionKey, params) async {
      try {
        final items = [...await readItems(userId, encryptionKey)];
        final now = jsIsoDateTime(DateTime.now());
        final newItem = {
          ...params,
          'id': (params['id'] as String?) ?? generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };
        items.add(newItem);
        await writeItems(userId, encryptionKey, items);
        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建失败: $e');
      }
    },
    'update': (userId, encryptionKey, params) async {
      try {
        final items = [...await readItems(userId, encryptionKey)];
        final index = items.indexWhere((i) => i['id'] == params['id']);
        if (index == -1) {
          return const PluginResult.failure('项目不存在', 'NOT_FOUND');
        }
        final updatedItem = {
          ...items[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        items[index] = updatedItem;
        await writeItems(userId, encryptionKey, items);
        return PluginResult.success(updatedItem);
      } catch (e) {
        return PluginResult.failure('更新失败: $e');
      }
    },
    'delete': (userId, encryptionKey, params) async {
      try {
        final items = [...await readItems(userId, encryptionKey)];
        final index = items.indexWhere((i) => i['id'] == params['id']);
        if (index == -1) {
          return const PluginResult.failure('项目不存在', 'NOT_FOUND');
        }
        items.removeAt(index);
        await writeItems(userId, encryptionKey, items);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除失败: $e');
      }
    },
  };
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
