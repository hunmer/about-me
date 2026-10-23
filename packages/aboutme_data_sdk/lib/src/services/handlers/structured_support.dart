import '../../storage_errors.dart';
import '../plugin_data.dart';

/// Strict legacy decoding shared by structured business handlers. It never repairs on read.
List<Map<String, dynamic>> entityList(dynamic value, {String? key}) {
  if (value == null) return [];
  if (value is Map && key != null && value.containsKey(key))
    value = value[key];
  else if (value is Map && value.values.every((v) => v is Map))
    value = value.values.toList();
  if (value is! List || value.any((v) => v is! Map)) {
    throw const StorageException(StorageErrorKind.invalidData, '业务列表结构损坏');
  }
  final result = value.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  final ids = <String>{};
  for (final entity in result) {
    if (entity['id'] is! String ||
        (entity['id'] as String).isEmpty ||
        !ids.add(entity['id'] as String)) {
      throw const StorageException(StorageErrorKind.invalidData, '业务 ID 缺失或重复');
    }
  }
  return result;
}

Map<String, dynamic> entityObject(dynamic value) {
  if (value == null) return {};
  if (value is! Map)
    throw const StorageException(StorageErrorKind.invalidData, '业务配置结构损坏');
  return Map<String, dynamic>.from(value);
}

Future<void> writeEntityList(
  PluginData data,
  String plugin,
  String file,
  List<Map<String, dynamic>> rows, {
  String? key,
}) async {
  final old = await data.read(plugin, file);
  await data.write(
    plugin,
    file,
    old is Map && key != null && old.containsKey(key)
        ? {...old, key: rows}
        : rows,
  );
}

void requiredText(Map<String, dynamic> value, String key) {
  if (value[key] is! String || (value[key] as String).trim().isEmpty)
    throw FormatException('$key 必须为非空字符串');
}

DateTime validDate(dynamic value, String key) {
  if (value is! String || DateTime.tryParse(value) == null)
    throw FormatException('$key 必须为 ISO 日期');
  return DateTime.parse(value);
}

Map<String, dynamic> pageEntities(
  List<Map<String, dynamic>> rows,
  Map<String, dynamic> params,
) {
  final offset = params['offset'] as int? ?? 0;
  final count = params['count'] as int? ?? rows.length;
  final items = rows.skip(offset).take(count).toList();
  return {
    'data': items,
    'total': rows.length,
    'offset': offset,
    'count': items.length,
    'hasMore': offset + items.length < rows.length,
  };
}

Map<String, dynamic> changedFields(Map<String, dynamic> params) =>
    Map<String, dynamic>.from(params)..remove('id');
Future<void> backupDomain(
  PluginData data,
  String plugin,
  Map<String, dynamic> snapshot,
) async {
  // Immutable first-import backup, committed with the import by the runtime journal.
  if (await data.read(plugin, 'sdk_migration_backup.json') == null) {
    await data.write(plugin, 'sdk_migration_backup.json', {
      'schemaVersion': 1,
      'snapshot': snapshot,
    });
  }
}

const structuredDomainFiles = <String, List<String>>{
  'contact': [
    'contacts.json',
    'interactions.json',
    'filter_config',
    'sort_config',
  ],
  'day': ['memorial_days.json', 'view_preference.json'],
  'calendar': ['calendar_events.json', 'calendar_last_view.json'],
  'calendar_album': ['calendar_entries.json'],
};
Future<void> ensureDomainBackup(PluginData data, String plugin) async {
  if (await data.read(plugin, 'sdk_migration_backup.json') != null) return;
  final files = <String, dynamic>{};
  for (final file in structuredDomainFiles[plugin]!) {
    files[file] = await data.read(plugin, file);
  }
  await data.write(plugin, 'sdk_migration_backup.json', {
    'schemaVersion': 1,
    'pluginId': plugin,
    'files': files,
  });
}

Future<Map<String, dynamic>> restoreDomainBackup(
  PluginData data,
  String plugin,
) async {
  final backup = entityObject(
    await data.read(plugin, 'sdk_migration_backup.json'),
  );
  if (backup['schemaVersion'] != 1 ||
      backup['pluginId'] != plugin ||
      backup['files'] is! Map)
    throw const FormatException('没有可恢复的 SDK 迁移备份');
  final files = entityObject(backup['files']);
  for (final file in structuredDomainFiles[plugin]!) {
    if (!files.containsKey(file)) throw const FormatException('备份文件清单不完整');
  }
  for (final file in structuredDomainFiles[plugin]!) {
    if (files[file] == null) {
      await data.delete(plugin, file);
    } else {
      await data.write(plugin, file, files[file]);
    }
  }
  return {'restored': true, 'schemaVersion': 1};
}

T decodeStored<T>(T Function() decode) {
  try {
    return decode();
  } on FormatException catch (e) {
    throw StorageException(StorageErrorKind.invalidData, e.message);
  }
}
