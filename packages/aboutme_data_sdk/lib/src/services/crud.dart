import 'plugin_data.dart';
import 'types.dart';
import 'utils.dart';

/// 通用 CRUD 处理器：数据格式 `{resourceName: [...items]}`。
///
/// 写回时保留文件中的其它字段（如客户端存于同一文件的
/// completedTasks/viewMode 等），确保与客户端整文件写回共存不丢数据。
PluginHandlers createCrudHandlers(
  PluginData data,
  String pluginId,
  String resourceName, [
  String dataFile = 'data.json',
]) {
  Future<Map<String, dynamic>> readFile() async {
    final content = await data.read(pluginId, dataFile);
    return content is Map<String, dynamic> ? content : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> readItems() async {
    final file = await readFile();
    final items = file[resourceName];
    return items is List
        ? List<Map<String, dynamic>>.from(items)
        : <Map<String, dynamic>>[];
  }

  Future<void> writeItems(Map<String, dynamic> file, List<dynamic> items) {
    file[resourceName] = items;
    return data.write(pluginId, dataFile, file);
  }

  return {
    'getList': (data, params) async {
      try {
        final result = createPaginatedResult(
          await readItems(),
          offset: params['offset'] as int?,
          count: params['count'] as int?,
        );
        return PluginResult.success(result);
      } catch (e) {
        return PluginResult.failure('读取数据失败: $e');
      }
    },
    'getById': (data, params) async {
      try {
        final items = await readItems();
        final item = items.where((i) => i['id'] == params['id']).firstOrNull;
        if (item == null) {
          return const PluginResult.failure('项目不存在', 'NOT_FOUND');
        }
        return PluginResult.success(item);
      } catch (e) {
        return PluginResult.failure('读取数据失败: $e');
      }
    },
    'create': (data, params) async {
      try {
        final file = await readFile();
        final items = [
          ...(file[resourceName] is List ? file[resourceName] as List : []),
        ];
        final now = jsIsoDateTime(DateTime.now());
        final newItem = {
          ...params,
          'id': (params['id'] as String?) ?? generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };
        items.add(newItem);
        await writeItems(file, items);
        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建失败: $e');
      }
    },
    'update': (data, params) async {
      try {
        final file = await readFile();
        final items = [
          ...(file[resourceName] is List ? file[resourceName] as List : []),
        ];
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
        await writeItems(file, items);
        return PluginResult.success(updatedItem);
      } catch (e) {
        return PluginResult.failure('更新失败: $e');
      }
    },
    'delete': (data, params) async {
      try {
        final file = await readFile();
        final items = [
          ...(file[resourceName] is List ? file[resourceName] as List : []),
        ];
        final index = items.indexWhere((i) => i['id'] == params['id']);
        if (index == -1) {
          return const PluginResult.failure('项目不存在', 'NOT_FOUND');
        }
        items.removeAt(index);
        await writeItems(file, items);
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
