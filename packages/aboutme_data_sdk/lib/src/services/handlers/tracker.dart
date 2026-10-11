import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Tracker 插件专用处理器（移植自 nodejs handlers/tracker.ts）。
//
// 数据格式：
// - goals.json: 目标列表 {"goals": [...]}
// - records.json: 记录列表 {"records": [...]}

PluginHandlers createTrackerHandlers(PluginData data) {
  // 读取所有目标
  Future<List<Map<String, dynamic>>> readAllGoals() async {
    final content = await data.read('tracker', 'goals.json');
    if (content is! Map) return [];
    final goals = content['goals'];
    if (goals is! List) return [];
    return List<Map<String, dynamic>>.from(goals);
  }

  // 保存所有目标
  Future<void> saveAllGoals(List<Map<String, dynamic>> goals) {
    return data.write('tracker', 'goals.json', {
      'goals': goals,
    });
  }

  // 读取所有记录
  Future<List<Map<String, dynamic>>> readAllRecords() async {
    final content = await data.read('tracker', 'records.json');
    if (content is! Map) return [];
    final records = content['records'];
    if (records is! List) return [];
    return List<Map<String, dynamic>>.from(records);
  }

  // 保存所有记录
  Future<void> saveAllRecords(List<Map<String, dynamic>> records) {
    return data.write('tracker', 'records.json', {
      'records': records,
    });
  }

  return {
    // 获取目标列表
    'getList': (data, params) async {
      try {
        var goals = await readAllGoals();

        // 按状态过滤
        final status = params['status'] as String?;
        if (status == 'active') {
          goals = goals.where((g) => !_truthy(g['isCompleted'])).toList();
        } else if (status == 'completed') {
          goals = goals.where((g) => _truthy(g['isCompleted'])).toList();
        }

        // 按分组过滤
        final group = params['group'] as String?;
        if (group != null && group.isNotEmpty) {
          goals = goals.where((g) => g['group'] == group).toList();
        }

        return PluginResult.success(
          createPaginatedResult(
            goals,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取目标列表失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final goals = await readAllGoals();
        final index = goals.indexWhere((g) => g['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('目标不存在', 'NOT_FOUND');
        }

        return PluginResult.success(goals[index]);
      } catch (e) {
        return PluginResult.failure('获取目标失败: $e');
      }
    },

    // 创建目标
    'create': (data, params) async {
      try {
        final goals = await readAllGoals();
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final currentValue = params['currentValue'];
        final isCompleted = params['isCompleted'];
        final newGoal = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'currentValue': _truthy(currentValue) ? currentValue : 0,
          'isCompleted': _truthy(isCompleted) ? isCompleted : false,
          'createdAt': now,
          'updatedAt': now,
        };

        goals.add(newGoal);
        await saveAllGoals(goals);

        return PluginResult.success(newGoal);
      } catch (e) {
        return PluginResult.failure('创建目标失败: $e');
      }
    },

    // 更新目标
    'update': (data, params) async {
      try {
        final goals = await readAllGoals();
        final index = goals.indexWhere((g) => g['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('目标不存在', 'NOT_FOUND');
        }

        final updatedGoal = <String, dynamic>{
          ...goals[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        goals[index] = updatedGoal;

        await saveAllGoals(goals);
        return PluginResult.success(updatedGoal);
      } catch (e) {
        return PluginResult.failure('更新目标失败: $e');
      }
    },

    // 删除目标
    'delete': (data, params) async {
      try {
        final goals = await readAllGoals();
        final initialLength = goals.length;
        final filteredGoals = goals
            .where((g) => g['id'] != params['id'])
            .toList();

        if (filteredGoals.length == initialLength) {
          return const PluginResult.failure('目标不存在', 'NOT_FOUND');
        }

        await saveAllGoals(filteredGoals);

        // 同时删除相关记录
        final records = await readAllRecords();
        final filteredRecords = records
            .where((r) => r['goalId'] != params['id'])
            .toList();
        await saveAllRecords(filteredRecords);

        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除目标失败: $e');
      }
    },

    // 添加记录
    'addRecord': (data, params) async {
      try {
        final goalId = params['goalId'];
        final value = params['value'];
        final date = params['date'];
        final note = params['note'];
        final records = await readAllRecords();

        final now = jsIsoDateTime(DateTime.now());
        final newRecord = <String, dynamic>{
          'id': generateUUID(),
          if (goalId != null) 'goalId': goalId,
          if (value != null) 'value': value,
          if (date != null) 'date': date,
          if (note != null) 'note': note,
          'recordedAt': now,
          'createdAt': now,
        };

        records.add(newRecord);
        await saveAllRecords(records);

        // 更新目标的 currentValue
        final goals = await readAllGoals();
        final goalIndex = goals.indexWhere((g) => g['id'] == goalId);

        if (goalIndex != -1) {
          final goal = goals[goalIndex];
          goals[goalIndex] = <String, dynamic>{
            ...goal,
            'currentValue': _toNum(goal['currentValue']) + _toNum(value),
            'updatedAt': now,
          };
          await saveAllGoals(goals);
        }

        return PluginResult.success(newRecord);
      } catch (e) {
        return PluginResult.failure('添加记录失败: $e');
      }
    },

    // 获取目标的记录
    'getRecords': (data, params) async {
      try {
        final goalId = params['goalId'];
        var records = await readAllRecords();

        records = records.where((r) => r['goalId'] == goalId).toList();

        // 按记录时间排序
        records.sort((a, b) {
          final aTime = (a['recordedAt'] ?? '').toString();
          final bTime = (b['recordedAt'] ?? '').toString();
          return bTime.compareTo(aTime);
        });

        return PluginResult.success({
          'data': records,
          'total': records.length,
        });
      } catch (e) {
        return PluginResult.failure('获取记录失败: $e');
      }
    },

    // 获取统计
    'getStats': (data, params) async {
      try {
        final goals = await readAllGoals();
        final records = await readAllRecords();

        final totalGoals = goals.length;
        final activeGoals = goals
            .where((g) => !_truthy(g['isCompleted']))
            .length;
        final completedGoals = goals
            .where((g) => _truthy(g['isCompleted']))
            .length;

        // 今日记录数（toISOString 为 UTC 日期）
        final today = jsIsoDateTime(DateTime.now()).split('T')[0];
        final todayRecords = records
            .where((r) => (r['recordedAt'] ?? '').toString().startsWith(today))
            .length;

        return PluginResult.success({
          'totalGoals': totalGoals,
          'activeGoals': activeGoals,
          'completedGoals': completedGoals,
          'totalRecords': records.length,
          'todayRecordCount': todayRecords,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}

/// JS 真值判断（null/false/0/空串为假，其余为真）。
bool _truthy(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  return true;
}

/// 模拟 JS 算术场景下的宽松数字转换（(x as number) || 0 的语义）。
num _toNum(dynamic value) =>
    value is num ? value : (num.tryParse(value?.toString() ?? '') ?? 0);
