import '../migrations/record_domains_migration.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

PluginHandlers createTrackerHandlers(PluginData data) {
  Future<Map<String, dynamic>> goalsFile() =>
      readDomainFile(data, 'tracker', 'goals.json', ['goals']);
  Future<Map<String, dynamic>> recordsFile() =>
      readDomainFile(data, 'tracker', 'records.json', ['records']);
  Future<void> saveGoals(Map<String, dynamic> f) =>
      data.write('tracker', 'goals.json', f);
  Future<void> saveRecords(Map<String, dynamic> f) =>
      data.write('tracker', 'records.json', f);
  bool completed(Map goal) =>
      domainNumber(goal['currentValue']) >= domainNumber(goal['targetValue']);
  void validateGoal(Map goal) {
    if ('${goal['name'] ?? ''}'.trim().isEmpty ||
        domainNumber(goal['targetValue']) <= 0)
      throw ArgumentError('Name and positive targetValue required');
    if (!domainNumber(goal['targetValue']).isFinite ||
        !domainNumber(goal['currentValue']).isFinite)
      throw ArgumentError('Values must be finite');
    final dates = goal['dateSettings'];
    if (dates is Map &&
        dates['startDate'] != null &&
        dates['endDate'] != null &&
        DateTime.parse(
          dates['startDate'],
        ).isAfter(DateTime.parse(dates['endDate'])))
      throw ArgumentError('Invalid date range');
  }

  void setValue(Map<String, dynamic> goal, num value) {
    goal['currentValue'] = value;
    goal['isCompleted'] = completed(goal);
    goal['updatedAt'] = DateTime.now().toIso8601String();
    goal['completedAt'] = completed(goal)
        ? goal['completedAt'] ?? goal['updatedAt']
        : null;
  }

  Future<dynamic> listGoals(Map<String, dynamic> p) async {
    var rows = domainRows(await goalsFile(), 'goals')
        .where((g) {
          if (p['status'] == 'active' && completed(g)) return false;
          if (p['status'] == 'completed' && !completed(g)) return false;
          if (p['group'] != null && g['group'] != p['group']) return false;
          if (p['field'] != null && p['value'] != null) {
            final actual = '${g[p['field']] ?? ''}', wanted = '${p['value']}';
            if (p['fuzzy'] == true
                ? !actual.toLowerCase().contains(wanted.toLowerCase())
                : actual != wanted)
              return false;
          }
          return true;
        })
        .map((g) => <String, dynamic>{...g, 'isCompleted': completed(g)})
        .toList();
    rows.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    return createPaginatedResult(
      rows,
      offset: p['offset'] as int?,
      count: p['count'] as int? ?? rows.length,
    );
  }

  Future<dynamic> listRecords(Map<String, dynamic> p) async {
    final rows = domainRows(await recordsFile(), 'records').where((r) {
      if (p['goalId'] != null && r['goalId'] != p['goalId']) return false;
      final date = '${r['recordedAt'] ?? r['date'] ?? ''}';
      if (p['startDate'] != null && date.compareTo('${p['startDate']}') < 0)
        return false;
      if (p['endDate'] != null && date.compareTo('${p['endDate']}') > 0)
        return false;
      if (p['field'] != null && p['value'] != null) {
        final actual = '${r[p['field']] ?? ''}', wanted = '${p['value']}';
        if (p['fuzzy'] == true
            ? !actual.toLowerCase().contains(wanted.toLowerCase())
            : actual != wanted)
          return false;
      }
      return true;
    }).toList();
    rows.sort((a, b) {
      final date = '${b['recordedAt']}'.compareTo('${a['recordedAt']}');
      return date != 0 ? date : '${b['id']}'.compareTo('${a['id']}');
    });
    return createPaginatedResult(
      rows,
      offset: p['offset'] as int?,
      count: p['count'] as int? ?? rows.length,
    );
  }

  return withRecordDomainMigration(data, 'tracker', {
    'getSnapshot': domainAction((p) async {
      final g = await goalsFile(), r = await recordsFile();
      return {'goals': g['goals'], 'records': r['records']};
    }),
    'getList': domainAction(listGoals),
    'getRecords': domainAction(listRecords),
    'searchRecords': domainAction(listRecords),
    'getById': domainAction((p) async {
      final rows = domainRows(await goalsFile(), 'goals');
      final g = rows[domainIndex(rows, p['id'])];
      return {...g, 'isCompleted': completed(g)};
    }),
    'create': domainAction((p) async {
      final f = await goalsFile(), rows = domainRows(f, 'goals');
      final id = p['id'] ?? generateUUID();
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Goal exists');
      final goal = <String, dynamic>{
        'currentValue': 0,
        'icon': '57455',
        'unitType': '次',
        'group': '默认',
        'dateSettings': {'type': 'daily'},
        'isLoopReset': false,
        'createdAt': DateTime.now().toIso8601String(),
        ...domainPatch(p),
        'id': id,
      };
      validateGoal(goal);
      setValue(goal, domainNumber(goal['currentValue']));
      rows.add(goal);
      await saveGoals(f);
      return goal;
    }),
    'update': domainAction((p) async {
      final f = await goalsFile(), rows = domainRows(f, 'goals');
      final i = domainIndex(rows, p['id']);
      final patch = domainPatch(p)
        ..remove('createdAt')
        ..remove('isCompleted');
      final goal = <String, dynamic>{...rows[i], ...patch};
      validateGoal(goal);
      setValue(goal, domainNumber(goal['currentValue']));
      rows[i] = goal;
      await saveGoals(f);
      return goal;
    }),
    'toggleCompletion': domainAction((p) async {
      final f = await goalsFile(), rows = domainRows(f, 'goals');
      final i = domainIndex(rows, p['id']);
      setValue(
        rows[i],
        completed(rows[i]) ? 0 : domainNumber(rows[i]['targetValue']),
      );
      await saveGoals(f);
      return rows[i];
    }),
    'delete': domainAction((p) async {
      final g = await goalsFile(), r = await recordsFile();
      final rows = domainRows(g, 'goals');
      rows.removeAt(domainIndex(rows, p['id']));
      domainRows(r, 'records').removeWhere((e) => e['goalId'] == p['id']);
      await saveGoals(g);
      await saveRecords(r);
      return {'id': p['id']};
    }),
    'addRecord': domainAction((p) async {
      final g = await goalsFile(),
          r = await recordsFile(),
          goals = domainRows(g, 'goals'),
          records = domainRows(r, 'records');
      final i = domainIndex(goals, p['goalId']);
      final value = p['value'];
      if (value is! num || !value.isFinite || value <= 0)
        throw ArgumentError('Positive finite record value required');
      final id = p['id'] ?? generateUUID();
      if (records.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Record exists');
      final timestamp =
          p['recordedAt'] ?? p['date'] ?? DateTime.now().toIso8601String();
      if (DateTime.tryParse('$timestamp') == null)
        throw ArgumentError('Invalid recordedAt');
      final record = <String, dynamic>{
        ...domainPatch(p),
        'id': id,
        'recordedAt': timestamp,
        'createdAt': DateTime.now().toIso8601String(),
      };
      records.add(record);
      setValue(goals[i], domainNumber(goals[i]['currentValue']) + value);
      await saveRecords(r);
      await saveGoals(g);
      return record;
    }),
    'deleteRecord': domainAction((p) async {
      final g = await goalsFile(),
          r = await recordsFile(),
          goals = domainRows(g, 'goals'),
          records = domainRows(r, 'records');
      final record = records.removeAt(domainIndex(records, p['id']));
      final i = domainIndex(goals, record['goalId']);
      setValue(
        goals[i],
        (domainNumber(goals[i]['currentValue']) - domainNumber(record['value']))
            .clamp(0, double.infinity),
      );
      await saveRecords(r);
      await saveGoals(g);
      return {'id': p['id']};
    }),
    'clearRecords': domainAction((p) async {
      final g = await goalsFile(),
          r = await recordsFile(),
          goals = domainRows(g, 'goals');
      final i = domainIndex(goals, p['goalId']);
      domainRows(r, 'records').removeWhere((e) => e['goalId'] == p['goalId']);
      setValue(goals[i], 0);
      await saveRecords(r);
      await saveGoals(g);
      return {'goalId': p['goalId']};
    }),
    'getStats': domainAction((p) async {
      final goals = domainRows(await goalsFile(), 'goals'),
          records = domainRows(await recordsFile(), 'records');
      final now = DateTime.now(),
          today = formatDate(DateTime.now()),
          month = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final complete = goals.where(completed).length;
      bool since(Map g, String field, DateTime date) =>
          DateTime.tryParse('${g[field]}')?.isBefore(date) == false;
      return {
        'totalGoals': goals.length,
        'activeGoals': goals.length - complete,
        'completedGoals': complete,
        'totalRecords': records.length,
        'todayRecordCount': records
            .where((r) => '${r['recordedAt']}'.startsWith(today))
            .length,
        'todayCompletedGoals': goals
            .where(
              (g) =>
                  completed(g) &&
                  since(
                    g,
                    'completedAt',
                    DateTime(now.year, now.month, now.day),
                  ),
            )
            .length,
        'monthCompletedGoals': goals
            .where((g) => completed(g) && since(g, 'completedAt', month))
            .length,
        'monthAddedGoals': goals
            .where((g) => since(g, 'createdAt', month))
            .length,
      };
    }),
    'seedExamples': domainAction((p) async {
      final f = await goalsFile(), r = await recordsFile();
      if (f['exampleTemplateVersion'] != null ||
          domainRows(f, 'goals').isNotEmpty ||
          domainRows(r, 'records').isNotEmpty)
        return {'inserted': 0};
      f['goals'] = [
        {
          'id': 'seed:tracker:reading:v1',
          'name': '每日阅读',
          'icon': '57455',
          'iconColor': 0xFF2196F3,
          'unitType': '分钟',
          'targetValue': 30.0,
          'currentValue': 0.0,
          'dateSettings': {'type': 'daily'},
          'reminderTime': '09:00',
          'isLoopReset': true,
          'createdAt': DateTime.now().toIso8601String(),
          'group': '学习',
          'progressColor': 0xFF2196F3,
        },
      ];
      f['exampleTemplateVersion'] = 1;
      await saveGoals(f);
      return {'inserted': 1};
    }),
  });
}
