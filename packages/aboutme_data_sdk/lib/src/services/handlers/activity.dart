import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

// Activity 插件专用处理器（移植自 nodejs handlers/activity.ts）。
//
// 数据格式：使用按日期分割的文件 activities_{date}.json
// 文件内容可以是数组 [...] 或对象 {"activities": [...]}
// 另有整文件读写的标签分组/最近标签/最近心情三份数据。

PluginHandlers createActivityHandlers(PluginData data) {
  // 读取指定日期的活动（文件缺失视为空；损坏数据报 CORRUPT_DATA）
  Future<List<Map<String, dynamic>>> readActivitiesForDate(
    String dateStr,
  ) async {
    final content = await data.read('activity', 'activities_$dateStr.json');
    if (content == null) return [];

    // 兼容两种格式：数组 [...] 或对象 {"activities": [...]}
    final List? rows = switch (content) {
      List() => content,
      Map() => content['activities'] is List
          ? content['activities'] as List
          : null,
      _ => null,
    };
    if (rows == null) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected activities array');
    }
    return rows.map((e) {
      if (e is! Map) {
        throw const DomainFailure('CORRUPT_DATA', 'Invalid activity row');
      }
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  // 读取字符串数组文件（recent_tags / recent_moods）
  Future<List<String>> readStringListFile(String fileName) async {
    final content = await data.read('activity', fileName);
    if (content == null) return [];
    if (content is! List || content.any((e) => e is! String)) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected string array');
    }
    return List<String>.from(content);
  }

  // 解析标签分组内容（元素须为含 name 的对象；标签兼容字符串旧格式）
  List<Map<String, dynamic>> parseTagGroups(dynamic content) {
    if (content is! List) {
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    }
    return content.map((e) {
      if (e is! Map || e['name'] is! String) {
        throw const DomainFailure('CORRUPT_DATA', 'Invalid tag group row');
      }
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  // 校验并归一化日期参数（yyyy-MM-dd，允许带时间后缀）
  String requireDate(Map<String, dynamic> params, String key) {
    final value = params[key]?.toString();
    final dateStr = value == null ? '' : value.split('T')[0];
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr) ||
        DateTime.tryParse(dateStr) == null) {
      throw ArgumentError('$key 必须为有效日期 (yyyy-MM-dd)');
    }
    return dateStr;
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

  // 读取日期区间（含两端）内的全部活动，按开始时间升序
  Future<List<Map<String, dynamic>>> readActivitiesInRange(
    String startDate,
    String endDate,
  ) async {
    final files = await data.listFiles('activity', 'activities_*.json');
    final result = <Map<String, dynamic>>[];
    for (final file in files) {
      final dateStr = file.substring(
        'activities_'.length,
        file.length - '.json'.length,
      );
      if (dateStr.compareTo(startDate) < 0 || dateStr.compareTo(endDate) > 0) {
        continue;
      }
      result.addAll(await readActivitiesForDate(dateStr));
    }
    sortByStartTime(result);
    return result;
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
            count: params['count'] as int? ?? activities.length,
          ),
        );
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
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
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
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
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
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
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
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
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
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
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },

    // 获取日期区间（含两端）的活动列表
    'getRange': (data, params) async {
      try {
        final startDate = requireDate(params, 'startDate');
        final endDate = requireDate(params, 'endDate');
        final activities = await readActivitiesInRange(startDate, endDate);

        return PluginResult.success(
          createPaginatedResult(
            activities,
            offset: params['offset'] as int?,
            count: params['count'] as int? ?? activities.length,
          ),
        );
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } on ArgumentError catch (e) {
        return PluginResult.failure('$e', 'INVALID_PARAMS');
      } catch (e) {
        return PluginResult.failure('获取区间活动失败: $e');
      }
    },

    // 获取日期区间（含两端）的统计：活动数、总分钟数与按标签聚合分钟数
    'getRangeStats': (data, params) async {
      try {
        final startDate = requireDate(params, 'startDate');
        final endDate = requireDate(params, 'endDate');
        final activities = await readActivitiesInRange(startDate, endDate);

        final tagStats = <String, int>{};
        var totalMinutes = 0;
        for (final a in activities) {
          final start = DateTime.tryParse('${a['startTime'] ?? ''}');
          final end = DateTime.tryParse('${a['endTime'] ?? ''}');
          final minutes = start == null || end == null
              ? 0
              : end.difference(start).inMinutes;
          totalMinutes += minutes;
          final tags = a['tags'];
          if (tags is List) {
            for (final tag in tags) {
              final key = '$tag';
              tagStats[key] = (tagStats[key] ?? 0) + minutes;
            }
          }
        }

        return PluginResult.success({
          'startDate': startDate,
          'endDate': endDate,
          'activityCount': activities.length,
          'durationMinutes': totalMinutes,
          'tagStats': tagStats,
        });
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } on ArgumentError catch (e) {
        return PluginResult.failure('$e', 'INVALID_PARAMS');
      } catch (e) {
        return PluginResult.failure('获取区间统计失败: $e');
      }
    },

    // 获取标签分组（exists 表示文件是否已创建，供首启示例数据判断）
    'getTagGroups': (data, params) async {
      try {
        final raw = await data.read('activity', 'tag_groups.json');
        if (raw == null) {
          return PluginResult.success({
            'exists': false,
            'data': <Map<String, dynamic>>[],
          });
        }
        return PluginResult.success({
          'exists': true,
          'data': parseTagGroups(raw),
        });
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } catch (e) {
        return PluginResult.failure('获取标签分组失败: $e');
      }
    },

    // 整体更新标签分组
    'updateTagGroups': (data, params) async {
      try {
        final groups = params['groups'];
        if (groups is! List ||
            groups.any((e) => e is! Map || e['name'] is! String)) {
          return const PluginResult.failure(
            'groups 必须为标签分组对象数组',
            'INVALID_PARAMS',
          );
        }
        final rows = groups
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await data.write('activity', 'tag_groups.json', rows);
        return PluginResult.success({'count': rows.length});
      } catch (e) {
        return PluginResult.failure('更新标签分组失败: $e');
      }
    },

    // 获取最近使用标签
    'getRecentTags': (data, params) async {
      try {
        return PluginResult.success(await readStringListFile('recent_tags.json'));
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } catch (e) {
        return PluginResult.failure('获取最近标签失败: $e');
      }
    },

    // 整体更新最近使用标签
    'updateRecentTags': (data, params) async {
      try {
        final tags = params['tags'];
        if (tags is! List || tags.any((e) => e is! String)) {
          return const PluginResult.failure(
            'tags 必须为字符串数组',
            'INVALID_PARAMS',
          );
        }
        await data.write('activity', 'recent_tags.json', List<String>.from(tags));
        return PluginResult.success({'count': tags.length});
      } catch (e) {
        return PluginResult.failure('更新最近标签失败: $e');
      }
    },

    // 获取最近使用心情
    'getRecentMoods': (data, params) async {
      try {
        return PluginResult.success(
          await readStringListFile('recent_moods.json'),
        );
      } on DomainFailure catch (e) {
        return PluginResult.failure(e.message, e.code);
      } catch (e) {
        return PluginResult.failure('获取最近心情失败: $e');
      }
    },

    // 整体更新最近使用心情
    'updateRecentMoods': (data, params) async {
      try {
        final moods = params['moods'];
        if (moods is! List || moods.any((e) => e is! String)) {
          return const PluginResult.failure(
            'moods 必须为字符串数组',
            'INVALID_PARAMS',
          );
        }
        await data.write(
          'activity',
          'recent_moods.json',
          List<String>.from(moods),
        );
        return PluginResult.success({'count': moods.length});
      } catch (e) {
        return PluginResult.failure('更新最近心情失败: $e');
      }
    },
  };
}
