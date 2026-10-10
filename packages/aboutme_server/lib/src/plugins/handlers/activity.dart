import 'package:aboutme_data_sdk/io.dart';

import '../types.dart';
import '../utils.dart';

// Activity 插件专用处理器（移植自 nodejs handlers/activity.ts）。
//
// 数据格式：使用按日期分割的文件 activities_{date}.json
// 文件内容可以是数组 [...] 或对象 {"activities": [...]}

PluginHandlers createActivityHandlers(PluginDataStore store) {
  // 读取指定日期的活动
  Future<List<Map<String, dynamic>>> readActivitiesForDate(
    String userId,
    String encryptionKey,
    String dateStr,
  ) async {
    final data = await store.readPluginData(
      userId,
      'activity',
      'activities_$dateStr.json',
      encryptionKey,
    );
    if (data == null) return [];

    // 兼容两种格式：数组 [...] 或对象 {"activities": [...]}
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    if (data is Map) {
      final activities = data['activities'];
      if (activities is List) {
        return List<Map<String, dynamic>>.from(activities);
      }
    }
    return [];
  }

  // 保存指定日期的活动
  Future<void> saveActivitiesForDate(
    String userId,
    String encryptionKey,
    String dateStr,
    List<Map<String, dynamic>> activities,
  ) {
    return store.writePluginData(
      userId,
      'activity',
      'activities_$dateStr.json',
      {
        'activities': activities.map((a) => <String, dynamic>{...a}).toList(),
      },
      encryptionKey,
    );
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
    'getList': (userId, encryptionKey, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          date,
        );

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
    'getById': (userId, encryptionKey, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          date,
        );
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
    'create': (userId, encryptionKey, params) async {
      try {
        final startTime = params['startTime'] as String?;
        final dateStr = startTime != null && startTime.isNotEmpty
            ? startTime.split('T')[0]
            : formatDate(DateTime.now());
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          dateStr,
        );

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

        await saveActivitiesForDate(userId, encryptionKey, dateStr, activities);

        return PluginResult.success(newItem);
      } catch (e) {
        return PluginResult.failure('创建活动失败: $e');
      }
    },

    // 更新活动
    'update': (userId, encryptionKey, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          date,
        );
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

        await saveActivitiesForDate(userId, encryptionKey, date, activities);

        return PluginResult.success(updatedItem);
      } catch (e) {
        return PluginResult.failure('更新活动失败: $e');
      }
    },

    // 删除活动
    'delete': (userId, encryptionKey, params) async {
      try {
        final date = resolveDate(params);
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          date,
        );
        final index = activities.indexWhere((a) => a['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('活动不存在', 'NOT_FOUND');
        }

        activities.removeAt(index);
        await saveActivitiesForDate(userId, encryptionKey, date, activities);

        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除活动失败: $e');
      }
    },

    // 获取今日统计
    'getTodayStats': (userId, encryptionKey, params) async {
      try {
        final today = formatDate(DateTime.now());
        final activities = await readActivitiesForDate(
          userId,
          encryptionKey,
          today,
        );

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
