import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../storage_errors.dart';
import '../storage_interface.dart';
import '../legacy_write_policy.dart';
import 'plugin_data.dart';
import 'migrations/diary_migration.dart';

/// 平台持久化边界。write 必须原子替换单个键；多键提交由日志恢复。
abstract class PluginPersistence {
  String get identity;
  Future<String?> read(String path);
  Future<void> write(String path, String content);
  Future<bool> remove(String path);
  Future<List<String>> keys(String prefix);
}

abstract class BinaryPluginPersistence {
  Future<Uint8List?> readBytes(String path, int maxBytes);
}

/// 浏览器 IndexedDB 等宿主存储接入共享执行器，不依赖 dart:io。
class StoragePluginPersistence implements PluginPersistence, BinaryPluginPersistence {
  StoragePluginPersistence(this.storage, {required this.identity});
  final StorageInterface storage;
  @override
  final String identity;
  @override
  Future<String?> read(String path) => storage.loadData(path);
  @override
  Future<void> write(String path, String content) =>
      storage.saveData(path, content);
  @override
  Future<bool> remove(String path) async {
    final exists = await storage.hasData(path);
    if (exists) await storage.removeData(path);
    return exists;
  }

  @override
  Future<List<String>> keys(String prefix) => storage.getKeysWithPrefix(prefix);

  @override
  Future<Uint8List?> readBytes(String path, int maxBytes) async {
    final bytes = await storage.readBytes(path);
    if (bytes != null && bytes.length > maxBytes) {
      throw const StorageException(StorageErrorKind.invalidRequest, '旧资源超过导入大小上限');
    }
    return bytes;
  }
}

abstract class TransactionalPluginData implements PluginData {
  Future<Map<String, dynamic>> execute({
    required String pluginId,
    required String action,
    required String resource,
    required bool isQuery,
    required Map<String, dynamic> params,
    required Future<Map<String, dynamic>> Function(PluginData data) operation,
  });
}

/// 单进程部署：锁按持久化身份共享，REST/MCP/本地的临时后端也共用。
/// 所有业务读取同样经过锁与恢复，永远不会观察到半次多文件提交。
class PersistentPluginBackend implements TransactionalPluginData {
  PersistentPluginBackend(
    this.persistence, {
    this.source = 'local',
    this.onEvent,
    this.sourceDeviceId,
  });

  final PluginPersistence persistence;
  final String source;
  final String? sourceDeviceId;
  final void Function(DataChangeEvent event)? onEvent;
  static final _requestContextKey = Object();

  /// 请求上下文使用 Zone 隔离；复用 runtime 时不能修改实例上的设备字段。
  Future<T> withRequestContext<T>(
    Future<T> Function() operation, {
    required String source,
    String? sourceDeviceId,
  }) => runZoned(operation, zoneValues: {
    _requestContextKey: (source: source, deviceId: sourceDeviceId),
  });
  static final _queues = <String, Future<void>>{};
  static final _events = <String, StreamController<DataChangeEvent>>{};

  Stream<DataChangeEvent> get events {
    final key = persistence.identity;
    final existing = _events[key];
    if (existing != null) return existing.stream;
    late StreamController<DataChangeEvent> controller;
    controller = StreamController<DataChangeEvent>.broadcast(
      onCancel: () {
        if (!controller.hasListener && identical(_events[key], controller)) {
          _events.remove(key);
          unawaited(controller.close());
        }
      },
    );
    _events[key] = controller;
    return controller.stream;
  }

  void _emit(DataChangeEvent event) {
    _events[persistence.identity]?.add(event);
    onEvent?.call(event);
  }

  static const _journalPath = '.sdk/pending.json';
  static const _statePath = '.sdk/state.json';
  static const mutationRetention = Duration(days: 30);

  Future<T> _locked<T>(Future<T> Function() operation) async {
    final key = persistence.identity;
    final previous = _queues[key] ?? Future<void>.value();
    final done = Completer<void>();
    _queues[key] = done.future;
    await previous;
    try {
      await _recover();
      return await operation();
    } finally {
      done.complete();
      if (identical(_queues[key], done.future)) _queues.remove(key);
    }
  }

  Future<dynamic> _json(String path) async {
    final content = await persistence.read(path);
    if (content == null) return null;
    try {
      return jsonDecode(content);
    } on FormatException {
      throw StorageException(StorageErrorKind.invalidData, '损坏的 JSON: $path');
    }
  }

  Future<void> _apply(Map<String, dynamic> writes) async {
    for (final entry in writes.entries) {
      if (entry.value == null) {
        await persistence.remove(entry.key);
      } else {
        await persistence.write(entry.key, entry.value as String);
      }
    }
  }

  Future<void> _recover() async {
    final journal = await _json(_journalPath);
    if (journal == null) return;
    if (journal is! Map ||
        journal['schemaVersion'] != 1 ||
        journal['writes'] is! Map) {
      throw const StorageException(StorageErrorKind.invalidData, '事务恢复日志损坏');
    }
    // 日志落盘是提交决定，恢复必须向前完成；重放是幂等的。
    await _apply(Map<String, dynamic>.from(journal['writes'] as Map));
    await persistence.remove(_journalPath);
    if (journal['event'] is Map) {
      _emit(
        DataChangeEvent.fromJson({
          ...Map<String, dynamic>.from(journal['event'] as Map),
          'source': 'recovery',
        }),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> execute({
    required String pluginId,
    required String action,
    required String resource,
    required bool isQuery,
    required Map<String, dynamic> params,
    required Future<Map<String, dynamic>> Function(PluginData data) operation,
  }) => _locked(() async {
    final state =
        await _json(_statePath) ??
        <String, dynamic>{
          'schemaVersion': 1,
          'versions': <String, dynamic>{},
          'mutations': <String, dynamic>{},
        };
    if (state is! Map ||
        state['versions'] is! Map ||
        state['mutations'] is! Map) {
      throw const StorageException(StorageErrorKind.invalidData, 'SDK 版本状态损坏');
    }
    final versions = Map<String, dynamic>.from(state['versions'] as Map);
    final mutations = Map<String, dynamic>.from(state['mutations'] as Map);
    final version = (versions[pluginId] as num?)?.toInt() ?? 0;
    final mutationId = params['clientMutationId'] as String?;
    final mutationKey = jsonEncode([pluginId, action, mutationId]);
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(_canonical(params))))
        .toString();
    Map<String, dynamic> failure(String message, String code) => {
      'success': false,
      'error': message,
      'code': code,
      'version': version,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final now = DateTime.now().toUtc();
    mutations.removeWhere(
      (key, value) =>
          now.difference(
            DateTime.parse((value as Map)['committedAt'] as String),
          ) >
          mutationRetention,
    );
    if (!isQuery && mutationId != null && mutations.containsKey(mutationKey)) {
      final previous = mutations[mutationKey] as Map;
      if (previous['fingerprint'] != fingerprint) {
        return failure('mutationId 已被不同参数使用', 'CONFLICT');
      }
      return Map<String, dynamic>.from(previous['result'] as Map);
    }
    if (!isQuery &&
        params.containsKey('expectedVersion') &&
        params['expectedVersion'] != version) {
      return failure('业务域版本已变化，请重新查询', 'CONFLICT');
    }
    final transaction = _TransactionData(this);
    if (!isQuery && pluginId == 'diary' && action != 'restoreMigrationBackup') {
      await prepareDiaryMigration(transaction);
    }
    final result = await operation(transaction);
    if (transaction.fault != null) throw transaction.fault!;
    if (result['success'] != true) return {...result, 'version': version};
    if (isQuery) {
      if (transaction.writes.isNotEmpty) throw StateError('查询不得写入持久化');
      return {...result, 'version': version};
    }
    final nextVersion = transaction.writes.isEmpty ? version : version + 1;
    final committed = {
      ...result,
      'version': nextVersion,
      if (mutationId != null) 'mutationId': mutationId,
    };
    if (mutationId != null) {
      mutations[mutationKey] = {
        'fingerprint': fingerprint,
        'result': committed,
        'committedAt': now.toIso8601String(),
      };
    }
    if (transaction.writes.isEmpty && mutationId == null) return committed;
    versions[pluginId] = nextVersion;
    final writes = {
      ...transaction.writes,
      _statePath: jsonEncode({
        'schemaVersion': 1,
        'versions': versions,
        'mutations': mutations,
      }),
    };
    final event = DataChangeEvent(
      pluginId: pluginId,
      filePattern: '*',
      source: (Zone.current[_requestContextKey] as ({String source, String? deviceId})?)?.source ?? source,
      action: action,
      resource: resource,
      version: nextVersion,
      entityId: (params['channelId'] ?? params['id'] ?? params['date'])
          ?.toString(),
      mutationId: mutationId,
      sourceDeviceId: (Zone.current[_requestContextKey] as ({String source, String? deviceId})?)?.deviceId ?? sourceDeviceId,
    );
    await persistence.write(
      _journalPath,
      jsonEncode({
        'schemaVersion': 1,
        'writes': writes,
        if (transaction.writes.isNotEmpty) 'event': event.toJson(),
      }),
    );
    await _apply(writes);
    await persistence.remove(_journalPath);
    if (transaction.writes.isNotEmpty) {
      _emit(event);
    }
    return committed;
  });

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }

  static String checkedPath(String path) {
    final parts = path.split('/');
    if (parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              part.contains('\\') ||
              part.contains(':') ||
              RegExp(r'[. ]$').hasMatch(part) ||
              part.contains('\u0000'),
        ) ||
        parts.first.toLowerCase() == '.sdk')
      throw const StoragePathException();
    return path;
  }

  @override
  Future<dynamic> read(String pluginId, String fileName) =>
      readPath('$pluginId/$fileName');
  @override
  Future<void> write(String pluginId, String fileName, dynamic data) =>
      writePath('$pluginId/$fileName', data);
  @override
  Future<bool> delete(String pluginId, String fileName) =>
      deletePath('$pluginId/$fileName');
  @override
  Future<List<String>> listFiles(String pluginId, [String? pattern]) async {
    checkedPath(pluginId);
    final names = (await listPathKeys(
      '$pluginId/',
    )).map((key) => key.substring(pluginId.length + 1));
    final regex = pattern == null
        ? null
        : RegExp('^${pattern.split('*').map(RegExp.escape).join('.*')}\$');
    return names
        .where(
          (name) =>
              name.endsWith('.json') && (regex == null || regex.hasMatch(name)),
        )
        .toList()
      ..sort();
  }

  @override
  void notifyChanged(String pluginId, String filePattern) => _emit(
    DataChangeEvent(
      pluginId: pluginId,
      filePattern: filePattern,
      source: source,
    ),
  );

  // 仅供尚未迁移的业务域使用，最终收口时删除。
  Future<dynamic> readPath(String path) =>
      _locked(() => _json(checkedPath(path)));
  Future<String> readPathText(String path) =>
      _locked(() async => await persistence.read(checkedPath(path)) ?? '');
  Future<void> writePath(String path, dynamic data) => _locked(() async {
    LegacyWritePolicy.check(path);
    await persistence.write(
      checkedPath(path),
      data is String ? data : jsonEncode(data),
    );
    notifyChanged(path.split('/').first, path.split('/').skip(1).join('/'));
  });
  Future<bool> deletePath(String path) => _locked(() async {
    LegacyWritePolicy.check(path);
    final removed = await persistence.remove(checkedPath(path));
    if (removed)
      notifyChanged(path.split('/').first, path.split('/').skip(1).join('/'));
    return removed;
  });
  Future<bool> existsPath(String path) =>
      _locked(() async => await persistence.read(checkedPath(path)) != null);
  Future<List<String>> listPathKeys(String prefix) => _locked(() {
    if (prefix.isNotEmpty) checkedPath(prefix.replaceFirst(RegExp(r'/+$'), ''));
    return persistence.keys(prefix);
  });
  Future<void> clearPathPrefix(String prefix) => _locked(() async {
    LegacyWritePolicy.check(prefix, prefix: true);
    checkedPath(prefix.replaceFirst(RegExp(r'/+$'), ''));
    for (final key in await persistence.keys(prefix)) {
      await persistence.remove(checkedPath(key));
    }
    notifyChanged(prefix.split('/').first, '*');
  });
}

class _TransactionData implements PluginData, LegacyAssetData {
  _TransactionData(this.backend);
  final PersistentPluginBackend backend;
  final writes = <String, String?>{};
  StorageException? fault;
  @override
  Future<Uint8List?> readLegacyAsset(String path, int maxBytes) {
    PersistentPluginBackend.checkedPath(path);
    final persistence = backend.persistence;
    if (persistence is! BinaryPluginPersistence) {
      throw const StorageException(StorageErrorKind.unsupported, '持久化适配器不支持旧资源导入');
    }
    return (persistence as BinaryPluginPersistence).readBytes(path, maxBytes);
  }

  /// 受控迁移：删除分区外旧数据文件，纳入当前事务（崩溃由日志恢复重放）。
  @override
  Future<bool> removeLegacyAsset(String path) async {
    final checked = PersistentPluginBackend.checkedPath(path);
    try {
      if (writes.containsKey(checked)) {
        final pending = writes[checked] != null;
        if (pending) writes[checked] = null;
        return pending;
      }
      final exists = await backend._json(checked) != null;
      if (exists) writes[checked] = null;
      return exists;
    } on StorageException catch (error) {
      fault = error;
      rethrow;
    }
  }
  String _path(String pluginId, String fileName) =>
      PersistentPluginBackend.checkedPath('$pluginId/$fileName');
  @override
  Future<dynamic> read(String pluginId, String fileName) async {
    final path = _path(pluginId, fileName);
    try {
      if (writes.containsKey(path))
        return writes[path] == null ? null : jsonDecode(writes[path]!);
      return await backend._json(path);
    } on StorageException catch (error) {
      fault = error;
      rethrow;
    }
  }

  @override
  Future<void> write(String pluginId, String fileName, dynamic data) async {
    writes[_path(pluginId, fileName)] = jsonEncode(data);
  }

  @override
  Future<bool> delete(String pluginId, String fileName) async {
    final exists = await read(pluginId, fileName) != null;
    if (exists) writes[_path(pluginId, fileName)] = null;
    return exists;
  }

  @override
  Future<List<String>> listFiles(String pluginId, [String? pattern]) async {
    PersistentPluginBackend.checkedPath(pluginId);
    final prefix = '$pluginId/';
    final keys = {
      ...await backend.persistence.keys(prefix),
      ...writes.keys.where((key) => key.startsWith(prefix)),
    };
    final regex = pattern == null
        ? null
        : RegExp('^${pattern.split('*').map(RegExp.escape).join('.*')}\$');
    return keys
        .where((key) => !writes.containsKey(key) || writes[key] != null)
        .map((key) => key.substring(prefix.length))
        .where(
          (name) =>
              name.endsWith('.json') && (regex == null || regex.hasMatch(name)),
        )
        .toList()
      ..sort();
  }

  @override
  void notifyChanged(String pluginId, String filePattern) {}
}
