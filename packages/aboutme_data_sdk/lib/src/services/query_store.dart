import 'dart:async';
import 'dart:convert';
import '../storage_errors.dart';
import 'plugin_data.dart';

enum QueryStatus { loading, data, error, stale }

class QuerySnapshot {
  const QuerySnapshot(this.status, {this.result, this.error});
  final QueryStatus status;
  final Map<String, dynamic>? result;
  final Object? error;
}

typedef QueryExecutor =
    Future<Map<String, dynamic>> Function(
      String pluginId,
      String action,
      Map<String, dynamic> params,
    );

/// 每个 SDK 实例独占缓存。失效发生于请求中时丢弃旧响应并重查。
class QueryStore {
  QueryStore(this.execute, Stream<DataChangeEvent> events) {
    _events = events.listen((event) => invalidate(event.pluginId));
  }
  final QueryExecutor execute;
  late final StreamSubscription<DataChangeEvent> _events;
  final _entries = <String, _QueryEntry>{};
  bool _closed = false;

  _QueryEntry _entry(
    String pluginId,
    String action,
    Map<String, dynamic> params,
  ) {
    if (_closed) throw StateError('SDK 已关闭');
    final frozen =
        jsonDecode(jsonEncode(_canonical(params))) as Map<String, dynamic>;
    final key = jsonEncode([pluginId, action, frozen]);
    return _entries.putIfAbsent(
      key,
      () => _QueryEntry(pluginId, action, frozen),
    );
  }

  Future<Map<String, dynamic>> query(
    String pluginId,
    String action,
    Map<String, dynamic> params, {
    bool cacheOnly = false,
  }) {
    final entry = _entry(pluginId, action, params);
    if (cacheOnly) {
      final result = entry.snapshot.result;
      if (result == null)
        throw const StorageException(StorageErrorKind.offline, '没有可用的缓存快照');
      return Future.value(_copy(result));
    }
    return _refresh(entry).then(_copy);
  }

  Stream<QuerySnapshot> watch(
    String pluginId,
    String action,
    Map<String, dynamic> params,
  ) {
    final entry = _entry(pluginId, action, params);
    return Stream<QuerySnapshot>.multi((controller) {
      entry.listeners++;
      final subscription = entry.changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.add(_snapshotCopy(entry.snapshot));
      unawaited(
        _refresh(
          entry,
        ).then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
      controller.onCancel = () async {
        entry.listeners--;
        await subscription.cancel();
      };
    });
  }

  void invalidate([String? pluginId]) {
    if (_closed) return;
    for (final entry in _entries.values.toList()) {
      if (pluginId != null && entry.pluginId != pluginId) continue;
      entry.generation++;
      _publish(
        entry,
        QuerySnapshot(QueryStatus.stale, result: entry.snapshot.result),
      );
      if (entry.listeners > 0) {
        unawaited(
          _refresh(
            entry,
          ).then<void>((_) {}, onError: (Object _, StackTrace __) {}),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _refresh(_QueryEntry entry) {
    final pending = entry.pending;
    if (pending != null) return pending;
    final completer = Completer<Map<String, dynamic>>();
    entry.pending = completer.future;
    unawaited(() async {
      try {
        while (!_closed) {
          final generation = entry.generation;
          _publish(
            entry,
            QuerySnapshot(QueryStatus.loading, result: entry.snapshot.result),
          );
          try {
            final result = await execute(
              entry.pluginId,
              entry.action,
              entry.params,
            );
            if (_closed) throw StateError('SDK 已关闭');
            if (generation != entry.generation) continue;
            if (result['success'] != true) throw QueryFailure(result);
            final copy = _copy(result);
            _publish(entry, QuerySnapshot(QueryStatus.data, result: copy));
            completer.complete(copy);
            return;
          } catch (error) {
            if (!_closed && generation != entry.generation) continue;
            rethrow;
          }
        }
        throw StateError('SDK 已关闭');
      } catch (error, stack) {
        if (!_closed)
          _publish(
            entry,
            QuerySnapshot(
              QueryStatus.error,
              result: entry.snapshot.result,
              error: error,
            ),
          );
        completer.completeError(error, stack);
      } finally {
        entry.pending = null;
      }
    }());
    return completer.future;
  }

  void _publish(_QueryEntry entry, QuerySnapshot snapshot) {
    if (_closed) return;
    entry.snapshot = snapshot;
    entry.changes.add(_snapshotCopy(snapshot));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _events.cancel();
    await Future.wait(_entries.values.map((entry) => entry.changes.close()));
    _entries.clear();
  }

  static Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  static QuerySnapshot _snapshotCopy(QuerySnapshot value) => QuerySnapshot(
    value.status,
    result: value.result == null ? null : _copy(value.result!),
    error: value.error,
  );
  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }
}

class QueryFailure implements Exception {
  QueryFailure(this.result);
  final Map<String, dynamic> result;
  @override
  String toString() => 'QueryFailure(${result['code']}): ${result['error']}';
}

class _QueryEntry {
  _QueryEntry(this.pluginId, this.action, this.params);
  final String pluginId;
  final String action;
  final Map<String, dynamic> params;
  final changes = StreamController<QuerySnapshot>.broadcast();
  QuerySnapshot snapshot = const QuerySnapshot(QueryStatus.loading);
  int generation = 0;
  int listeners = 0;
  Future<Map<String, dynamic>>? pending;
}
