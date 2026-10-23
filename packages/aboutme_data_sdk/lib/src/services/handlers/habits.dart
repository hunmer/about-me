import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

/// Habits 域业务：habits/skills 双主集合（顶层 List，与旧客户端文件格式一致）、
/// 每个父级（习惯/技能）一个打卡记录分文件、视图偏好单文件。
/// 主集合首次成功写前把原始文件快照到 migration_v1_backup.json
/// （records 分文件与 view_settings 不纳入快照）。
PluginHandlers createHabitsHandlers(PluginData data) {
  const plugin = 'habits';

  Future<List<Map<String, dynamic>>> readRows(String file, String key) async {
    final raw = await data.read(plugin, file);
    if (raw == null) return [];
    final rows = raw is List ? raw : raw is Map ? raw[key] : null;
    if (rows is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final result = <Map<String, dynamic>>[];
    for (final e in rows) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/$file row');
      result.add(Map<String, dynamic>.from(e));
    }
    return result;
  }

  Future<Map<String, dynamic>> readSettings() async {
    final raw = await data.read(plugin, 'view_settings.json');
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> backup() async {
    if (await data.read(plugin, 'migration_v1_backup.json') != null) return;
    await data.write(plugin, 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'habits': await data.read(plugin, 'habits.json'),
      'skills': await data.read(plugin, 'skills.json'),
    });
  }

  Future<void> saveHabits(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'habits.json', rows);
  }

  Future<void> saveSkills(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'skills.json', rows);
  }

  void checkParentId(dynamic value) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\'))
      throw ArgumentError('parentId required');
  }

  // 与客户端 updateTotalDuration 同源：总时长为记录秒数截断分钟之和。
  int totalMinutes(List<Map<String, dynamic>> records) => records.fold(
    0,
    (sum, r) => sum + domainNumber(r['duration']).toInt() ~/ 60,
  );

  void applyTotal(
    List<Map<String, dynamic>> habits,
    String parentId,
    List<Map<String, dynamic>> records,
  ) {
    final i = habits.indexWhere((h) => h['id'] == parentId);
    if (i >= 0) habits[i]['totalDurationMinutes'] = totalMinutes(records);
  }

  // 记录变更后联动习惯总时长缓存；父级不是习惯时（技能记录）只写记录文件。
  Future<void> syncHabitTotal(
    List<Map<String, dynamic>> records,
    String parentId,
  ) async {
    final habits = await readRows('habits.json', 'habits');
    applyTotal(habits, parentId, records);
    if (habits.any((h) => h['id'] == parentId)) await saveHabits(habits);
  }

  Map<String, dynamic> patchOf(Map<String, dynamic> p) => domainPatch(p)
    ..remove('id')
    ..remove('habitId');

  return {
    'getSnapshot': domainAction((_) async => {
      'habits': await readRows('habits.json', 'habits'),
      'skills': await readRows('skills.json', 'skills'),
      'settings': await readSettings(),
    }),
    'getList': domainAction((p) async {
      var rows = await readRows('habits.json', 'habits');
      final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
      rows = rows
          .where((h) {
            if (p['group'] != null && h['group'] != p['group']) return false;
            if (p['skillId'] != null && h['skillId'] != p['skillId'])
              return false;
            if (keyword.isNotEmpty &&
                !'${h['title'] ?? ''}'.toLowerCase().contains(keyword)) {
              return false;
            }
            return true;
          })
          .toList();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'getById': domainAction((p) async {
      final rows = await readRows('habits.json', 'habits');
      return rows[domainIndex(rows, p['id'])];
    }),
    'create': domainAction((p) async {
      final rows = await readRows('habits.json', 'habits');
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Habit exists');
      final habit = <String, dynamic>{
        'notes': null,
        'group': null,
        'icon': null,
        'image': null,
        'reminderDays': <dynamic>[],
        'intervalDays': 0,
        'durationMinutes': 0,
        'tags': <dynamic>[],
        'skillId': null,
        'totalDurationMinutes': 0,
        ...patchOf(p),
        'id': id,
      };
      if (habit['title'] is! String || (habit['title'] as String).isEmpty)
        throw ArgumentError('title required');
      rows.add(habit);
      await saveHabits(rows);
      return habit;
    }),
    'update': domainAction((p) async {
      final rows = await readRows('habits.json', 'habits');
      final i = domainIndex(rows, p['id']);
      rows[i] = {...rows[i], ...patchOf(p)};
      await saveHabits(rows);
      return rows[i];
    }),
    'delete': domainAction((p) async {
      final rows = await readRows('habits.json', 'habits');
      rows.removeAt(domainIndex(rows, p['id']));
      await saveHabits(rows);
      return {'id': p['id']};
    }),
    'getSkills': domainAction((p) async {
      var rows = await readRows('skills.json', 'skills');
      final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
      rows = rows
          .where((s) {
            if (p['group'] != null && s['group'] != p['group']) return false;
            if (keyword.isNotEmpty &&
                !'${s['title'] ?? ''}'.toLowerCase().contains(keyword)) {
              return false;
            }
            return true;
          })
          .toList();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'getSkillById': domainAction((p) async {
      final rows = await readRows('skills.json', 'skills');
      return rows[domainIndex(rows, p['id'])];
    }),
    'createSkill': domainAction((p) async {
      final rows = await readRows('skills.json', 'skills');
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Skill exists');
      final skill = <String, dynamic>{
        'description': null,
        'notes': null,
        'group': null,
        'icon': null,
        'image': null,
        'targetMinutes': 0,
        'maxDurationMinutes': 0,
        ...patchOf(p),
        'id': id,
      };
      if (skill['title'] is! String || (skill['title'] as String).isEmpty)
        throw ArgumentError('title required');
      rows.add(skill);
      await saveSkills(rows);
      return skill;
    }),
    'updateSkill': domainAction((p) async {
      final rows = await readRows('skills.json', 'skills');
      final i = domainIndex(rows, p['id']);
      rows[i] = {...rows[i], ...patchOf(p)};
      await saveSkills(rows);
      return rows[i];
    }),
    'deleteSkill': domainAction((p) async {
      final rows = await readRows('skills.json', 'skills');
      rows.removeAt(domainIndex(rows, p['id']));
      await saveSkills(rows);
      return {'id': p['id']};
    }),
    'getRecords': domainAction((p) async {
      final parentId = p['parentId'] ?? p['habitId'];
      checkParentId(parentId);
      final rows = await readRows('records/$parentId.json', 'records');
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'addRecord': domainAction((p) async {
      final parentId = p['parentId'] ?? p['habitId'];
      checkParentId(parentId);
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      final rows = await readRows('records/$parentId.json', 'records');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Record exists');
      final date = p['date'] ?? DateTime.now().toIso8601String();
      if (DateTime.tryParse('$date') == null)
        throw ArgumentError('Invalid date');
      final duration = domainNumber(
        p['duration'] ?? p['durationSeconds'] ?? 0,
      ).toInt();
      if (duration < 0) throw ArgumentError('duration invalid');
      final record = <String, dynamic>{
        ...patchOf(p)..remove('durationSeconds'),
        'id': id,
        'parentId': parentId,
        'date': '$date',
        'duration': duration,
      };
      rows.add(record);
      await data.write(plugin, 'records/$parentId.json', rows);
      await syncHabitTotal(rows, parentId);
      return record;
    }),
    'deleteRecord': domainAction((p) async {
      final id = p['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('id required');
      final parentId = p['parentId'] ?? p['habitId'];
      final files = parentId is String && parentId.isNotEmpty
          ? ['records/$parentId.json']
          : await data.listFiles(plugin, 'records/*.json');
      for (final file in files) {
        final rows = await readRows(file, 'records');
        final i = rows.indexWhere((e) => e['id'] == id);
        if (i < 0) continue;
        rows.removeAt(i);
        await data.write(plugin, file, rows);
        final owner = file.substring(
          'records/'.length,
          file.length - '.json'.length,
        );
        await syncHabitTotal(rows, owner);
        return {'id': id, 'parentId': owner};
      }
      throw const DomainFailure('NOT_FOUND', 'Record not found');
    }),
    'clearRecords': domainAction((p) async {
      final parentId = p['parentId'] ?? p['habitId'];
      checkParentId(parentId);
      await data.write(plugin, 'records/$parentId.json', <dynamic>[]);
      await syncHabitTotal(const [], parentId);
      return {'parentId': parentId};
    }),
    'getSettings': domainAction((_) => readSettings()),
    'updateSettings': domainAction((p) async {
      final settings = await readSettings();
      settings.addAll(domainPatch(p));
      await data.write(plugin, 'view_settings.json', settings);
      return settings;
    }),
    'getStats': domainAction((p) async {
      final habitId = p['habitId'] ?? p['id'];
      checkParentId(habitId);
      final rows = await readRows('records/$habitId.json', 'records');
      return {
        'habitId': habitId,
        'totalDurationMinutes': totalMinutes(rows),
        'completionCount': rows.length,
      };
    }),
    'seedExamples': domainAction((p) async {
      var insertedHabits = 0, insertedSkills = 0, insertedRecords = 0;
      final habitsPayload = p['habits'];
      if (habitsPayload is List && habitsPayload.isNotEmpty) {
        final rows = await readRows('habits.json', 'habits');
        if (rows.isEmpty) {
          for (final e in habitsPayload) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure('CORRUPT_DATA', 'Invalid example habit');
            rows.add(Map<String, dynamic>.from(e));
          }
          await saveHabits(rows);
          insertedHabits = rows.length;
        }
      }
      final skillsPayload = p['skills'];
      if (skillsPayload is List && skillsPayload.isNotEmpty) {
        final rows = await readRows('skills.json', 'skills');
        if (rows.isEmpty) {
          for (final e in skillsPayload) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure('CORRUPT_DATA', 'Invalid example skill');
            rows.add(Map<String, dynamic>.from(e));
          }
          await saveSkills(rows);
          insertedSkills = rows.length;
        }
      }
      final recordsPayload = p['records'];
      if (recordsPayload is Map) {
        for (final entry in recordsPayload.entries) {
          checkParentId(entry.key);
          final list = entry.value;
          if (list is! List || list.isEmpty) continue;
          if ((await readRows('records/${entry.key}.json', 'records'))
              .isNotEmpty) {
            continue;
          }
          final seed = <Map<String, dynamic>>[];
          for (final e in list) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure(
                'CORRUPT_DATA',
                'Invalid example record',
              );
            seed.add(Map<String, dynamic>.from(e));
          }
          await data.write(plugin, 'records/${entry.key}.json', seed);
          insertedRecords += seed.length;
        }
      }
      return {
        'insertedHabits': insertedHabits,
        'insertedSkills': insertedSkills,
        'insertedRecords': insertedRecords,
      };
    }),
  };
}
