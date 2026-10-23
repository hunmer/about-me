import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/plugins/day/models/memorial_day.dart';

class MemorialDayCacheUpdatedEventArgs extends EventArgs {
  /// 所有纪念日列表
  final List<MemorialDay> items;

  /// 更新时间
  final DateTime timestamp;

  MemorialDayCacheUpdatedEventArgs({required this.items, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now(),
      super('memorial_day_cache_updated');
}

enum SortMode { upcoming, recent, manual }

class DayController extends ChangeNotifier {
  AboutmeData get _data => AboutmeDataService.instance.data;
  final List<MemorialDay> _memorialDays = [];
  final _originals = <String, Map<String, dynamic>>{};
  final _versions = <String, int?>{};
  bool _isCardView = true;
  SortMode _sortMode = SortMode.upcoming;
  int? _version;
  Object? queryError;
  StreamSubscription<QuerySnapshot>? _subscription;
  List<MemorialDay> get memorialDays => List.unmodifiable(_memorialDays);
  bool get isCardView => _isCardView;
  SortMode get sortMode => _sortMode;
  bool get isDraggable => _sortMode == SortMode.manual;
  dynamic _result(Map<String, dynamic> r) {
    if (r['success'] != true) throw QueryFailure(r);
    _version = r['version'] as int?;
    return r['data'];
  }

  void _accept(Map<String, dynamic> response) {
    final state = _result(response) as Map;
    final rows = (state['data'] as List)
        .map((r) => MemorialDay.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    _memorialDays
      ..clear()
      ..addAll(rows);
    _originals.clear();
    _versions.clear();
    for (final row in rows) {
      _originals[row.id] = row.toJson();
      _versions[row.id] = _version;
    }
    final prefs = state['preferences'] as Map;
    _isCardView = prefs['isCardView'] as bool;
    _sortMode = SortMode.values.byName(
      prefs['sortMode'].toString().split('.').last,
    );
    queryError = null;
    notifyListeners();
    EventManager.instance.broadcast(
      'memorial_day_cache_updated',
      MemorialDayCacheUpdatedEventArgs(items: List.from(rows)),
    );
  }

  Future<void> initialize() async {
    await reloadData();
    _subscription = _data.watch('day', 'getSnapshot').listen((snapshot) {
      if (snapshot.status == QueryStatus.data) _accept(snapshot.result!);
      if (snapshot.status == QueryStatus.error) {
        queryError = snapshot.error;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> reloadData() async {
    try {
      _accept(await _data.query('day', 'getSnapshot'));
    } catch (e) {
      queryError = e;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _command(
    String action,
    Map<String, dynamic> p, {
    int? expectedVersion,
  }) async {
    try {
      _result(
        await _data.call('day', action, {
          ...p,
          if (expectedVersion != null) 'expectedVersion': expectedVersion,
        }),
      );
      await reloadData();
    } catch (e) {
      queryError = e;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleView() async {
    await _command('updatePreferences', {'isCardView': !_isCardView});
  }

  Future<void> setSortMode(SortMode mode) async {
    await _command('updatePreferences', {'sortMode': mode.name});
  }

  Future<void> loadSampleMemorialDays() async {
    await _command('seedExamples', {
      'groups': ['memorialDays'],
      'templateVersion': 1,
    });
  }

  Future<void> addMemorialDay(MemorialDay day) async {
    await _command('create', day.toJson());
    _notifyEvent('added', day);
  }

  Future<void> updateMemorialDay(MemorialDay day) async {
    final old = _originals[day.id];
    if (old == null) throw StateError('纪念日已失效，请刷新');
    final row = day.toJson();
    final patch = {
      'id': day.id,
      for (final e in row.entries)
        if (e.key != 'id' && jsonEncode(e.value) != jsonEncode(old[e.key]))
          e.key: e.value,
    };
    await _command('update', patch, expectedVersion: _versions[day.id]);
    _notifyEvent('updated', day);
  }

  Future<void> deleteMemorialDay(String id) async {
    final day = _memorialDays.firstWhere((r) => r.id == id);
    await _command('delete', {'id': id}, expectedVersion: _versions[id]);
    _notifyEvent('deleted', day);
  }

  Future<void> reorderIds(List<String> ids) async {
    await _command('reorder', {'ids': ids}, expectedVersion: _version);
  }

  Future<void> reorderMemorialDays(int oldIndex, int newIndex) async {
    if (!isDraggable) return;
    final ids = _memorialDays.map((r) => r.id).toList();
    if (oldIndex < newIndex) newIndex--;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    await _command('reorder', {'ids': ids}, expectedVersion: _version);
  }

  // 触发事件
  void _notifyEvent(String action, MemorialDay memorialDay) {
    // 1. 广播单个项目的事件（保持兼容性）
    final eventName = 'memorial_day_$action';
    debugPrint(
      '[DayController] Broadcasting event: $eventName, itemId: ${memorialDay.id}',
    );
    final eventArgs = ItemEventArgs(
      eventName: eventName,
      itemId: memorialDay.id,
      title: memorialDay.title,
      action: action,
    );
    EventManager.instance.broadcast(eventName, eventArgs);

    // 2. 广播缓存更新事件（携带所有纪念日数据）
    debugPrint(
      '[DayController] Broadcasting cache_updated with ${_memorialDays.length} items',
    );
    EventManager.instance.broadcast(
      'memorial_day_cache_updated',
      MemorialDayCacheUpdatedEventArgs(items: List.from(_memorialDays)),
    );
  }
}
