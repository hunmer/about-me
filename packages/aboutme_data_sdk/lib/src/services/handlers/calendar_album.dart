import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'structured_support.dart';

/// 标签偏好三文件沿用历史落盘位置（`data/` 顶层，早于插件分区目录出现），
/// 通过 'data' 分区访问以保持既有数据兼容。
const _tagFiles = <String, String>{
  'tagGroups': 'calendar_tag_groups.json',
  'recentTags': 'calendar_recent_tags.json',
  'tagIcons': 'calendar_tag_icons.json',
};

PluginHandlers createCalendarAlbumHandlers(PluginData data) {
  Future<Map<String, List<Map<String, dynamic>>>> allRows() async {
    final raw = await data.read('calendar_album', 'calendar_entries.json');
    if (raw == null) return {};
    if (raw is! Map) {
      throw const StorageException(StorageErrorKind.invalidData, '日历相册数据结构损坏');
    }
    final result = <String, List<Map<String, dynamic>>>{};
    final ids = <String>{};
    raw.forEach((key, value) {
      if (key is! String ||
          DateTime.tryParse(key) == null ||
          value is! List ||
          value.any((e) => e is! Map)) {
        throw const StorageException(StorageErrorKind.invalidData, '日历相册数据结构损坏');
      }
      final rows = [
        for (final e in value)
          decodeStored(() => _row(Map<String, dynamic>.from(e as Map))),
      ];
      for (final row in rows) {
        if (!ids.add(row['id'] as String)) {
          throw const StorageException(StorageErrorKind.invalidData, '业务 ID 缺失或重复');
        }
      }
      result[key] = rows;
    });
    return result;
  }

  Future<void> saveRows(Map<String, List<Map<String, dynamic>>> rows) async {
    // 空日期键整体移除，与客户端原行为一致。
    rows.removeWhere((_, value) => value.isEmpty);
    await data.write('calendar_album', 'calendar_entries.json', rows);
  }

  Future<Map<String, dynamic>> tags() async => {
    'tagGroups': _decodeTagGroups(
      await data.read('data', _tagFiles['tagGroups']!),
    ),
    'recentTags': _decodeRecentTags(
      await data.read('data', _tagFiles['recentTags']!),
    ),
    'tagIcons': entityObject(
      await data.read('data', _tagFiles['tagIcons']!),
    ).map((key, value) => MapEntry(key, value.toString())),
  };

  /// 首写备份：域内条目文件走通用清单；标签三文件在 `data/` 顶层，
  /// 以 `data/<文件名>` 为键补充进同一份备份。
  Future<void> ensureBackup() async {
    await ensureDomainBackup(data, 'calendar_album');
    final backup = entityObject(
      await data.read('calendar_album', 'sdk_migration_backup.json'),
    );
    final files = entityObject(backup['files']);
    final tagKey = 'data/${_tagFiles['tagGroups']}';
    if (files.containsKey(tagKey)) return;
    for (final file in _tagFiles.values) {
      files['data/$file'] = await data.read('data', file);
    }
    await data.write('calendar_album', 'sdk_migration_backup.json', {
      ...backup,
      'files': files,
    });
  }

  Future<PluginResult> updateTags(Map<String, dynamic> p) async {
    final next = <String, dynamic>{};
    for (final key in _tagFiles.keys) {
      if (!p.containsKey(key)) continue;
      final value = p[key];
      if (key == 'tagGroups') {
        if (value is! List || value.any((e) => e is! Map)) {
          throw const FormatException('tagGroups 必须为对象数组');
        }
        next[key] = [
          for (final group in value)
            _tagGroup(Map<String, dynamic>.from(group as Map)),
        ];
      } else if (key == 'recentTags') {
        if (value is! List || value.any((e) => e is! String)) {
          throw const FormatException('recentTags 必须为字符串数组');
        }
        next[key] = List<String>.from(value);
      } else {
        if (value is! Map || value.values.any((e) => e is! String)) {
          throw const FormatException('tagIcons 必须为字符串映射');
        }
        next[key] = Map<String, String>.from(value);
      }
    }
    if (next.isEmpty) throw const FormatException('缺少可更新的标签数据');
    await ensureBackup();
    for (final entry in next.entries) {
      await data.write('data', _tagFiles[entry.key]!, entry.value);
    }
    return PluginResult.success(await tags());
  }

  Future<PluginResult> list(Map<String, dynamic> p) async {
    var rows = await allRows();
    if (p['date'] != null) {
      final key = _dateKey(validDate(p['date'], 'date'));
      rows = {if (rows.containsKey(key)) key: rows[key]!};
    }
    DateTime? start;
    DateTime? end;
    if (p['month'] != null) {
      final month = p['month'].toString();
      final first = DateTime.tryParse('$month-01');
      if (month.length != 7 || first == null) {
        throw const FormatException('month 必须为 YYYY-MM');
      }
      start = DateTime(first.year, first.month);
      end = DateTime(first.year, first.month + 1);
    }
    if (p['startDate'] != null) start = _day(validDate(p['startDate'], 'startDate'));
    if (p['endDate'] != null) {
      end = _day(validDate(p['endDate'], 'endDate')).add(const Duration(days: 1));
    }
    final result = <String, List<Map<String, dynamic>>>{};
    var total = 0;
    rows.forEach((key, value) {
      final date = _day(DateTime.parse(key));
      if (start != null && date.isBefore(start)) return;
      if (end != null && !date.isBefore(end)) return;
      result[key] = value;
      total += value.length;
    });
    return PluginResult.success({'data': result, 'total': total});
  }

  Future<PluginResult> put(Map<String, dynamic> p, bool create) async {
    final id = p['id']?.toString() ?? generateUUID();
    final rows = await allRows();
    // date 仅用于定位日期键，不得混入条目字段。
    final payload = Map<String, dynamic>.from(p)..remove('date');
    final row = _row({...changedFields(payload), 'id': id});
    final key = _dateKey(p['date'] != null ? validDate(p['date'], 'date') : DateTime.parse(row['createdAt'] as String));
    final bucket = rows[key] ??= <Map<String, dynamic>>[];
    final i = bucket.indexWhere((r) => r['id'] == id);
    if (create && i >= 0) {
      return const PluginResult.failure('日记条目已存在', 'CONFLICT');
    }
    if (!create && i < 0) {
      return const PluginResult.failure('日记条目不存在', 'NOT_FOUND');
    }
    final next = i < 0 ? row : _row({...bucket[i], ...changedFields(payload), 'id': id});
    if (i < 0) {
      bucket.add(next);
    } else {
      bucket[i] = next;
    }
    await ensureBackup();
    await saveRows(rows);
    return PluginResult.success(next);
  }

  Future<PluginResult> remove(Map<String, dynamic> p) async {
    final rows = await allRows();
    final key = _dateKey(validDate(p['date'], 'date'));
    final bucket = rows[key];
    if (bucket == null || !bucket.any((r) => r['id'] == p['id'])) {
      return const PluginResult.failure('日记条目不存在', 'NOT_FOUND');
    }
    bucket.removeWhere((r) => r['id'] == p['id']);
    await ensureBackup();
    await saveRows(rows);
    return PluginResult.success({'id': p['id']});
  }

  return {
    'getSnapshot': (_, p) async => PluginResult.success({
      'data': await allRows(),
      'tags': await tags(),
    }),
    'getList': (_, p) => list(p),
    'create': (_, p) => put(p, true),
    'update': (_, p) => put(p, false),
    'delete': (_, p) => remove(p),
    'getTags': (_, p) async => PluginResult.success(await tags()),
    'updateTags': (_, p) => updateTags(p),
    'exportData': (_, p) async => PluginResult.success({
      'schemaVersion': 1,
      'entries': await allRows(),
      'tags': await tags(),
    }),
    'importData': (_, p) async {
      final raw = p['entries'];
      if (raw is! Map) throw const FormatException('entries 必须为按日期分组对象');
      final incoming = <String, List<Map<String, dynamic>>>{};
      raw.forEach((key, value) {
        final date = key is String ? DateTime.tryParse(key) : null;
        if (date == null || value is! List || value.any((e) => e is! Map)) {
          throw const FormatException('entries 必须为按日期分组对象');
        }
        incoming[_dateKey(date)] = [
          for (final e in value) _row(Map<String, dynamic>.from(e as Map)),
        ];
      });
      var inserted = 0;
      await ensureBackup();
      final rows = await allRows();
      incoming.forEach((key, value) {
        final bucket = rows[key] ??= <Map<String, dynamic>>[];
        for (final row in value) {
          if (!bucket.any((r) => r['id'] == row['id'])) {
            bucket.add(row);
            inserted++;
          }
        }
      });
      await saveRows(rows);
      if (p.containsKey('tags')) {
        await updateTags(entityObject(p['tags']));
      }
      var total = 0;
      rows.forEach((_, value) => total += value.length);
      return PluginResult.success({'inserted': inserted, 'total': total});
    },
    'getStats': (_, p) async {
      final rows = await allRows();
      final today = _day(DateTime.now());
      var entries = 0;
      var todayEntries = 0;
      final photos = <String>{};
      rows.forEach((key, value) {
        final isToday = _day(DateTime.parse(key)) == today;
        for (final row in value) {
          entries++;
          if (isToday) todayEntries++;
          photos.addAll((row['imageUrls'] as List).cast<String>());
          photos.addAll(_markdownImages(row['content'] as String));
        }
      });
      final tagGroups = _decodeTagGroups(
        await data.read('data', _tagFiles['tagGroups']!),
      );
      return PluginResult.success({
        'photoCount': photos.length,
        'totalEntries': entries,
        'todayEntries': todayEntries,
        'tagCount': tagGroups.fold<int>(
          0,
          (sum, group) => sum + (group['tags'] as List).length,
        ),
      });
    },
    'seedExamples': (_, p) async {
      if (p['templateVersion'] != null && p['templateVersion'] != 1) {
        return const PluginResult.failure('未知示例版本', 'UNSUPPORTED');
      }
      if (await data.read('calendar_album', 'sdk_examples_v1.json') != null) {
        return PluginResult.success({'inserted': 0, 'templateVersion': 1});
      }
      final now = DateTime.now();
      final examples = [
        {
          'id': 'seed_album_v1_today',
          'title': '美好的一天开始啦',
          'content': '今天天气真不错！阳光明媚，心情也特别好。',
          'createdAt': DateTime(now.year, now.month, now.day, 8, 30).toIso8601String(),
          'tags': ['生活', '心情'],
          'mood': '😊',
          'weather': '晴天',
        },
        {
          'id': 'seed_album_v1_weekend',
          'title': '周末时光',
          'content': '和朋友约好一起去公园野餐，在草地上玩了一下午。',
          'createdAt': DateTime(now.year, now.month, now.day - 3, 15, 30).toIso8601String(),
          'tags': ['休闲', '朋友'],
          'mood': '🥳',
          'weather': '晴天',
        },
      ];
      final rows = await allRows();
      var inserted = 0;
      for (final example in examples) {
        final key = _dateKey(DateTime.parse(example['createdAt'] as String));
        final bucket = rows[key] ??= <Map<String, dynamic>>[];
        if (!bucket.any((r) => r['id'] == example['id'])) {
          bucket.add(_row({...example}));
          inserted++;
        }
      }
      await ensureBackup();
      await saveRows(rows);
      await data.write('calendar_album', 'sdk_examples_v1.json', {
        'templateVersion': 1,
      });
      return PluginResult.success({'inserted': inserted, 'templateVersion': 1});
    },
  };
}

Map<String, dynamic> _row(Map<String, dynamic> raw) {
  final now = DateTime.now().toIso8601String();
  final row = <String, dynamic>{
    'content': '',
    'tags': <String>[],
    'location': null,
    'latLng': null,
    'mood': null,
    'weather': null,
    'imageUrls': <String>[],
    'thumbUrls': <String>[],
    'liveVideoUrls': <String>[],
    'createdAt': now,
    ...raw,
    'updatedAt': raw['updatedAt'] ?? raw['createdAt'] ?? now,
  };
  requiredText(row, 'id');
  requiredText(row, 'title');
  validDate(row['createdAt'], 'createdAt');
  validDate(row['updatedAt'], 'updatedAt');
  if (row['content'] is! String) throw const FormatException('content 必须为字符串');
  for (final key in ['tags', 'imageUrls', 'thumbUrls', 'liveVideoUrls']) {
    if (row[key] is! List || (row[key] as List).any((v) => v is! String)) {
      throw FormatException('无效日记条目字段: $key');
    }
  }
  for (final key in ['location', 'latLng', 'mood', 'weather']) {
    if (row[key] != null && row[key] is! String) {
      throw FormatException('无效日记条目字段: $key');
    }
  }
  return row;
}

Map<String, dynamic> _tagGroup(Map<String, dynamic> raw) {
  final group = <String, dynamic>{'tags': <String>[], ...raw};
  requiredText(group, 'name');
  if (group['tags'] is! List || (group['tags'] as List).any((v) => v is! String)) {
    throw const FormatException('标签组的 tags 必须为字符串数组');
  }
  return group;
}

List<Map<String, dynamic>> _decodeTagGroups(dynamic raw) {
  if (raw == null) return [];
  if (raw is! List || raw.any((e) => e is! Map)) {
    throw const StorageException(StorageErrorKind.invalidData, '标签组数据结构损坏');
  }
  return [
    for (final e in raw)
      decodeStored(() => _tagGroup(Map<String, dynamic>.from(e as Map))),
  ];
}

List<String> _decodeRecentTags(dynamic raw) {
  if (raw == null) return [];
  if (raw is! List || raw.any((e) => e is! String)) {
    throw const StorageException(StorageErrorKind.invalidData, '最近标签数据结构损坏');
  }
  return List<String>.from(raw);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// 日期键与客户端一致：按日归整后 ISO 字符串。
String _dateKey(DateTime value) => _day(value).toIso8601String();

List<String> _markdownImages(String content) {
  final matches = RegExp(r'!\[.*?\]\((.*?)\)').allMatches(content);
  return [for (final match in matches) match.group(1)!];
}
