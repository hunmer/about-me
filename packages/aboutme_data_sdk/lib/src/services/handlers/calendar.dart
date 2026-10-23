import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'structured_support.dart';

PluginHandlers createCalendarHandlers(PluginData data) {
  Future<Map<String, dynamic>> state() async {
    final s = entityObject(await data.read('calendar', 'calendar_events.json'));
    s['events'] = entityList(s['events']).map(_event).toList();
    s['completedEvents'] = entityList(
      s['completedEvents'],
    ).map(_event).toList();
    final ids = <String>{};
    for (final row in [
      ...s['events'] as List,
      ...s['completedEvents'] as List,
    ]) {
      if (!ids.add(row['id'] as String))
        throw const FormatException('活动和完成列表 ID 重复');
    }
    return s;
  }

  Future<void> save(Map<String, dynamic> s) async {
    await ensureDomainBackup(data, 'calendar');
    await data.write('calendar', 'calendar_events.json', s);
  }

  Future<PluginResult> list(
    Map<String, dynamic> p, {
    bool snapshot = false,
  }) async {
    final s = await state();
    if (snapshot) return PluginResult.success(s);
    var rows = entityList(
      s[p['completed'] == true ? 'completedEvents' : 'events'],
    );
    final start = p['startDate'] == null
        ? null
        : validDate(p['startDate'], 'startDate');
    final end = p['endDate'] == null
        ? null
        : validDate(p['endDate'], 'endDate').add(
            p['endDate'].toString().length == 10
                ? const Duration(days: 1)
                : Duration.zero,
          );
    if (start != null && end != null && !end.isAfter(start))
      throw const FormatException('区间结束必须晚于开始');
    rows = rows.where((r) {
      final from = validDate(r['startTime'], 'startTime');
      final until = r['endTime'] == null
          ? from
          : validDate(r['endTime'], 'endTime');
      if (start != null && until.isBefore(start)) return false;
      if (end != null && !from.isBefore(end)) return false;
      final keyword = (p['keyword'] ?? '').toString().toLowerCase();
      return keyword.isEmpty ||
          '${r['title']} ${r['description']}'.toLowerCase().contains(keyword);
    }).toList();
    rows.sort((a, b) {
      final n = validDate(
        a['startTime'],
        'startTime',
      ).compareTo(validDate(b['startTime'], 'startTime'));
      return n == 0 ? (a['id'] as String).compareTo(b['id'] as String) : n;
    });
    return PluginResult.success(pageEntities(rows, p));
  }

  Future<PluginResult> put(Map<String, dynamic> p, bool create) async {
    final s = await state();
    final active = entityList(s['events']);
    final completed = entityList(s['completedEvents']);
    final id = p['id'] ?? generateUUID();
    final rows = active.any((r) => r['id'] == id) ? active : completed;
    final i = rows.indexWhere((r) => r['id'] == id);
    if (create && i >= 0)
      return const PluginResult.failure('日程已存在', 'CONFLICT');
    if (!create && i < 0)
      return const PluginResult.failure('日程不存在', 'NOT_FOUND');
    final next = _event({
      ...?(i < 0 ? null : rows[i]),
      ...changedFields(p),
      'id': id,
    });
    if (create) {
      active.add(next);
    } else {
      rows[i] = next;
    }
    s['events'] = active;
    s['completedEvents'] = completed;
    await save(s);
    return PluginResult.success(next);
  }

  Future<Map<String, dynamic>> preferences() async =>
      entityObject(await data.read('calendar', 'calendar_last_view.json'));
  return {
    'restoreBackup': (_, p) async {
      if (p['confirmRestore'] != true) {
        throw const FormatException('confirmRestore required');
      }
      return PluginResult.success(await restoreDomainBackup(data, 'calendar'));
    },
    'getPreferences': (_, p) async => PluginResult.success(await preferences()),
    'updatePreferences': (_, p) async {
      await ensureDomainBackup(data, 'calendar');
      final next = {...await preferences(), ...p};
      if (next['view'] != null &&
          ![
            'day',
            'week',
            'workWeek',
            'month',
            'schedule',
            'timelineDay',
            'timelineWeek',
            'timelineWorkWeek',
            'timelineMonth',
          ].contains(next['view']))
        throw const FormatException('无效日历视图');
      await data.write('calendar', 'calendar_last_view.json', next);
      return PluginResult.success(next);
    },
    'restoreEvent': (_, p) async {
      final s = await state();
      final rows = s['completedEvents'] as List;
      final i = rows.indexWhere((r) => r['id'] == p['id']);
      if (i < 0) return const PluginResult.failure('已完成日程不存在', 'NOT_FOUND');
      final row = Map<String, dynamic>.from(rows.removeAt(i) as Map)
        ..['completedTime'] = null
        ..remove('completedAt')
        ..remove('completed');
      (s['events'] as List).add(row);
      await save(s);
      return PluginResult.success(row);
    },
    'resetData': (_, p) async {
      final s = await state();
      await ensureDomainBackup(data, 'calendar');
      s['events'] = [];
      s['completedEvents'] = [];
      await save(s);
      await data.write('calendar', 'calendar_last_view.json', {});
      return PluginResult.success({'cleared': true});
    },
    'getList': (_, p) => list(p),
    'search': (_, p) => list(p),
    'getSnapshot': (_, p) => list(p, snapshot: true),
    'getById': (_, p) async {
      final s = await state();
      for (final row in [
        ...s['events'] as List,
        ...s['completedEvents'] as List,
      ]) {
        if (row['id'] == p['id']) return PluginResult.success(row);
      }
      return const PluginResult.failure('日程不存在', 'NOT_FOUND');
    },
    'create': (_, p) => put(p, true),
    'update': (_, p) => put(p, false),
    'delete': (_, p) async {
      final s = await state();
      var found = false;
      for (final key in ['events', 'completedEvents']) {
        final rows = s[key] as List;
        final n = rows.length;
        rows.removeWhere((r) => r['id'] == p['id']);
        found = found || rows.length != n;
      }
      if (!found) return const PluginResult.failure('日程不存在', 'NOT_FOUND');
      await save(s);
      return PluginResult.success({'id': p['id']});
    },
    'completeEvent': (_, p) async {
      final s = await state();
      final rows = s['events'] as List;
      final i = rows.indexWhere((r) => r['id'] == p['id']);
      if (i < 0) return const PluginResult.failure('未完成日程不存在', 'NOT_FOUND');
      final next = <String, dynamic>{
        ...rows.removeAt(i) as Map<String, dynamic>,
        'completedTime': DateTime.now().toIso8601String(),
      };
      (s['completedEvents'] as List).add(next);
      await save(s);
      return PluginResult.success(next);
    },
    'exportData': (_, p) async =>
        PluginResult.success({'schemaVersion': 1, ...await state()}),
    'importData': (_, p) async {
      final incoming = {
        'events': entityList(p['events']).map(_event).toList(),
        'completedEvents': entityList(
          p['completedEvents'],
        ).map(_event).toList(),
      };
      final s = await state();
      await ensureDomainBackup(data, 'calendar');
      final ids = {
        for (final r in [
          ...s['events'] as List,
          ...s['completedEvents'] as List,
        ])
          r['id'],
      };
      var inserted = 0;
      for (final key in incoming.keys) {
        for (final row in incoming[key]!) {
          if (ids.add(row['id'])) {
            (s[key] as List).add(row);
            inserted++;
          }
        }
      }
      await save(s);
      return PluginResult.success({'inserted': inserted});
    },
    'seedExamples': (_, p) async {
      if (p['templateVersion'] != null && p['templateVersion'] != 1)
        return const PluginResult.failure('未知示例版本', 'UNSUPPORTED');
      if (await data.read('calendar', 'sdk_examples_v1.json') != null)
        return PluginResult.success({'inserted': 0, 'templateVersion': 1});
      final s = await state();
      final rows = s['events'] as List;
      final existing = {
        for (final r in [...rows, ...s['completedEvents'] as List]) r['id'],
      };
      var inserted = 0;
      final now = DateTime.now();
      for (final sample in [
        {
          'id': 'sample_event_1',
          'title': '团队周会',
          'startTime': DateTime(
            now.year,
            now.month,
            now.day,
            10,
          ).toIso8601String(),
          'endTime': DateTime(
            now.year,
            now.month,
            now.day,
            11,
          ).toIso8601String(),
          'reminderMinutes': 15,
        },
        {
          'id': 'sample_event_2',
          'title': '健身时间',
          'startTime': DateTime(
            now.year,
            now.month,
            now.day,
            18,
            30,
          ).toIso8601String(),
        },
      ]) {
        if (existing.add(sample['id'])) {
          rows.add(_event(sample));
          inserted++;
        }
      }
      await save(s);
      await data.write('calendar', 'sdk_examples_v1.json', {
        'templateVersion': 1,
      });
      return PluginResult.success({'inserted': inserted, 'templateVersion': 1});
    },
  };
}

Map<String, dynamic> _event(Map<String, dynamic> raw) {
  final row = <String, dynamic>{
    'description': '',
    'icon': 0xe878,
    'color': 0xff2196f3,
    'source': 'default',
    ...raw,
  };
  requiredText(row, 'id');
  requiredText(row, 'title');
  final start = validDate(row['startTime'], 'startTime');
  if (row['endTime'] != null &&
      validDate(row['endTime'], 'endTime').isBefore(start))
    throw const FormatException('结束时间早于开始时间');
  if (row['completedTime'] == null && row['completedAt'] != null)
    row['completedTime'] = row['completedAt'];
  if (row['completedTime'] != null)
    validDate(row['completedTime'], 'completedTime');
  if (row['reminderMinutes'] != null &&
      (row['reminderMinutes'] is! int || (row['reminderMinutes'] as int) < 0))
    throw const FormatException('提醒分钟数必须为非负整数或 null');
  if (row['icon'] is! int ||
      row['color'] is! int ||
      row['description'] is! String ||
      row['source'] is! String)
    throw const FormatException('无效日程显示字段');
  // Unknown extension fields (including repeat rules) survive every patch and completion.
  return row;
}
