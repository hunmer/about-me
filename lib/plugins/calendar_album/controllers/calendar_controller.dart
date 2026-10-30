import 'package:flutter/foundation.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/calendar_album/models/calendar_entry.dart';
import 'package:aboutme/plugins/calendar_album/sample_data.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event_args.dart';
import 'package:aboutme/core/event/item_event_args.dart';

import 'package:shared_models/shared_models.dart';
class CalendarController extends ChangeNotifier {
  // 发送事件通知
  void _notifyEvent(String action, CalendarEntry entry) {
    final eventArgs = ItemEventArgs(
      eventName: 'calendar_entry_$action',
      itemId: entry.id,
      title: entry.title,
      action: action,
    );
    EventManager.instance.broadcast('calendar_entry_$action', eventArgs);
  }
  final Map<DateTime, List<CalendarEntry>> _entries = {};
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  final List<DateTime> _displayMonths = [];
  late final VoidCallback _cancelPluginWatch;

  CalendarController() {
    _loadEntries();
    _updateDisplayMonths(); // 初始化时设置默认月份范围
    // 远端 REST/MCP 写入后自动刷新（本机写入由内存状态同步维护）
    _cancelPluginWatch = AboutmeDataService.instance.onPluginChanged(
      'calendar_album',
      () => reloadEntries(),
    );
  }

  @override
  void dispose() {
    _cancelPluginWatch();
    super.dispose();
  }

  DateTime get selectedDate => _selectedDate;
  DateTime get currentMonth => _currentMonth;
  DateTime get rangeStart => _rangeStart;
  DateTime get rangeEnd => _rangeEnd;

  set currentMonth(DateTime month) {
    _currentMonth = DateTime(month.year, month.month);
    _rangeStart = DateTime(
      _currentMonth.year,
      _currentMonth.month - 1,
    ); // 默认显示前后1个月
    _rangeEnd = DateTime(_currentMonth.year, _currentMonth.month + 1);
    _updateDisplayMonths();
    notifyListeners();
  }

  bool get isExpanded => _rangeStart.month != _rangeEnd.month;

  void expandRange() {
    _rangeStart = DateTime(_currentMonth.year, _currentMonth.month - 3);
    _rangeEnd = DateTime(_currentMonth.year, _currentMonth.month + 3);
    _updateDisplayMonths();
    notifyListeners();
  }

  void collapseRange() {
    _rangeStart = DateTime(_currentMonth.year, _currentMonth.month);
    _rangeEnd = DateTime(_currentMonth.year, _currentMonth.month);
    _updateDisplayMonths();
    notifyListeners();
  }

  void toggleExpanded() {
    if (isExpanded) {
      collapseRange();
    } else {
      expandRange();
    }
  }

  void _updateDisplayMonths() {
    _displayMonths.clear();
    var current = DateTime(_rangeStart.year, _rangeStart.month);
    final end = DateTime(_rangeEnd.year, _rangeEnd.month);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      _displayMonths.add(current);
      current = DateTime(current.year, current.month + 1);
    }
  }

  Map<DateTime, List<CalendarEntry>> get entries => _entries;

  bool loadMoreMonths(bool isBefore) {
    if (_displayMonths.isEmpty) return false;

    final newMonths = <DateTime>[];

    if (isBefore) {
      final firstMonth = _displayMonths.first;
      for (int i = 1; i <= 3; i++) {
        newMonths.add(DateTime(firstMonth.year, firstMonth.month - i));
      }
      _displayMonths.insertAll(0, newMonths);
      _rangeStart = _displayMonths.first;
    } else {
      final lastMonth = _displayMonths.last;
      for (int i = 1; i <= 3; i++) {
        newMonths.add(DateTime(lastMonth.year, lastMonth.month + i));
      }
      _displayMonths.addAll(newMonths);
      _rangeEnd = _displayMonths.last;
    }
    notifyListeners();
    return true;
  }

  List<DateTime> get displayMonths => _displayMonths;

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  List<CalendarEntry> getEntriesForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _entries[key] ?? [];
  }

  static String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _ok(Map<String, dynamic> result) => result['success'] == true;

  Future<void> _loadEntries() async {
    try {
      final result = await AboutmeDataService.instance.get(
        'calendar_album',
        'getSnapshot',
      );
      if (!_ok(result)) return;
      final data = (result['data'] as Map)['data'] as Map? ?? {};
      if (data.isEmpty) return;

      // 加载现有数据
      data.forEach((key, value) {
        final date = parseIsoDateTime(key as String);
        final entries =
            (value as List)
                .map(
                  (e) =>
                      CalendarEntry.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
        _entries[date] = entries;
      });
      notifyListeners();
    } catch (e) {
      debugPrint('加载日历相册数据失败: $e');
    }
  }

  /// 重新加载日记数据（供同步后刷新使用）
  Future<void> reloadEntries() async {
    _entries.clear();
    await _loadEntries();
  }

  /// 加载示例数据（存储为空时写入，供首次打开引导选择调用）
  Future<void> loadSampleData() async {
    final snapshot = await AboutmeDataService.instance.get(
      'calendar_album',
      'getSnapshot',
    );
    if (!_ok(snapshot)) return;
    final existing = ((snapshot['data'] as Map)['data'] as Map?) ?? {};
    if (existing.isNotEmpty) return;
    final sampleEntries = CalendarAlbumSampleData.getSampleCalendarEntriesGrouped();

    // 示例数据按原日期分组结构一次性导入
    final entries = <String, dynamic>{};
    sampleEntries.forEach((date, list) {
      entries[date.toIso8601String()] =
          list.map((e) => e.toJson()).toList();
    });
    final result = await AboutmeDataService.instance.call(
      'calendar_album',
      'importData',
      {'entries': entries},
    );
    if (!_ok(result)) return;
    await reloadEntries();
    notifyListeners();
  }

  Future<bool> addEntry(CalendarEntry entry) async {
    final date = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final result = await AboutmeDataService.instance.call(
      'calendar_album',
      'create',
      entry.toJson(),
    );
    if (!_ok(result)) return false;
    _entries.putIfAbsent(date, () => []);
    _entries[date]!.add(entry);
    notifyListeners();

    // 广播添加事件
    _notifyEvent('added', entry);

    // 成就系统计数（A38 定格瞬间）：新增条目携带的照片张数
    if (entry.imageUrls.isNotEmpty) {
      EventManager.instance.broadcast(
        'album_photo_added',
        Value<int>(entry.imageUrls.length, 'album_photo_added'),
      );
    }

    // 同步小组件数据
    await PluginWidgetSyncHelper.instance.syncCalendarAlbum();
    return true;
  }

  Future<bool> updateEntry(CalendarEntry entry) async {
    final date = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final bucket = _entries[date];
    if (bucket == null) return false;
    final index = bucket.indexWhere((e) => e.id == entry.id);
    if (index == -1) return false;

    // 成就系统计数（A38 定格瞬间）：编辑新增的照片张数（差集）
    final oldImages = bucket[index].imageUrls;
    final addedImages = entry.imageUrls
        .where((url) => !oldImages.contains(url))
        .length;

    final result = await AboutmeDataService.instance.call(
      'calendar_album',
      'update',
      {'date': _dateStr(date), ...entry.toJson()},
    );
    if (!_ok(result)) return false;
    bucket[index] = entry;
    notifyListeners();
    if (addedImages > 0) {
      EventManager.instance.broadcast(
        'album_photo_added',
        Value<int>(addedImages, 'album_photo_added'),
      );
    }

    // 广播更新事件
    _notifyEvent('updated', entry);

    // 同步小组件数据
    await PluginWidgetSyncHelper.instance.syncCalendarAlbum();
    return true;
  }

  Future<void> deleteEntry(CalendarEntry entry) async {
    final date = DateTime(
      entry.createdAt.year,
      entry.createdAt.month,
      entry.createdAt.day,
    );
    final bucket = _entries[date];
    if (bucket == null || !bucket.any((e) => e.id == entry.id)) return;
    final result = await AboutmeDataService.instance.call(
      'calendar_album',
      'delete',
      {'date': _dateStr(date), 'id': entry.id},
    );
    if (!_ok(result)) return;
    bucket.removeWhere((e) => e.id == entry.id);
    if (bucket.isEmpty) {
      _entries.remove(date);
    }
    notifyListeners();

    // 广播删除事件
    _notifyEvent('deleted', entry);

    // 同步小组件数据
    await PluginWidgetSyncHelper.instance.syncCalendarAlbum();
  }

  List<String> getAllTags() {
    final Set<String> tags = {};
    for (var entries in _entries.values) {
      for (var entry in entries) {
        tags.addAll(entry.tags);
      }
    }
    return tags.toList()..sort();
  }

  List<CalendarEntry> getEntriesByTag(String tag) {
    final List<CalendarEntry> taggedEntries = [];
    for (var entries in _entries.values) {
      taggedEntries.addAll(entries.where((entry) => entry.tags.contains(tag)));
    }
    return taggedEntries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<CalendarEntry> getEntriesByTags(List<String> tags) {
    if (tags.isEmpty) return [];

    final List<CalendarEntry> taggedEntries = [];
    for (var entries in _entries.values) {
      taggedEntries.addAll(
        entries.where((entry) => tags.every((tag) => entry.tags.contains(tag))),
      );
    }
    return taggedEntries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<String> getAllImages() {
    final Set<String> images = {};
    for (var entries in _entries.values) {
      for (var entry in entries) {
        images.addAll(entry.imageUrls);
        images.addAll(entry.extractImagesFromMarkdown());
      }
    }
    return images.toList();
  }

  CalendarEntry? getEntryById(String id) {
    for (final entries in _entries.values) {
      for (final entry in entries) {
        if (entry.id == id) {
          return entry;
        }
      }
    }
    return null;
  }

  CalendarEntry? getDiaryEntryForImage(String imageUrl) {
    for (final entries in _entries.values) {
      for (final entry in entries) {
        if (entry.imageUrls.contains(imageUrl) ||
            entry.extractImagesFromMarkdown().contains(imageUrl)) {
          return entry;
        }
      }
    }
    return null;
  }

  int getAllEntriesCount() {
    return _entries.values.fold(0, (sum, entries) => sum + entries.length);
  }

  int getTodayEntriesCount() {
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);
    return _entries[key]?.length ?? 0;
  }

  int getLast7DaysEntriesCount() {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    int count = 0;

    var current = DateTime(
      sevenDaysAgo.year,
      sevenDaysAgo.month,
      sevenDaysAgo.day,
    );
    final end = DateTime(now.year, now.month, now.day);

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      count += _entries[current]?.length ?? 0;
      current = current.add(const Duration(days: 1));
    }

    return count;
  }
}
