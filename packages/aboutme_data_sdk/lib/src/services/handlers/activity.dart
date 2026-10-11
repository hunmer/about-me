import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Activity 插件专用处理器（移植自 nodejs handlers/activity.ts）。
//
// 数据格式：使用按日期分割的文件 activities_{date}.json
// 文件内容可以是数组 [...] 或对象 {"activities": [...]}

PluginHandlers createActivityHandlers(PluginData data) {
  // 读取指定日期的活动
  Future<List<Map<String, dynamic>>> readActivitiesForDate(
    String dateStr,
  ) async {
    final content = await data.read('activity', 'activities_$dateStr.json');
    if (content == null) return [];

    // 兼容两种格式：数组 [...] 或对象 {"activities": [...]}
    if (content is List) {
      return List<Map<String, dynamic>>.from(content);
    }
    if (content is Map) {
      final activities = content['activities'];
      if (activities is List) {
        return List<Map<String, dynamic>>.from(activities);
      }
    }
    return [];
  }

  // 保存指定日期的活动
  Future<void> saveActivitiesForDate(
    String dateStr,
    List<Map<String, dynamic>> activities,
  ) {
    return data.write('activity', 'activities_$dateStr.json', {
      'activities': activities.map((a) => <String, dynamic>{...a}).toList(),
    });
  }

  // 按开始时间升序排序
  void sortByStartTime(List<Map<String, dynamic>> activities) {
    activities.sort((a, b) {
      final aTime = (a['startTime'] as String?) ?? '';
      final bTime = (b['startTime'] as String?) ?? '';
      return aTime.compareTo(bTime);
    });
  }

  // params.date 为空时取今天
  String resolveDate(Map<String, dynamic> params) {
    final date = params['date'] as String?;
    return date != null && date.isNotEmpty ? date : formatDate(DateTime.now());
  }

  return {
    // 获取活动列表
    'getList': (data, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(date);

        // 按开始时间排序
        sortByStartTime(activities);

        return PluginResult.success(
          createPaginatedResult(
            activities,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取活动失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (data, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(date);
        final index = activities.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('活动不存在', 'NOT_FOUND');
        }

        return PluginResult.success(activities[index]);
      } catch (e) {
        return PluginResult.failure('获取活动失败: $e');
      }
    },

    // 创建活动
    'create': (data, params) async {
      try {
        final startTime = params['startTime'] as String?;
        final dateStr = startTime != null && startTime.isNotEmpty
            ? startTime.split('T')[0]
            : formatDate(DateTime.now());
        final activities = await readActivitiesForDate(dateStr);

        final now = jsIsoDateTime(DateTime.now());
        final id = params['id'];
        final newItem = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };

        activities.add(newItem);

        // 按开始时间排序
        sortByStartTime(activities);

        await saveActivitiesForDate(dateStr, activities);

        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建活动失败: $e');
      }
    },

    // 更新活动
    'update': (data, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(date);
        final index = activities.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('活动不存在', 'NOT_FOUND');
        }

        final updatedItem = <String, dynamic>{
          ...activities[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        activities[index] = updatedItem;

        // 按开始时间排序
        sortByStartTime(activities);

        await saveActivitiesForDate(date, activities);

        return PluginResult.success(updatedItem);
      } catch (e) {
        return PluginResult.failure('更新活动失败: $e');
      }
    },

    // 删除活动
    'delete': (data, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(date);
        final index = activities.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('活动不存在', 'NOT_FOUND');
        }

        activities.removeAt(index);
        await saveActivitiesForDate(date, activities);

        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除活动失败: $e');
      }
    },

    // 获取今日统计
    'getTodayStats': (data, params) async {
      try {
        final today = formatDate(DateTime.now());
        final activities = await readActivitiesForDate(today);

        var totalDuration = 0;
        for (final a in activities) {
          final start = DateTime.parse(a['startTime'].toString());
          final end = DateTime.parse(a['endTime'].toString());
          totalDuration += end.difference(start).inMilliseconds;
        }

        return PluginResult.success({
          'date': today,
          'activityCount': activities.length,
          'durationMinutes': (totalDuration / 60000).round(),
          'durationHours': totalDuration ~/ 3600000,
          'remainingMinutes': ((totalDuration % 3600000) / 60000).round(),
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}
