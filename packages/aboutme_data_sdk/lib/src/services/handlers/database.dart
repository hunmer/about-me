import 'dart:convert';

import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

/// Database 域业务：库定义列表（database/databases/databases.json，顶层 List）
/// + 每库一个记录分文件（database/records_<id>.json，顶层 List）。
///
/// 旧客户端数据存放在根目录：`databases/databases.json`（库定义）与
/// `records_<id>`（记录，无扩展名）。首次写命令时整体搬入 database 分区
/// （读旧→写新→删旧，单事务）；查询对旧位置只读回退，保证迁移前数据可见。
/// 库定义列表首次成功写前把原始文件快照到 migration_v1_backup.json
/// （records 分文件不纳入快照）。
PluginHandlers createDatabaseHandlers(PluginData data) {
  const plugin = 'database';
  const databasesFile = 'databases/databases.json';

  // 旧库定义文件位于根目录 databases/databases.json，借 'databases' 分区访问
  // （与 chat_stickers 访问 stickers/ 同一惯例）。
  Future<dynamic> readLegacyDatabases() =>
      data.read('databases', 'databases.json');

  String recordFile(String id) => 'records_$id.json';

  void checkDatabaseId(dynamic value) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains(':') ||
        value.contains('..'))
      throw ArgumentError('databaseId required');
  }

  List<Map<String, dynamic>> asRows(dynamic raw, String what) {
    if (raw is! List)
      throw DomainFailure('CORRUPT_DATA', 'Expected array for $what');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $what row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  // 分区外顶层旧文件（根目录 records_<id>），仅受控迁移可读删。
  Future<dynamic> readLegacyTopFile(String path) async {
    if (data is! LegacyAssetData) return null;
    try {
      final bytes = await (data as LegacyAssetData).readLegacyAsset(
        path,
        64 << 20,
      );
      if (bytes == null) return null;
      return jsonDecode(utf8.decode(bytes));
    } on StorageException catch (error) {
      if (error.kind == StorageErrorKind.unsupported) return null;
      rethrow;
    }
  }

  Future<void> removeLegacyTopFile(String path) async {
    if (data is! LegacyAssetData) return;
    try {
      await (data as LegacyAssetData).removeLegacyAsset(path);
    } on StorageException catch (error) {
      if (error.kind != StorageErrorKind.unsupported) rethrow;
    }
  }

  // ==================== 库定义 ====================

  Future<List<Map<String, dynamic>>> readDatabases() async {
    final raw = await data.read(plugin, databasesFile);
    if (raw != null) return asRows(raw, '$plugin/$databasesFile');
    final legacy = await readLegacyDatabases();
    if (legacy != null) return asRows(legacy, 'databases/databases.json');
    return [];
  }

  Future<void> backup() async {
    if (await data.read(plugin, 'migration_v1_backup.json') != null) return;
    await data.write(plugin, 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'databases':
          await data.read(plugin, databasesFile) ??
          await readLegacyDatabases(),
    });
  }

  Future<void> saveDatabases(List<Map<String, dynamic>> rows) async {
    await backup();
    // 旧库定义文件搬家：读旧→写新→删旧（同事务提交）。
    if (await data.read(plugin, databasesFile) == null) {
      final legacy = await readLegacyDatabases();
      if (legacy != null) {
        await data.write(plugin, databasesFile, legacy);
        await data.delete('databases', 'databases.json');
      }
    }
    await data.write(plugin, databasesFile, rows);
  }

  // ==================== 记录（每库一个文件） ====================

  Future<List<Map<String, dynamic>>> readRecords(String databaseId) async {
    final file = recordFile(databaseId);
    final raw = await data.read(plugin, file);
    if (raw != null) return asRows(raw, '$plugin/$file');
    final legacy = await readLegacyTopFile('records_$databaseId');
    if (legacy != null) return asRows(legacy, 'records_$databaseId');
    return [];
  }

  Future<void> saveRecords(
    String databaseId,
    List<Map<String, dynamic>> rows,
  ) async {
    await data.write(plugin, recordFile(databaseId), rows);
    // 旧顶层记录文件搬家收尾：新文件已写，删除旧位置（同事务提交）。
    await removeLegacyTopFile('records_$databaseId');
  }

  Map<String, dynamic> patchOf(Map<String, dynamic> p) => domainPatch(p)
    ..remove('id')
    ..remove('databaseId')
    ..remove('tableId');

  Map<String, dynamic> defaultDatabase() => {
    'id': 'default_db',
    'name': 'Default Database',
    'description': null,
    'coverImage': null,
    'fields': <dynamic>[],
    'createdAt': jsIsoDateTime(DateTime.now()),
    'updatedAt': jsIsoDateTime(DateTime.now()),
  };

  return {
    'getList': domainAction((p) async {
      var rows = await readDatabases();
      final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
      if (keyword.isNotEmpty)
        rows = rows
            .where(
              (d) => '${d['name'] ?? ''}'.toLowerCase().contains(keyword),
            )
            .toList();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'getById': domainAction((p) async {
      final rows = await readDatabases();
      return rows[domainIndex(rows, p['id'])];
    }),
    'create': domainAction((p) async {
      final rows = await readDatabases();
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Database exists');
      final now = jsIsoDateTime(DateTime.now());
      final database = <String, dynamic>{
        'description': null,
        'coverImage': null,
        'fields': <dynamic>[],
        ...patchOf(p),
        'id': id,
        'createdAt': p['createdAt'] ?? now,
        'updatedAt': p['updatedAt'] ?? now,
      };
      if (database['name'] is! String || (database['name'] as String).isEmpty)
        throw ArgumentError('name required');
      if (database['fields'] is! List)
        throw ArgumentError('fields invalid');
      rows.add(database);
      await saveDatabases(rows);
      return database;
    }),
    'update': domainAction((p) async {
      final rows = await readDatabases();
      final i = domainIndex(rows, p['id']);
      rows[i] = {
        ...rows[i],
        ...patchOf(p),
        'updatedAt': p['updatedAt'] ?? jsIsoDateTime(DateTime.now()),
      };
      if (rows[i]['fields'] is! List) throw ArgumentError('fields invalid');
      await saveDatabases(rows);
      return rows[i];
    }),
    'delete': domainAction((p) async {
      final id = p['id'];
      checkDatabaseId(id);
      final rows = await readDatabases();
      rows.removeAt(domainIndex(rows, id));
      await saveDatabases(rows);
      // 级联删除该库记录文件（新位置 + 旧顶层残留）。
      await data.delete(plugin, recordFile(id));
      await removeLegacyTopFile('records_$id');
      return {'id': id};
    }),
    'getRecords': domainAction((p) async {
      final databaseId = p['databaseId'] ?? p['tableId'] ?? p['id'];
      checkDatabaseId(databaseId);
      var rows = await readRecords(databaseId);
      final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
      if (keyword.isNotEmpty)
        rows = rows.where((r) {
          final fields = r['fields'];
          if (fields is! Map) return false;
          for (final value in fields.values) {
            if (value != null && '$value'.toLowerCase().contains(keyword))
              return true;
          }
          return false;
        }).toList();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'createRecord': domainAction((p) async {
      final databaseId = p['databaseId'] ?? p['tableId'];
      checkDatabaseId(databaseId);
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      final rows = await readRecords(databaseId);
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Record exists');
      final now = jsIsoDateTime(DateTime.now());
      final record = <String, dynamic>{
        'fields': <String, dynamic>{},
        ...patchOf(p),
        'id': id,
        'tableId': databaseId,
        'createdAt': p['createdAt'] ?? now,
        'updatedAt': p['updatedAt'] ?? now,
      };
      if (record['fields'] is! Map) throw ArgumentError('fields invalid');
      rows.add(record);
      await saveRecords(databaseId, rows);
      return record;
    }),
    'updateRecord': domainAction((p) async {
      final databaseId = p['databaseId'] ?? p['tableId'];
      checkDatabaseId(databaseId);
      final rows = await readRecords(databaseId);
      final i = domainIndex(rows, p['id']);
      rows[i] = {
        ...rows[i],
        ...patchOf(p),
        'updatedAt': p['updatedAt'] ?? jsIsoDateTime(DateTime.now()),
      };
      if (rows[i]['fields'] is! Map) throw ArgumentError('fields invalid');
      await saveRecords(databaseId, rows);
      return rows[i];
    }),
    'deleteRecord': domainAction((p) async {
      final databaseId = p['databaseId'] ?? p['tableId'];
      checkDatabaseId(databaseId);
      final rows = await readRecords(databaseId);
      rows.removeAt(domainIndex(rows, p['id']));
      await saveRecords(databaseId, rows);
      return {'id': p['id'], 'databaseId': databaseId};
    }),
    'exportData': domainAction((_) async {
      final databases = await readDatabases();
      final records = <String, dynamic>{};
      for (final database in databases) {
        final id = database['id'] as String;
        records[id] = await readRecords(id);
      }
      return {'databases': databases, 'records': records};
    }),
    'importData': domainAction((p) async {
      var importedDatabases = 0, importedRecords = 0;
      final databasesPayload = p['databases'];
      if (databasesPayload is List && databasesPayload.isNotEmpty) {
        final rows = await readDatabases();
        for (final e in databasesPayload) {
          if (e is! Map || e['id'] is! String)
            throw const DomainFailure('CORRUPT_DATA', 'Invalid database row');
          final row = Map<String, dynamic>.from(e);
          if (row['fields'] is! List)
            throw ArgumentError('fields invalid');
          final i = rows.indexWhere((r) => r['id'] == row['id']);
          if (i >= 0)
            rows[i] = {...rows[i], ...row};
          else
            rows.add(row);
        }
        await saveDatabases(rows);
        importedDatabases = databasesPayload.length;
      }
      final recordsPayload = p['records'];
      if (recordsPayload is Map) {
        for (final entry in recordsPayload.entries) {
          checkDatabaseId(entry.key);
          final list = entry.value;
          if (list is! List || list.isEmpty) continue;
          final rows = await readRecords(entry.key);
          for (final e in list) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure('CORRUPT_DATA', 'Invalid record row');
            final row = <String, dynamic>{
              ...Map<String, dynamic>.from(e),
              'tableId': e['tableId'] ?? entry.key,
            };
            if (row['fields'] is! Map) throw ArgumentError('fields invalid');
            final i = rows.indexWhere((r) => r['id'] == row['id']);
            if (i >= 0)
              rows[i] = {...rows[i], ...row};
            else
              rows.add(row);
          }
          await saveRecords(entry.key, rows);
          importedRecords += list.length;
        }
      }
      return {
        'importedDatabases': importedDatabases,
        'importedRecords': importedRecords,
      };
    }),
    'seedExamples': domainAction((p) async {
      var insertedDatabases = 0, insertedRecords = 0;
      final rows = await readDatabases();
      if (rows.isEmpty) {
        final payload = p['databases'];
        final seeds = payload is List && payload.isNotEmpty
            ? payload
            : [defaultDatabase()];
        for (final e in seeds) {
          if (e is! Map || e['id'] is! String)
            throw const DomainFailure(
              'CORRUPT_DATA',
              'Invalid example database',
            );
          rows.add(Map<String, dynamic>.from(e));
        }
        await saveDatabases(rows);
        insertedDatabases = rows.length;
      }
      final recordsPayload = p['records'];
      if (recordsPayload is Map) {
        for (final entry in recordsPayload.entries) {
          checkDatabaseId(entry.key);
          final list = entry.value;
          if (list is! List || list.isEmpty) continue;
          if ((await readRecords(entry.key)).isNotEmpty) continue;
          final seed = <Map<String, dynamic>>[];
          for (final e in list) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure(
                'CORRUPT_DATA',
                'Invalid example record',
              );
            seed.add(<String, dynamic>{
              ...Map<String, dynamic>.from(e),
              'tableId': e['tableId'] ?? entry.key,
            });
          }
          await saveRecords(entry.key, seed);
          insertedRecords += seed.length;
        }
      }
      return {
        'insertedDatabases': insertedDatabases,
        'insertedRecords': insertedRecords,
      };
    }),
  };
}
