import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_models/shared_models.dart';

import '../../storage_errors.dart';
import '../plugin_data.dart';

const _backup = 'diary/v1_backup.json';
const _manifest = 'diary/v1.json';

Never _corrupt(String detail) =>
    throw StorageException(StorageErrorKind.invalidData, detail);

dynamic _canonical(dynamic value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _hash(dynamic value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

Future<Map<String, dynamic>> _files(PluginData data) async => {
  for (final file in await data.listFiles('diary'))
    file: await data.read('diary', file),
};

Map<String, Map<String, dynamic>> _entries(Map<String, dynamic> files) {
  final entries = <String, Map<String, dynamic>>{};
  for (final file in files.keys) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}\.json$').hasMatch(file)) continue;
    final raw = files[file];
    if (raw is! Map<String, dynamic>) _corrupt('日记结构损坏: $file');
    try {
      final day = DiaryCodec.date(file.substring(0, 10));
      final entry = DiaryCodec.entry(raw);
      if (entry['date'] != day || entry['content'] != raw['content']) {
        _corrupt('日记迁移前后日期或内容不一致: $file');
      }
      entries[day] = entry;
    } on FormatException catch (error) {
      _corrupt('$file: ${error.message}');
    }
  }
  final index = files['diary_index.json'];
  if (index != null && index is! Map<String, dynamic>) _corrupt('日记索引损坏');
  if (index is Map) {
    for (final key in index.keys.cast<String>()) {
      if ([
        'totalCharCount',
        'entryCount',
        'schemaVersion',
        'diary_index.json',
      ].contains(key))
        continue;
      if (!entries.containsKey(key) || index[key] is! Map) {
        _corrupt('日记索引引用缺失或损坏: $key');
      }
    }
  }
  return entries;
}

/// 由命令事务调用。备份保留全部 JSON 字段，校验按 JSON 语义计算，
/// 不将空白/缩进视为内容变化；损坏文件不会被迁移或替换。
Future<void> prepareDiaryMigration(PluginData data) async {
  final existing = await data.read('sdk_migrations', _manifest);
  if (existing != null) {
    if (existing is! Map ||
        existing['schemaVersion'] != 1 ||
        existing['verified'] != true) {
      _corrupt('日记迁移记录损坏');
    }
    return;
  }
  final original = await _files(data);
  final entries = _entries(original);
  final checksum = _hash(original);
  final backup = {
    'schemaVersion': 1,
    'domain': 'diary',
    'checksum': checksum,
    'files': original,
  };
  await data.write('sdk_migrations', _backup, backup);
  if (_hash((await data.read('sdk_migrations', _backup))['files']) !=
      checksum) {
    _corrupt('日记备份校验失败');
  }
  final index = <String, dynamic>{
    ...original['diary_index.json'] as Map? ?? {},
    'schemaVersion': 1,
    'entryCount': entries.length,
    'totalCharCount': 0,
  };
  var words = 0;
  for (final entry in entries.entries) {
    final value = entry.value;
    final length = DiaryCodec.plainText(
      value['content'] as String,
    ).trim().length;
    words += length;
    index[entry.key] = {
      ...index[entry.key] as Map? ?? {},
      'lastUpdated': value['updatedAt'],
      'contentLength': length,
    };
    await data.write('diary', '${entry.key}.json', value);
  }
  index['totalCharCount'] = words;
  await data.write('diary', 'diary_index.json', index);
  final migrated = await _files(data);
  final after = _entries(migrated);
  if (after.length != entries.length ||
      entries.keys.any(
        (id) => after[id]?['content'] != entries[id]?['content'],
      ) ||
      _hash(after) != _hash(entries)) {
    _corrupt('日记迁移实体/内容校验失败');
  }
  await data.write('sdk_migrations', _manifest, {
    'schemaVersion': 1,
    'verified': true,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'entryCount': entries.length,
    'entryIds': entries.keys.toList()..sort(),
    'backupChecksum': checksum,
    'normalizedChecksum': _hash(migrated),
    'fileChecksums': {
      for (final file in original.entries) file.key: _hash(file.value),
    },
  });
}

Future<Map<String, dynamic>> diaryMigrationReport(PluginData data) async =>
    Map<String, dynamic>.from(
      await data.read('sdk_migrations', _manifest) as Map? ?? {},
    );

/// 受控恢复服务，只能在调用者创建的 SDK 维护事务中执行。
/// 恢复前保存当前快照，允许再次恢复，避免直接拿旧客户端覆盖新数据。
Future<void> restoreDiaryMigrationBackup(PluginData data) async {
  final raw = await data.read('sdk_migrations', _backup);
  if (raw is! Map ||
      raw['domain'] != 'diary' ||
      raw['schemaVersion'] != 1 ||
      raw['files'] is! Map<String, dynamic> ||
      _hash(raw['files']) != raw['checksum']) {
    _corrupt('日记迁移备份损坏或不存在');
  }
  final files = Map<String, dynamic>.from(raw['files'] as Map);
  if (files.keys.any(
    (file) =>
        !file.endsWith('.json') ||
        file.split('/').any((part) => part.isEmpty || part == '.' || part == '..' || part.contains('\\') || part.contains(':') || part.contains('\u0000')),
  )) {
    _corrupt('日记备份文件名错误');
  }
  _entries(files);
  final current = await _files(data);
  await data.write('sdk_migrations', 'diary/before_restore.json', {
    'schemaVersion': 1,
    'domain': 'diary',
    'files': current,
    'checksum': _hash(current),
  });
  for (final file in current.keys) {
    if (!files.containsKey(file)) await data.delete('diary', file);
  }
  for (final entry in files.entries) {
    await data.write('diary', entry.key, entry.value);
  }
  await data.delete('sdk_migrations', _manifest);
  if (_hash(await _files(data)) != raw['checksum']) _corrupt('日记备份恢复校验失败');
}
