import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:shared_models/shared_models.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/plugins/diary/models/diary_entry.dart';
import 'package:aboutme/plugins/diary/diary_plugin.dart';

/// 日记 UI 模型适配。日期布局、索引、统计和示例由 SDK 管理。
class DiaryUtils {
  static AboutmeData get _data => AboutmeDataService.instance.data;
  static String contentToPlainText(String content) =>
      DiaryCodec.plainText(content);
  static String _day(DateTime date) => DiaryCodec.formatDate(date);
  static dynamic _result(Map<String, dynamic> response) {
    if (response['success'] != true) throw QueryFailure(response);
    return response['data'];
  }

  static Map<DateTime, DiaryEntry> _entries(Map<String, dynamic> response) => {
    for (final raw in (_result(response) as Map)['data'] as List)
      DateTime.parse(raw['date'] as String): DiaryEntry.fromJson({
        ...Map<String, dynamic>.from(raw as Map),
        '_sdkVersion': response['version'],
      }),
  };
  static Future<Map<DateTime, DiaryEntry>> loadDiaryEntries() async =>
      _entries(await _data.query('diary', 'getSnapshot'));
  static Stream<Map<DateTime, DiaryEntry>> watchEntries() => _data
      .watch('diary', 'getSnapshot')
      .where(
        (snapshot) =>
            snapshot.status == QueryStatus.data ||
            snapshot.status == QueryStatus.error,
      )
      .map((snapshot) {
        if (snapshot.error != null) throw snapshot.error!;
        return _entries(snapshot.result!);
      });
  static Future<({DiaryEntry? entry, int? version})> loadDiarySnapshot(
    DateTime date,
  ) async {
    final response = await _data.get('diary', 'getByDate', {
      'date': _day(date),
    });
    if (response['code'] == 'NOT_FOUND') {
      return (entry: null, version: response['version'] as int?);
    }
    final json = Map<String, dynamic>.from(_result(response) as Map);
    return (
      entry: DiaryEntry.fromJson({...json, '_sdkVersion': response['version']}),
      version: response['version'] as int?,
    );
  }

  static Future<DiaryEntry?> loadDiaryEntry(DateTime date) async =>
      (await loadDiarySnapshot(date)).entry;

  static Future<void> saveDiaryEntry(
    DateTime date,
    String content, {
    String title = '',
    String? mood,
    List<String>? tags,
    int? expectedVersion,
    void Function(DiaryEntry entry, int? version)? onCommitted,
  }) async {
    final response = await _data.call('diary', 'save', {
      'date': _day(date),
      'content': content,
      'title': title,
      'mood': mood,
      if (tags != null) 'tags': tags,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    final saved = DiaryEntry.fromJson({
      ...Map<String, dynamic>.from(_result(response) as Map),
      '_sdkVersion': response['version'],
    });
    onCommitted?.call(saved, response['version'] as int?);
    EventManager.instance.broadcast(
      'diary_entry_updated',
      DiaryEntryUpdatedEventArgs(saved),
    );
    await PluginWidgetSyncHelper.instance.syncDiary();
  }

  static Future<void> createSampleEntries() async {
    _result(
      await _data.call('diary', 'seedExamples', {
        'groups': ['entries'],
        'templateVersion': 1,
      }),
    );
  }

  static Future<bool> deleteDiaryEntry(
    DateTime date, {
    int? expectedVersion,
  }) async {
    final response = await _data.call('diary', 'deleteByDate', {
      'date': _day(date),
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
    });
    if (response['code'] == 'NOT_FOUND') return false;
    _result(response);
    EventManager.instance.broadcast(
      'diary_entry_deleted',
      DiaryEntryDeletedEventArgs(date),
    );
    await PluginWidgetSyncHelper.instance.syncDiary();
    return true;
  }

  static Future<bool> hasEntryForDate(DateTime date) async =>
      await loadDiaryEntry(date) != null;
  static Future<Map<String, dynamic>> getDiaryStats() async =>
      Map<String, dynamic>.from(
        _result(await _data.get('diary', 'getStats')) as Map,
      );
  static Future<int> getTotalCharCount() async =>
      (await getDiaryStats())['totalCharCount'] as int;
  static Future<int> getEntryCharCount(DateTime date) async {
    final entry = await loadDiaryEntry(date);
    return entry == null ? 0 : contentToPlainText(entry.content).trim().length;
  }

  static Future<List<DiaryEntry>> searchDiaryEntries(String query) async {
    if (query.trim().isEmpty) return [];
    return _entries(
      await _data.query('diary', 'getSnapshot', {'keyword': query}),
    ).values.toList();
  }
}
