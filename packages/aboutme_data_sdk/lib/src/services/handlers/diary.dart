import 'package:shared_models/shared_models.dart';
import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import '../templates/diary_examples.dart';
import '../migrations/diary_migration.dart';

PluginHandlers createDiaryHandlers(PluginData data) {
  Future<Map<String, dynamic>> object(String file) async {
    final value = await data.read('diary', file);
    if (value == null) return {};
    if (value is! Map<String, dynamic>)
      throw StorageException(StorageErrorKind.invalidData, '日记文件结构损坏: $file');
    return value;
  }

  Future<Map<String, dynamic>?> readEntry(String day) async {
    final value = await data.read('diary', '$day.json');
    if (value == null) return null;
    if (value is! Map<String, dynamic>)
      throw StorageException(StorageErrorKind.invalidData, '日记结构损坏: $day');
    try {
      final entry = DiaryCodec.entry(value);
      if (entry['date'] != day) throw const FormatException('日记日期与索引不一致');
      return entry;
    } on FormatException catch (error) {
      throw StorageException(
        StorageErrorKind.invalidData,
        '$day: ${error.message}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> all() async {
    final index = await object('diary_index.json');
    final entries = <Map<String, dynamic>>[];
    for (final key in index.keys) {
      if ({
        'totalCharCount',
        'entryCount',
        'schemaVersion',
        'diary_index.json',
      }.contains(key))
        continue;
      try {
        DiaryCodec.date(key);
      } on FormatException {
        throw StorageException(StorageErrorKind.invalidData, '日记索引日期损坏: $key');
      }
      if (index[key] is! Map) throw StorageException(StorageErrorKind.invalidData, '日记索引条目损坏: $key');
      final entry = await readEntry(key);
      if (entry == null)
        throw StorageException(
          StorageErrorKind.invalidData,
          '日记索引引用不存在的条目: $key',
        );
      entries.add(entry);
    }
    entries.sort(
      (a, b) => (b['date'] as String).compareTo(a['date'] as String),
    );
    return entries;
  }

  int length(Map<String, dynamic> entry) =>
      DiaryCodec.plainText(entry['content'] as String).trim().length;
  Future<void> updateIndex(String day, Map<String, dynamic>? entry) async {
    final index = await object('diary_index.json');
    if (entry == null) {
      index.remove(day);
    } else {
      if (index.containsKey(day) && index[day] is! Map) {
        throw StorageException(StorageErrorKind.invalidData, '日记索引条目损坏: $day');
      }
      index[day] = {
        ...index[day] as Map? ?? {},
        'lastUpdated': entry['updatedAt'],
        'contentLength': length(entry),
      };
    }
    // 先暂存索引，重算旧索引中缺失/陈旧的统计；所有读取仍位于本次事务内。
    await data.write('diary', 'diary_index.json', index);
    final entries = await all();
    index['totalCharCount'] = entries.fold<int>(
      0,
      (sum, entry) => sum + length(entry),
    );
    index['entryCount'] = entries.length;
    index['schemaVersion'] = 1;
    await data.write('diary', 'diary_index.json', index);
  }

  Future<PluginResult> save(
    Map<String, dynamic> params, {
    bool mustExist = false,
    bool mustBeNew = false,
  }) async {
    final day = DiaryCodec.date(params['date']?.toString() ?? '');
    if (params.containsKey('content') && params['content'] is! String) {
      throw const FormatException('content 必须是字符串');
    }
    final existing = await readEntry(day);
    if (mustExist && existing == null)
      return const PluginResult.failure('日记不存在', 'NOT_FOUND');
    if (mustBeNew && existing != null)
      return const PluginResult.failure('该日期已有日记', 'CONFLICT');
    final now = jsIsoDateTime(DateTime.now());
    final patch = Map<String, dynamic>.from(params)
      ..remove('createdAt')
      ..remove('updatedAt')
      ..remove('sdkVersion');
    if (patch.containsKey('content') && !patch.containsKey('contentFormat'))
      patch['contentFormat'] = null;
    final next = DiaryCodec.entry({
      ...?existing,
      ...patch,
      'date': day,
      'content': patch['content'] ?? existing?['content'] ?? '',
      'createdAt': existing?['createdAt'] ?? now,
      'updatedAt': now,
    });
    await data.write('diary', '$day.json', next);
    await updateIndex(day, next);
    return PluginResult.success(next);
  }

  Future<PluginResult> list(Map<String, dynamic> params, {bool snapshot = false}) async {
    var entries = await all();
    final start = params['startDate'] == null
        ? null
        : DiaryCodec.date(params['startDate'].toString());
    final end = params['endDate'] == null
        ? null
        : DiaryCodec.date(params['endDate'].toString());
    final keyword = params['keyword']?.toString().trim().toLowerCase();
    entries = entries.where((entry) {
      final day = entry['date'] as String;
      if (start != null && day.compareTo(start) < 0) return false;
      if (end != null && day.compareTo(end) > 0) return false;
      if (params['mood'] != null && entry['mood'] != params['mood'])
        return false;
      if (keyword == null || keyword.isEmpty) return true;
      return '${entry['title']}\n${DiaryCodec.plainText(entry['content'] as String)}\n${(entry['tags'] as List).join(' ')}'
          .toLowerCase()
          .contains(keyword);
    }).toList();
    return PluginResult.success(
      createPaginatedResult(
        entries,
        offset: snapshot ? 0 : params['offset'] as int?,
        count: snapshot ? entries.length : params['count'] as int?,
      ),
    );
  }

  return {
    'migrate': (_, __) async {
      await prepareDiaryMigration(data);
      return PluginResult.success(await diaryMigrationReport(data));
    },
    'getMigrationReport': (_, __) async => PluginResult.success(await diaryMigrationReport(data)),
    'exportEntries': (_, params) async => PluginResult.success({
      'schemaVersion': 1, 'domain': 'diary', 'entries': await all(),
    }),
    'importEntries': (_, params) async {
      final raw = params['entries'];
      if (params['schemaVersion'] != 1 || raw is! List || raw.length > 100) {
        return const PluginResult.failure('导入需要 schemaVersion=1，且每批不超过 100 篇日记', 'INVALID_PARAMS');
      }
      final entries = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final item in raw) {
        if (item is! Map<String, dynamic>) throw const FormatException('导入日记必须是对象');
        final entry = DiaryCodec.entry(item);
        if (!ids.add(entry['date'] as String)) throw const FormatException('同批导入日期不能重复');
        entries.add(entry);
      }
      // 先读取并验证全域，损坏文件不能被一次导入隐藏或覆盖。
      final existing = {for (final entry in await all()) entry['date']};
      final created = <String>[];
      final skipped = <String>[];
      for (final entry in entries) {
        final day = entry['date'] as String;
        if (existing.contains(day) || await readEntry(day) != null) {
          skipped.add(day);
          continue;
        }
        await data.write('diary', '$day.json', entry);
        await updateIndex(day, entry);
        created.add(day);
      }
      return PluginResult.success({'created': created, 'skipped': skipped});
    },
    'getList': (_, params) => list(params),
    // 日历/统计需要一致的完整快照；普通列表仍保留分页语义。
    'getSnapshot': (_, params) => list(params, snapshot: true),
    'search': (_, params) => list(params),
    'getByDate': (_, params) async {
      final entry = await readEntry(DiaryCodec.date(params['date'].toString()));
      return entry == null
          ? const PluginResult.failure('日记不存在', 'NOT_FOUND')
          : PluginResult.success(entry);
    },
    'create': (_, params) => save(params, mustBeNew: true),
    'updateByDate': (_, params) => save(params, mustExist: true),
    'save': (_, params) => save(params),
    'deleteByDate': (_, params) async {
      final day = DiaryCodec.date(params['date'].toString());
      if (await readEntry(day) == null)
        return const PluginResult.failure('日记不存在', 'NOT_FOUND');
      await data.delete('diary', '$day.json');
      await updateIndex(day, null);
      return PluginResult.success({'date': day});
    },
    'getStats': (_, __) async {
      final entries = await all();
      final words = entries.fold<int>(0, (sum, entry) => sum + length(entry));
      final average = entries.isEmpty ? 0 : (words / entries.length).round();
      return PluginResult.success({
        'totalEntries': entries.length,
        'totalWords': words,
        'averageWords': average,
        'entryCount': entries.length,
        'totalCharCount': words,
        'averageCharCount': average,
      });
    },
    'seedExamples': (_, params) async {
      if (params['templateVersion'] != 1 ||
          params['groups'] is! List ||
          (params['groups'] as List).any((group) => group != 'entries')) {
        return const PluginResult.failure('不支持的日记示例模板', 'INVALID_PARAMS');
      }
      final marker = await object('seed_examples.json');
      if ((params['groups'] as List).isEmpty) return PluginResult.success({'created': []});
      if (marker['entries:1'] == true)
        return PluginResult.success({'created': [], 'skipped': true});
      final created = <String>[];
      for (final dto in DiarySampleData.getSampleDiaryEntries()) {
        final entry = DiaryCodec.entry(dto.toJson());
        final day = entry['date'] as String;
        if (await readEntry(day) != null) continue;
        await data.write('diary', '$day.json', {
          ...entry,
          'seedKey': 'entries:1:${created.length}',
        });
        await updateIndex(day, entry);
        created.add(day);
      }
      await data.write('diary', 'seed_examples.json', {
        ...marker,
        'entries:1': true,
      });
      return PluginResult.success({'created': created});
    },
  };
}
