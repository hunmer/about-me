import 'package:aboutme_data_sdk/io.dart';

import '../types.dart';
import '../utils.dart';

// Todo 插件专用处理器（移植自 nodejs handlers/todo.ts）。
//
// 数据格式：tasks.json 文件包含任务列表 {"tasks": [...]}

PluginHandlers createTodoHandlers(PluginDataStore store) {
  // 读取所有任务
  Future<List<Map<String, dynamic>>> readAllTasks(
    String userId,
    String encryptionKey,
  ) async {
    final data = await store.readPluginData(
      userId,
      'todo',
      'tasks.json',
      encryptionKey,
    );
    if (data is! Map) return [];
    final tasks = data['tasks'];
    if (tasks is! List) return [];
    return List<Map<String, dynamic>>.from(tasks);
  }

  // 保存所有任务
  Future<void> saveAllTasks(
    String userId,
    String encryptionKey,
    List<Map<String, dynamic>> tasks,
  ) {
    return store.writePluginData(
      userId,
      'todo',
      'tasks.json',
      {'tasks': tasks},
      encryptionKey,
    );
  }

  // 检查任务是否过期
  bool isOverdue(Map<String, dynamic> task) {
    if (_truthy(task['completed'])) return false;
    final dueDate = task['dueDate'] as String?;
    if (dueDate == null || dueDate.isEmpty) return false;
    final today = formatDate(DateTime.now().toUtc());
    return dueDate.compareTo(today) < 0;
  }

  // 检查任务是否是今日任务
  bool isToday(Map<String, dynamic> task) {
    final dueDate = task['dueDate'] as String?;
    if (dueDate == null || dueDate.isEmpty) return false;
    final today = formatDate(DateTime.now().toUtc());
    return dueDate == today;
  }

  return {
    // 获取任务列表
    'getList': (userId, encryptionKey, params) async {
      try {
        var tasks = await readAllTasks(userId, encryptionKey);

        // 按完成状态过滤
        if (params.containsKey('completed')) {
          final completed =
              params['completed'] == true || params['completed'] == 'true';
          tasks = tasks.where((t) => t['completed'] == completed).toList();
        }

        // 按优先级过滤
        if (params.containsKey('priority')) {
          final priority = params['priority'];
          tasks = tasks.where((t) => t['priority'] == priority).toList();
        }

        // 按分类过滤
        if (_truthy(params['category'])) {
          tasks = tasks.where((t) => t['category'] == params['category']).toList();
        }

        return PluginResult.success(
          createPaginatedResult(
            tasks,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取任务失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final index = tasks.indexWhere((t) => t['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }

        return PluginResult.success(tasks[index]);
      } catch (e) {
        return PluginResult.failure('获取任务失败: $e');
      }
    },

    // 创建任务
    'create': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final now = jsIsoDateTime(DateTime.now());

        final newTask = <String, dynamic>{
          ...params,
          'id':
              params['id'] != null && params['id'].toString().isNotEmpty
              ? params['id']
              : generateUUID(),
          'completed': _truthy(params['completed']) ? params['completed'] : false,
          'createdAt': now,
          'updatedAt': now,
        };

        tasks.add(newTask);
        await saveAllTasks(userId, encryptionKey, tasks);

        return PluginResult.success(newTask);
      } catch (e) {
        return PluginResult.failure('创建任务失败: $e');
      }
    },

    // 更新任务
    'update': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final index = tasks.indexWhere((t) => t['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }

        final updatedTask = <String, dynamic>{
          ...tasks[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        tasks[index] = updatedTask;

        await saveAllTasks(userId, encryptionKey, tasks);
        return PluginResult.success(updatedTask);
      } catch (e) {
        return PluginResult.failure('更新任务失败: $e');
      }
    },

    // 删除任务
    'delete': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final initialLength = tasks.length;
        final filtered = tasks.where((t) => t['id'] != params['id']).toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }

        await saveAllTasks(userId, encryptionKey, filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除任务失败: $e');
      }
    },

    // 完成任务
    'completeTask': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final index = tasks.indexWhere((t) => t['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }

        final task = tasks[index];
        if (_truthy(task['completed'])) {
          return const PluginResult.failure('任务已完成', 'INVALID_PARAMS');
        }

        final now = jsIsoDateTime(DateTime.now());
        final updatedTask = <String, dynamic>{
          ...task,
          'completed': true,
          'completedAt': now,
          'updatedAt': now,
        };
        tasks[index] = updatedTask;

        await saveAllTasks(userId, encryptionKey, tasks);
        return PluginResult.success(updatedTask);
      } catch (e) {
        return PluginResult.failure('完成任务失败: $e');
      }
    },

    // 获取今日任务
    'getTodayTasks': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final todayTasks = tasks.where(isToday).toList();

        return PluginResult.success({
          'data': todayTasks,
          'total': todayTasks.length,
        });
      } catch (e) {
        return PluginResult.failure('获取今日任务失败: $e');
      }
    },

    // 获取过期任务
    'getOverdueTasks': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);
        final overdueTasks = tasks.where(isOverdue).toList();

        return PluginResult.success({
          'data': overdueTasks,
          'total': overdueTasks.length,
        });
      } catch (e) {
        return PluginResult.failure('获取过期任务失败: $e');
      }
    },

    // 搜索任务
    'search': (userId, encryptionKey, params) async {
      try {
        var tasks = await readAllTasks(userId, encryptionKey);
        final keyword = params['keyword'];

        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          tasks = tasks
              .where((t) {
                final title = (t['title'] ?? '').toString().toLowerCase();
                final description = (t['description'] ?? '')
                    .toString()
                    .toLowerCase();
                return title.contains(kw) || description.contains(kw);
              })
              .toList();
        }

        return PluginResult.success({'data': tasks, 'total': tasks.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },

    // 获取统计
    'getStats': (userId, encryptionKey, params) async {
      try {
        final tasks = await readAllTasks(userId, encryptionKey);

        final total = tasks.length;
        final completed = tasks.where((t) => _truthy(t['completed'])).length;
        final pending = total - completed;
        final overdue = tasks.where(isOverdue).length;
        final dueToday = tasks.where(isToday).length;

        return PluginResult.success({
          'total': total,
          'completed': completed,
          'pending': pending,
          'overdue': overdue,
          'dueToday': dueToday,
          'completionRate': total > 0 ? ((completed / total) * 100).round() : 0,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}

/// 模拟 JS 真值判断（null/false/0/''/NaN 为假，其余为真）。
bool _truthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true; // List/Map 对象在 JS 中为真
}
