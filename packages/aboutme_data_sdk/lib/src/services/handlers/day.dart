import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'structured_support.dart';

PluginHandlers createDayHandlers(PluginData data) {
  Future<List<Map<String, dynamic>>> all() async => entityList(
    await data.read('day', 'memorial_days.json'),
    key: 'days',
  ).map(_day).toList();
  Future<void> save(List<Map<String, dynamic>> rows) =>
      writeEntityList(data, 'day', 'memorial_days.json', rows, key: 'days');
  Future<Map<String, dynamic>> preferences() async => {
    'isCardView': true,
    'sortMode': 'upcoming',
    ...entityObject(await data.read('day', 'view_preference.json')),
  };
  Future<PluginResult> list(
    Map<String, dynamic> p, {
    bool snapshot = false,
  }) async {
    final prefs = await preferences();
    var rows = await all();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    DateTime due(Map<String, dynamic> row) => _dayDue(row, day);
    if (p['keyword'] != null)
      rows = rows
          .where(
            (r) => (r['title'] as String).contains(p['keyword'].toString()),
          )
          .toList();
    if (p['includeExpired'] == false)
      rows = rows.where((r) => !due(r).isBefore(day)).toList();
    if (p['startDate'] != null)
      rows = rows
          .where(
            (r) => !due(r).isBefore(validDate(p['startDate'], 'startDate')),
          )
          .toList();
    if (p['endDate'] != null)
      rows = rows
          .where((r) => !due(r).isAfter(validDate(p['endDate'], 'endDate')))
          .toList();
    final mode = (p['sortMode'] ?? prefs['sortMode'])
        .toString()
        .split('.')
        .last;
    rows.sort((a, b) {
      final result = switch (mode) {
        'manual' => (a['sortIndex'] as num).compareTo(b['sortIndex'] as num),
        'recent' => (b['creationDate'] as String).compareTo(
          a['creationDate'] as String,
        ),
        _ => due(a).compareTo(due(b)),
      };
      return result == 0
          ? (a['id'] as String).compareTo(b['id'] as String)
          : result;
    });
    return PluginResult.success(
      snapshot ? {'data': rows, 'preferences': prefs} : pageEntities(rows, p),
    );
  }

  Future<PluginResult> put(Map<String, dynamic> p, bool create) async {
    final rows = await all();
    final id = p['id'] ?? generateUUID();
    final i = rows.indexWhere((r) => r['id'] == id);
    if (create && i >= 0)
      return const PluginResult.failure('纪念日已存在', 'CONFLICT');
    if (!create && i < 0)
      return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
    final next = _day({
      ...?(i < 0 ? null : rows[i]),
      ...changedFields(p),
      'id': id,
    });
    if (i < 0)
      rows.add(next);
    else
      rows[i] = next;
    await save(rows);
    return PluginResult.success(next);
  }

  Future<Map<String, dynamic>> export() async => {
    'schemaVersion': 1,
    'days': await all(),
    'preferences': await preferences(),
  };
  return {
    'restoreBackup': (_, p) async =>
        PluginResult.success(await restoreDomainBackup(data, 'day')),
    'getList': (_, p) => list(p),
    'search': (_, p) => list(p),
    'getSnapshot': (_, p) => list(p, snapshot: true),
    'getById': (_, p) async {
      final rows = await all();
      for (final r in rows) {
        if (r['id'] == p['id']) return PluginResult.success(r);
      }
      return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
    },
    'create': (_, p) => put(p, true),
    'update': (_, p) => put(p, false),
    'delete': (_, p) async {
      final rows = await all();
      final n = rows.length;
      rows.removeWhere((r) => r['id'] == p['id']);
      if (n == rows.length)
        return const PluginResult.failure('纪念日不存在', 'NOT_FOUND');
      await save(rows);
      return PluginResult.success({'id': p['id']});
    },
    'getPreferences': (_, p) async => PluginResult.success(await preferences()),
    'updatePreferences': (_, p) async {
      await ensureDomainBackup(data, 'day');
      final next = {...await preferences(), ...p};
      if (next['isCardView'] is! bool ||
          ![
            'upcoming',
            'recent',
            'manual',
          ].contains(next['sortMode'].toString().split('.').last))
        throw const FormatException('无效纪念日视图设置');
      await data.write('day', 'view_preference.json', next);
      return PluginResult.success(next);
    },
    'reorder': (_, p) async {
      final ids = p['ids'];
      final rows = await all();
      if (ids is! List ||
          ids.length != ids.toSet().length ||
          ids.any((id) => !rows.any((r) => r['id'] == id)))
        throw const FormatException('ids 必须为已存在且不重复的纪念日 ID');
      final ordered = [
        ...ids,
        ...rows.map((r) => r['id']).where((id) => !ids.contains(id)),
      ];
      for (var i = 0; i < ordered.length; i++) {
        rows.firstWhere((r) => r['id'] == ordered[i])['sortIndex'] = i;
      }
      await save(rows);
      return PluginResult.success({'data': rows});
    },
    'getStats': (_, p) async =>
        PluginResult.success({'totalDays': (await all()).length}),
    'exportData': (_, p) async => PluginResult.success(await export()),
    'importData': (_, p) async {
      final rows = entityList(p['days']);
      final decoded = rows.map(_day).toList();
      final prefs = entityObject(p['preferences']);
      await ensureDomainBackup(data, 'day');
      final current = await all();
      for (final row in decoded) {
        if (!current.any((r) => r['id'] == row['id'])) current.add(row);
      }
      await save(current);
      await data.write('day', 'view_preference.json', {
        ...await preferences(),
        ...prefs,
      });
      return PluginResult.success({
        'inserted': current.length - (await all()).length,
        'total': current.length,
      });
    },
    'seedExamples': (_, p) async {
      if (p['templateVersion'] != null && p['templateVersion'] != 1)
        return const PluginResult.failure('未知示例版本', 'UNSUPPORTED');
      if (await data.read('day', 'sdk_examples_v1.json') != null)
        return PluginResult.success({'inserted': 0, 'templateVersion': 1});
      final rows = await all();
      final now = DateTime.now();
      final examples = [
        {
          'id': 'seed_day_v1_new_year',
          'title': '新年倒计时',
          'targetDate': DateTime(now.year + 1, 1, 1).toIso8601String(),
        },
        {
          'id': 'seed_day_v1_anniversary',
          'title': '相识纪念日',
          'targetDate': DateTime(
            now.year,
            now.month,
            now.day + 30,
          ).toIso8601String(),
          'recurrenceUnit': 'years',
          'recurrenceInterval': 1,
        },
      ];
      var inserted = 0;
      for (final row in examples) {
        if (!rows.any((r) => r['id'] == row['id'])) {
          rows.add(_day(row));
          inserted++;
        }
      }
      await save(rows);
      await data.write('day', 'sdk_examples_v1.json', {'templateVersion': 1});
      return PluginResult.success({'inserted': inserted, 'templateVersion': 1});
    },
  };
}

Map<String, dynamic> _day(Map<String, dynamic> raw) {
  final now = DateTime.now().toIso8601String();
  final row = <String, dynamic>{
    'notes': <String>[],
    'noteDates': <String?>[],
    'backgroundColor': 0xff90caf9,
    'sortIndex': 0,
    'recurrenceInterval': 1,
    'creationDate': raw['createdAt'] ?? now,
    ...raw,
  };
  requiredText(row, 'id');
  requiredText(row, 'title');
  validDate(row['creationDate'], 'creationDate');
  validDate(row['targetDate'] ?? row['date'], 'targetDate');
  row['targetDate'] ??= row['date'];
  if (row['recurrenceUnit'] != null &&
      !['days', 'months', 'years'].contains(row['recurrenceUnit']))
    throw const FormatException('无效循环单位');
  if (row['recurrenceInterval'] is! int ||
      (row['recurrenceInterval'] as int) < 1 ||
      row['sortIndex'] is! num ||
      row['backgroundColor'] is! int)
    throw const FormatException('无效纪念日数字字段');
  if (row['notes'] is! List ||
      (row['notes'] as List).any((v) => v is! String) ||
      row['noteDates'] is! List)
    throw const FormatException('无效纪念日笔记');
  final dates = row['noteDates'] as List;
  row['noteDates'] = [
    for (var i = 0; i < (row['notes'] as List).length; i++)
      i < dates.length ? dates[i] : null,
  ];
  for (final date in row['noteDates'] as List) {
    if (date != null) validDate(date, 'noteDate');
  }
  return row;
}

DateTime _dayDue(Map<String, dynamic> row, DateTime today) {
  final raw = validDate(row['targetDate'], 'targetDate');
  var due = DateTime(raw.year, raw.month, raw.day);
  final unit = row['recurrenceUnit'];
  final interval = row['recurrenceInterval'] as int;
  if (unit == 'days' && due.isBefore(today)) {
    final d = today.difference(due).inDays;
    return due.add(Duration(days: ((d + interval - 1) ~/ interval) * interval));
  }
  while (unit != null && due.isBefore(today)) {
    due = unit == 'months'
        ? DateTime(due.year, due.month + interval, due.day)
        : DateTime(due.year + interval, due.month, due.day);
  }
  return due;
}
