import 'package:aboutme_data_sdk/io.dart';

import '../types.dart';
import '../utils.dart';

// Calendar 插件专用处理器（移植自 nodejs handlers/calendar.ts）。
//
// 数据格式：calendar_events.json 包含 {events: [...], completedEvents: [...]}

PluginHandlers createCalendarHandlers(PluginDataStore store) {
  // 读取所有事件数据
  Future<Map<String, dynamic>> readAllEventsData(
    String userId,
    String encryptionKey,
  ) async {
    final data = await store.readPluginData(
      userId,
      'calendar',
      'calendar_events.json',
      encryptionKey,
    );
    if (data is! Map) return {};
    return Map<String, dynamic>.from(data);
  }

  // 保存所有事件数据
  Future<void> saveAllEventsData(
    String userId,
    String encryptionKey,
    Map<String, dynamic> data,
  ) {
    return store.writePluginData(
      userId,
      'calendar',
      'calendar_events.json',
      data,
      encryptionKey,
    );
  }

  // 解析事件列表
  List<Map<String, dynamic>> parseEvents(Map<String, dynamic> data) {
    final events = data['events'];
    if (events is! List) return [];
    return List<Map<String, dynamic>>.from(events);
  }

  // 解析已完成事件列表
  List<Map<String, dynamic>> parseCompletedEvents(Map<String, dynamic> data) {
    final completedEvents = data['completedEvents'];
    if (completedEvents is! List) return [];
    return List<Map<String, dynamic>>.from(completedEvents);
  }

  return {
    // 获取事件列表
    'getList': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        var events = parseEvents(data);

        // 按日期范围过滤
        final startDate = params['startDate'] as String?;
        final endDate = params['endDate'] as String?;

        if (startDate != null && startDate.isNotEmpty) {
          events = events
              .where(
                (e) =>
                    (e['startTime'] ?? '').toString().compareTo(startDate) >= 0,
              )
              .toList();
        }
        if (endDate != null && endDate.isNotEmpty) {
          events = events
              .where(
                (e) => (e['startTime'] ?? '')
                    .toString()
                    .compareTo(endDate + 'T23:59:59') <= 0,
              )
              .toList();
        }

        // 分页
        final offset = params['offset'] as int? ?? 0;
        final count = params['count'] as int? ?? 100;
        final total = events.length;
        final end = (offset + count).clamp(0, total);
        final paginatedEvents = offset >= total
            ? <Map<String, dynamic>>[]
            : events.sublist(offset, end);

        return PluginResult.success({
          'data': paginatedEvents,
          'total': total,
          'offset': offset,
          'count': paginatedEvents.length,
          'hasMore': offset + paginatedEvents.length < total,
        });
      } catch (e) {
        return PluginResult.failure('获取事件列表失败: $e');
      }
    },

    // 根据 ID 获取
    'getById': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        final events = parseEvents(data);
        final index = events.indexWhere((e) => e['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('事件不存在', 'NOT_FOUND');
        }

        return PluginResult.success(events[index]);
      } catch (e) {
        return PluginResult.failure('获取事件失败: $e');
      }
    },

    // 创建事件
    'create': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        final events = parseEvents(data);
        final now = jsIsoDateTime(DateTime.now());

        final id = params['id'];
        final newEvent = <String, dynamic>{
          ...params,
          'id': id != null && id.toString().isNotEmpty ? id : generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };

        events.add(newEvent);
        data['events'] = events;
        await saveAllEventsData(userId, encryptionKey, data);

        return PluginResult.success(newEvent);
      } catch (e) {
        return PluginResult.failure('创建事件失败: $e');
      }
    },

    // 更新事件
    'update': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        final events = parseEvents(data);
        final index = events.indexWhere((e) => e['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('事件不存在', 'NOT_FOUND');
        }

        final updatedEvent = <String, dynamic>{
          ...events[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        events[index] = updatedEvent;
        data['events'] = events;

        await saveAllEventsData(userId, encryptionKey, data);
        return PluginResult.success(updatedEvent);
      } catch (e) {
        return PluginResult.failure('更新事件失败: $e');
      }
    },

    // 删除事件
    'delete': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        final events = parseEvents(data);
        final initialLength = events.length;
        final filtered = events
            .where((e) => e['id'] != params['id'])
            .toList();

        if (filtered.length == initialLength) {
          return const PluginResult.failure('事件不存在', 'NOT_FOUND');
        }

        data['events'] = filtered;
        await saveAllEventsData(userId, encryptionKey, data);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除事件失败: $e');
      }
    },

    // 完成事件
    'completeEvent': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        final events = parseEvents(data);
        final completedEvents = parseCompletedEvents(data);
        final index = events.indexWhere((e) => e['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('事件不存在', 'NOT_FOUND');
        }

        final event = events[index];
        final now = jsIsoDateTime(DateTime.now());
        final completedEvent = <String, dynamic>{
          ...event,
          'completed': true,
          'completedAt': now,
          'updatedAt': now,
        };

        // 从事件列表移除，添加到已完成列表
        events.removeAt(index);
        completedEvents.add(completedEvent);

        data['events'] = events;
        data['completedEvents'] = completedEvents;
        await saveAllEventsData(userId, encryptionKey, data);

        return PluginResult.success(completedEvent);
      } catch (e) {
        return PluginResult.failure('完成事件失败: $e');
      }
    },

    // 搜索事件
    'search': (userId, encryptionKey, params) async {
      try {
        final data = await readAllEventsData(userId, encryptionKey);
        var events = parseEvents(data);

        final keyword = params['keyword'];
        final startDate = params['startDate'];
        final endDate = params['endDate'];

        if (startDate != null && startDate.toString().isNotEmpty) {
          events = events
              .where(
                (e) => (e['startTime'] ?? '')
                    .toString()
                    .compareTo(startDate.toString()) >= 0,
              )
              .toList();
        }
        if (endDate != null && endDate.toString().isNotEmpty) {
          events = events
              .where(
                (e) => (e['startTime'] ?? '')
                    .toString()
                    .compareTo(endDate.toString() + 'T23:59:59') <= 0,
              )
              .toList();
        }
        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          events = events
              .where(
                (e) =>
                    (e['title'] ?? '').toString().toLowerCase().contains(kw) ||
                    (e['description'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(kw),
              )
              .toList();
        }

        return PluginResult.success({'data': events, 'total': events.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },
  };
}
