import 'package:flutter/foundation.dart';
import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/plugins/activity/models/activity_record.dart';
import 'package:aboutme/plugins/activity/sample_data.dart';
import 'package:aboutme/widgets/tags_dialog/models/models.dart';

/// 活动数据服务：分日活动 / 标签分组 / 最近标签 / 最近心情
/// 全部经统一数据 SDK（data.call/query）读写，与 REST/MCP 共用同一套处理器
class ActivityService {
  static const _pluginId = 'activity';

  final StorageManager _storage; // ignore: unused_field
  final String _pluginDir; // ignore: unused_field

  ActivityService(this._storage, this._pluginDir);

  // ============ SDK 调用辅助 ============

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _command(
    String action,
    Map<String, dynamic> params,
  ) async {
    final response = await AboutmeDataService.instance.data.call(
      _pluginId,
      action,
      params,
    );
    if (response['success'] != true) throw QueryFailure(response);
    return response;
  }

  Future<Map<String, dynamic>> _query(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await AboutmeDataService.instance.data.query(
      _pluginId,
      action,
      params,
    );
    if (response['success'] != true) throw QueryFailure(response);
    return response;
  }

  // 保存活动记录
  Future<void> saveActivity(ActivityRecord activity, {bool notify = true}) async {
    try {
      final date = activity.startTime;
      debugPrint('[ActivityTime] save id=${activity.id} date=${_dateKey(date)} '
          'start=${activity.startTime.toIso8601String()} end=${activity.endTime.toIso8601String()}');

      // 读取现有活动
      List<ActivityRecord> activities = await getActivitiesForDate(date);

      // 检查是否存在重叠的活动
      final overlappingIndex = activities.indexWhere(
        (a) =>
            a.startTime.isBefore(activity.endTime) &&
            a.endTime.isAfter(activity.startTime),
      );

      if (overlappingIndex != -1) {
        // 如果存在重叠，替换原有的活动（删旧写新，保留新 id）
        await _command('delete', {
          'id': activities[overlappingIndex].id,
          'date': _dateKey(date),
        });
      }
      await _command('create', {
        ...activity.toJson(),
        'date': _dateKey(date),
      });

      // 同步到小组件
      await _syncWidget();

      // 广播事件（初始化时不通知）
      if (notify) {
        eventManager.broadcast('activity_added', EventArgs());
        // 成就系统计数（A18 千时如梭）：仅新增记录（非重叠替换）时累计时长（分钟）
        if (overlappingIndex == -1) {
          eventManager.broadcast(
            'activity_duration_added',
            Value<int>(activity.durationInMinutes, 'activity_duration_added'),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving activity: $e');
      rethrow;
    }
  }

  // 获取指定日期的所有活动
  Future<List<ActivityRecord>> getActivitiesForDate(DateTime date) async {
    try {
      final response = await _query('getList', {'date': _dateKey(date)});
      final jsonList = ((response['data'] as Map)['data'] as List)
          .cast<Map<String, dynamic>>();

      return jsonList.map((json) {
        final activity = ActivityRecord.fromJson(json);
        if (DateTime.parse(json['startTime']).isUtc ||
            DateTime.parse(json['endTime']).isUtc) {
          debugPrint('[ActivityTime] read id=${activity.id} date=${_dateKey(date)} '
              'raw=${json['startTime']}..${json['endTime']} '
              'local=${activity.startTime.toIso8601String()}..${activity.endTime.toIso8601String()}');
        }
        return activity;
      }).toList();
    } catch (e) {
      debugPrint('Error loading activities: $e');
      return [];
    }
  }

  // 更新活动记录
  Future<void> updateActivity(
    ActivityRecord oldActivity,
    ActivityRecord newActivity,
  ) async {
    try {
      // 如果日期改变，需要从旧日期文件删除并添加到新日期文件
      if (oldActivity.startTime.year != newActivity.startTime.year ||
          oldActivity.startTime.month != newActivity.startTime.month ||
          oldActivity.startTime.day != newActivity.startTime.day) {
        // 从旧日期文件删除（不广播，由下面的 saveActivity 广播）
        await deleteActivity(oldActivity, notify: false);

        // 添加到新日期文件
        await saveActivity(newActivity);
      } else {
        // 同一天内更新
        final date = oldActivity.startTime;
        final activities = await getActivitiesForDate(date);

        // 查找并替换活动（删旧写新，保留新 id）
        final index = activities.indexWhere(
          (a) =>
              a.startTime == oldActivity.startTime &&
              a.endTime == oldActivity.endTime &&
              a.title == oldActivity.title,
        );

        if (index != -1) {
          await _command('delete', {
            'id': activities[index].id,
            'date': _dateKey(date),
          });
          await _command('create', {
            ...newActivity.toJson(),
            'date': _dateKey(date),
          });

          // 同步到小组件
          await _syncWidget();

          // 广播更新事件
          eventManager.broadcast('activity_updated', EventArgs());
        }
      }
    } catch (e) {
      debugPrint('Error updating activity: $e');
      rethrow;
    }
  }

  // 删除活动记录
  Future<void> deleteActivity(ActivityRecord activity, {bool notify = true}) async {
    try {
      final date = activity.startTime;

      // 读取现有活动，查找并删除所有匹配记录
      final activities = await getActivitiesForDate(date);
      final matches = activities
          .where(
            (a) =>
                a.startTime == activity.startTime &&
                a.endTime == activity.endTime &&
                a.title == activity.title,
          )
          .toList();

      for (final match in matches) {
        await _command('delete', {'id': match.id, 'date': _dateKey(date)});
      }

      // 同步到小组件
      await _syncWidget();

      // 广播删除事件
      if (notify) {
        eventManager.broadcast('activity_deleted', EventArgs());
      }
    } catch (e) {
      debugPrint('Error deleting activity: $e');
      rethrow;
    }
  }

  // 检查时间段是否有重叠的活动
  Future<bool> hasOverlappingActivities(
    DateTime start,
    DateTime end, {
    ActivityRecord? excludeActivity,
  }) async {
    final date = start;
    final activities = await getActivitiesForDate(date);

    return activities.any((activity) {
      // 排除自身
      if (excludeActivity != null &&
          activity.startTime == excludeActivity.startTime &&
          activity.endTime == excludeActivity.endTime &&
          activity.title == excludeActivity.title) {
        return false;
      }

      // 检查重叠
      return (start.isBefore(activity.endTime) &&
          end.isAfter(activity.startTime));
    });
  }

  // 保存标签组
  Future<void> saveTagGroups(List<TagGroupWithTags> groups) async {
    try {
      await _command('updateTagGroups', {
        'groups': groups.map((group) => group.toMap()).toList(),
      });
    } catch (e) {
      debugPrint('Error saving tag groups: $e');
      rethrow;
    }
  }

  // 获取标签组
  Future<List<TagGroupWithTags>> getTagGroups() async {
    try {
      final response = await _query('getTagGroups');
      final jsonList = ((response['data'] as Map)['data'] as List)
          .cast<Map<String, dynamic>>();
      return jsonList
          .map((json) => TagGroupWithTags.fromMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading tag groups: $e');
      return [];
    }
  }

  // 保存最近使用的标签
  Future<void> saveRecentTags(List<String> tags) async {
    try {
      await _command('updateRecentTags', {'tags': tags});
    } catch (e) {
      debugPrint('Error saving recent tags: $e');
      rethrow;
    }
  }

  // 获取最近使用的标签
  Future<List<String>> getRecentTags() async {
    try {
      final response = await _query('getRecentTags');
      return List<String>.from(response['data'] as List);
    } catch (e) {
      debugPrint('Error loading recent tags: $e');
      return [];
    }
  }

  // 保存最近使用的心情
  Future<void> saveRecentMoods(List<String> moods) async {
    try {
      await _command('updateRecentMoods', {'moods': moods});
    } catch (e) {
      debugPrint('Error saving recent moods: $e');
      rethrow;
    }
  }

  // 获取最近使用的心情
  Future<List<String>> getRecentMoods() async {
    try {
      final response = await _query('getRecentMoods');
      return List<String>.from(response['data'] as List);
    } catch (e) {
      debugPrint('Error loading recent moods: $e');
      return [];
    }
  }

  // 同步小组件数据
  Future<void> _syncWidget() async {
    try {
      // 同步基础活动小组件
      await PluginWidgetSyncHelper.instance.syncActivity();

      // 同步活动周视图小组件
      await PluginWidgetSyncHelper.instance.syncActivityWeeklyWidget();
    } catch (e) {
      // 静默处理小组件同步错误，不影响主要功能
      debugPrint('Failed to sync activity widget: $e');
    }
  }

  /// 获取最近的活动记录（跨所有日期）
  /// 返回最近结束的活动，如果没有活动则返回null
  Future<ActivityRecord?> getLastActivity() async {
    try {
      final now = DateTime.now();
      ActivityRecord? latestActivity;

      // 搜索最近7天的活动
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final activities = await getActivitiesForDate(date);

        for (final activity in activities) {
          if (latestActivity == null ||
              activity.endTime.isAfter(latestActivity.endTime)) {
            latestActivity = activity;
          }
        }

        // 如果找到今天之前有活动的记录，可以提前结束搜索
        if (latestActivity != null && i > 0) {
          break;
        }
      }

      return latestActivity;
    } catch (e) {
      debugPrint('Error getting last activity: $e');
      return null;
    }
  }

  /// 获取指定日期范围的活动统计（按标签分组）
  /// 返回 `Map<String, int>`，key是标签名，value是该标签的总时长（分钟）
  Future<Map<String, int>> getActivityStatsByTag(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _query('getRangeStats', {
        'startDate': _dateKey(startDate),
        'endDate': _dateKey(endDate),
      });
      return Map<String, int>.from(
        (response['data'] as Map)['tagStats'] as Map,
      );
    } catch (e) {
      debugPrint('Error getting activity stats by tag: $e');
      return {};
    }
  }

  /// 获取指定日期范围的活动（用于日历视图）
  Future<List<ActivityRecord>> getActivitiesForRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final response = await _query('getRange', {
        'startDate': _dateKey(startDate),
        'endDate': _dateKey(endDate),
      });
      final jsonList = ((response['data'] as Map)['data'] as List)
          .cast<Map<String, dynamic>>();
      return jsonList.map((json) => ActivityRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting activities for range: $e');
      return [];
    }
  }

  /// 插入示例标签数据（标签分组/最近标签/最近心情，存储已存在时跳过）
  /// 供首次打开引导选择调用
  Future<void> loadSampleTagData() async {
    try {
      // 与旧版 existsPath 判断对齐：文件已创建（含空分组）则不再种示例
      final response = await _query('getTagGroups');
      final fileExists = (response['data'] as Map)['exists'] == true;
      if (fileExists) return;

      final defaultTagGroups = ActivitySampleData.defaultTagGroups;
      await saveTagGroups(defaultTagGroups);

      final defaultRecentTags = ActivitySampleData.defaultRecentTags;
      await saveRecentTags(defaultRecentTags);

      final defaultRecentMoods = ActivitySampleData.defaultRecentMoods;
      await saveRecentMoods(defaultRecentMoods);

      debugPrint('[ActivityService] 已插入示例标签/心情数据');
    } catch (e) {
      debugPrint('[ActivityService] 插入示例标签数据失败: $e');
    }
  }

  /// 插入今日/昨日示例活动记录（供首次打开引导选择调用）
  Future<void> loadSampleActivities() async {
    try {
      final todaySampleActivities = ActivitySampleData.getSampleActivities();
      for (final activity in todaySampleActivities) {
        await saveActivity(activity, notify: false);
      }

      final yesterdaySampleActivities =
          ActivitySampleData.getYesterdaySampleActivities();
      for (final activity in yesterdaySampleActivities) {
        await saveActivity(activity, notify: false);
      }

      debugPrint('[ActivityService] 已插入今日/昨日示例活动');
    } catch (e) {
      debugPrint('[ActivityService] 插入示例活动失败: $e');
    }
  }
}
