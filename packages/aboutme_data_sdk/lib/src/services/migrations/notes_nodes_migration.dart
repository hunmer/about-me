import '../../storage_errors.dart';
import '../plugin_data.dart';

/// Maintenance-only helpers. Caller must execute inside an SDK transaction.
/// They are deliberately not normal REST/MCP business commands.
Future<void> restoreNotesMigrationBackup(PluginData data) async {
  final backup = await data.read('notes', 'migration_v1_backup.json');
  if (backup is! Map ||
      backup['schemaVersion'] != 1 ||
      backup['notes'] is! List ||
      backup['folders'] is! List) {
    throw const StorageException(StorageErrorKind.invalidData, '笔记备份无效');
  }
  final ids = await data.read('notes', 'notes/index.json');
  if (ids != null && ids is! List)
    throw const StorageException(
      StorageErrorKind.invalidData,
      '当前笔记索引损坏，请先导出原始数据后人工恢复',
    );
  final before = <String, dynamic>{
    'folders': await data.read('notes', 'folders.json'),
    'data': await data.read('notes', 'data.json'),
    'index': ids,
    'notes': <dynamic>[],
  };
  for (final id in (ids ?? <dynamic>[])) {
    (before['notes'] as List).add(await data.read('notes', 'notes/$id.json'));
  }
  await data.write('notes', 'before_restore.json', before);
  for (final id in (ids ?? <dynamic>[])) {
    await data.delete('notes', 'notes/$id.json');
  }
  final restored = <String>[];
  for (final raw in backup['notes'] as List) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['id'].toString().contains('/') ||
        raw['id'].toString().contains('\\')) {
      throw const StorageException(StorageErrorKind.invalidData, '备份笔记ID损坏');
    }
    final note = Map<String, dynamic>.from(raw);
    restored.add(note['id'] as String);
    await data.write('notes', 'notes/' + note['id'].toString() + '.json', note);
  }
  await data.write('notes', 'notes/index.json', restored);
  for (final pair in {
    'folders.json': 'originalFolders',
    'data.json': 'originalData',
  }.entries) {
    final value = backup[pair.value];
    if (value == null) {
      await data.delete('notes', pair.key);
    } else {
      await data.write('notes', pair.key, value);
    }
  }
}

Future<void> restoreNodesMigrationBackup(PluginData data) async {
  final backup = await data.read('nodes', 'migration_v1_backup.json');
  if (backup is! Map ||
      backup['schemaVersion'] != 1 ||
      !backup.containsKey('original')) {
    throw const StorageException(StorageErrorKind.invalidData, '节点备份无效');
  }
  await data.write('nodes', 'before_restore.json', {
    'original': await data.read('nodes', 'nodes_notebooks.json'),
  });
  final original = backup['original'];
  if (original == null) {
    await data.delete('nodes', 'nodes_notebooks.json');
  } else {
    await data.write('nodes', 'nodes_notebooks.json', original);
  }
}
