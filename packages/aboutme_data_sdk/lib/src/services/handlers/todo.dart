import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Todo 插件处理器。
//
// 数据格式：tasks.json = {"tasks": [...], "completedTasks": [...], "viewMode": ...}
// 客户端在同一文件存放视图设置与完成历史，写回时保留这些额外字段。

PluginHandlers createTodoHandlers(PluginData data) {
  // 读取整个文件（保留额外字段）
  Future<Map<String, dynamic>> readFile() async {
    final content = await data.read('todo', 'tasks.json');
    return content is Map<String, dynamic> ? content : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> readAllTasks() async {
    final file = await readFile();
    final tasks = file['tasks'];
    return tasks is List
        ? List<Map<String, dynamic>>.from(tasks)
        : <Map<String, dynamic>>[];
  }

  // 只替换 tasks 键，保留 completedTasks/viewMode 等
  Future<void> saveAllTasks(List<Map<String, dynamic>> tasks) async {
    final file = await readFile();
    file['tasks'] = tasks;
    await data.write('todo', 'tasks.json', file);
  }

  bool isOverdue(Map<String, dynamic> task) {
    if (truthy(task['completed'])) return false;
    final dueDate = task['dueDate'] as String?;
    if (dueDate == null || dueDate.isEmpty) return false;
    final today = formatDate(DateTime.now().toUtc());
    return dueDate.compareTo(today) < 0;
  }

  bool isToday(Map<String, dynamic> task) {
    final dueDate = task['dueDate'] as String?;
    if (dueDate == null || dueDate.isEmpty) return false;
    final today = formatDate(DateTime.now().toUtc());
    return dueDate == today;
  }

  return {
    'getList': (data, params) async {
      try {
        var tasks = await readAllTasks();

        if (params.containsKey('completed')) {
          final completed =
              params['completed'] == true || params['completed'] == 'true';
          tasks = tasks.where((t) => t['completed'] == completed).toList();
        }
        if (params.containsKey('priority')) {
          final priority = params['priority'];
          tasks = tasks.where((t) => t['priority'] == priority).toList();
        }
        if (truthy(params['category'])) {
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
    'getById': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final index = tasks.indexWhere((t) => t['id'] == params['id']);
        if (index == -1) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }
        return PluginResult.success(tasks[index]);
      } catch (e) {
        return PluginResult.failure('获取任务失败: $e');
      }
    },
    'create': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final now = jsIsoDateTime(DateTime.now());

        final newTask = <String, dynamic>{
          ...params,
          'id':
              params['id'] != null && params['id'].toString().isNotEmpty
                  ? params['id']
                  : generateUUID(),
          'completed': truthy(params['completed']) ? params['completed'] : false,
          'createdAt': now,
          'updatedAt': now,
        };

        tasks.add(newTask);
        await saveAllTasks(tasks);
        return PluginResult.success(newTask);
      } catch (e) {
        return PluginResult.failure('创建任务失败: $e');
      }
    },
    'update': (data, params) async {
      try {
        final tasks = await readAllTasks();
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
        await saveAllTasks(tasks);
        return PluginResult.success(updatedTask);
      } catch (e) {
        return PluginResult.failure('更新任务失败: $e');
      }
    },
    'delete': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final initialLength = tasks.length;
        final filtered = tasks.where((t) => t['id'] != params['id']).toList();
        if (filtered.length == initialLength) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }
        await saveAllTasks(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除任务失败: $e');
      }
    },
    'completeTask': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final index = tasks.indexWhere((t) => t['id'] == params['id']);
        if (index == -1) {
          return const PluginResult.failure('任务不存在', 'NOT_FOUND');
        }

        final task = tasks[index];
        if (truthy(task['completed'])) {
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
        await saveAllTasks(tasks);
        return PluginResult.success(updatedTask);
      } catch (e) {
        return PluginResult.failure('完成任务失败: $e');
      }
    },
    'getTodayTasks': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final todayTasks = tasks.where(isToday).toList();
        return PluginResult.success({
          'data': todayTasks,
          'total': todayTasks.length,
        });
      } catch (e) {
        return PluginResult.failure('获取今日任务失败: $e');
      }
    },
    'getOverdueTasks': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final overdueTasks = tasks.where(isOverdue).toList();
        return PluginResult.success({
          'data': overdueTasks,
          'total': overdueTasks.length,
        });
      } catch (e) {
        return PluginResult.failure('获取过期任务失败: $e');
      }
    },
    'search': (data, params) async {
      try {
        var tasks = await readAllTasks();
        final keyword = params['keyword'];
        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          tasks = tasks
              .where((t) {
                final title = (t['title'] ?? '').toString().toLowerCase();
                final description =
                    (t['description'] ?? '').toString().toLowerCase();
                return title.contains(kw) || description.contains(kw);
              })
              .toList();
        }
        return PluginResult.success({'data': tasks, 'total': tasks.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },
    'getStats': (data, params) async {
      try {
        final tasks = await readAllTasks();
        final total = tasks.length;
        final completed = tasks.where((t) => truthy(t['completed'])).length;
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
