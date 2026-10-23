import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

/// MediaLog 域业务：媒体记录（阅读/观影）单主集合 items.json（`{items: []}`，
/// 与旧客户端文件格式一致，顶层 List 亦可读）、视图偏好 ui_settings.json。
/// 主集合首次成功写前把原始文件快照到 migration_v1_backup.json
/// （ui_settings.json 不纳入快照）。
PluginHandlers createMediaLogHandlers(PluginData data) {
  const plugin = 'media_log';

  Future<List<Map<String, dynamic>>> readRows() async {
    final raw = await data.read(plugin, 'items.json');
    if (raw == null) return [];
    final rows = raw is List ? raw : raw is Map ? raw['items'] : null;
    if (rows is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final result = <Map<String, dynamic>>[];
    for (final e in rows) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/items.json row');
      final reviews = e['reviews'];
      if (reviews != null && reviews is! List)
        throw const DomainFailure('CORRUPT_DATA', 'Invalid reviews');
      result.add(Map<String, dynamic>.from(e));
    }
    return result;
  }

  Future<Map<String, dynamic>> readSettings() async {
    final raw = await data.read(plugin, 'ui_settings.json');
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> backup() async {
    if (await data.read(plugin, 'migration_v1_backup.json') != null) return;
    await data.write(plugin, 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'items': await data.read(plugin, 'items.json'),
    });
  }

  Future<void> saveRows(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'items.json', rows);
  }

  Map<String, dynamic> patchOf(Map<String, dynamic> p) => domainPatch(p)
    ..remove('id')
    ..remove('itemId');

  DateTime dateOf(Map<String, dynamic> row, String key) =>
      DateTime.tryParse('${row[key] ?? ''}') ?? DateTime(1970);

  // 与客户端 _getVisibleItems 同源：default 按 createdAt 倒序（新→旧）。
  List<Map<String, dynamic>> sortRows(
    List<Map<String, dynamic>> rows,
    String? sortBy,
  ) {
    final sorted = [...rows];
    switch (sortBy) {
      case 'title':
        sorted.sort((a, b) => '${a['title'] ?? ''}'.compareTo('${b['title'] ?? ''}'));
      case 'rating':
        sorted.sort(
          (a, b) => domainNumber(b['rating'] ?? 0)
              .compareTo(domainNumber(a['rating'] ?? 0)),
        );
      case 'finished':
        sorted.sort(
          (a, b) => dateOf(b, 'finishedAt').compareTo(dateOf(a, 'finishedAt')),
        );
      default:
        sorted.sort(
          (a, b) => dateOf(b, 'createdAt').compareTo(dateOf(a, 'createdAt')),
        );
    }
    return sorted;
  }

  bool passesFilters(Map<String, dynamic> row, Map<String, dynamic> p) {
    if (p['kind'] != null && row['kind'] != p['kind']) return false;
    final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
    if (keyword.isNotEmpty) {
      final inTitle = '${row['title'] ?? ''}'.toLowerCase().contains(keyword);
      final inAuthor = '${row['author'] ?? ''}'.toLowerCase().contains(keyword);
      final tags = row['tags'];
      final inTags = tags is List &&
          tags.any((t) => '$t'.toLowerCase().contains(keyword));
      if (!inTitle && !inAuthor && !inTags) return false;
    }
    final tags = p['tags'];
    if (tags is List && tags.isNotEmpty) {
      final rowTags = row['tags'];
      final selected = tags.map((t) => '$t').toList();
      final hit = rowTags is List &&
          rowTags.any((t) => selected.contains('$t'));
      if (!hit) return false;
    }
    if (p['finished'] == true && row['finishedAt'] == null) return false;
    if (p['finished'] == false && row['finishedAt'] != null) return false;
    if (p['minRating'] != null &&
        domainNumber(row['rating'] ?? 0) < domainNumber(p['minRating'])) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> normalizeReview(Map<String, dynamic> p, String id) {
    final text = '${p['text'] ?? ''}'.trim();
    if (text.isEmpty) throw ArgumentError('text required');
    final timestamp =
        p['timestamp'] ?? DateTime.now().toIso8601String();
    if (DateTime.tryParse('$timestamp') == null)
      throw ArgumentError('Invalid timestamp');
    final review = <String, dynamic>{
      'id': id,
      'text': text,
      'timestamp': '$timestamp',
    };
    for (final key in ['rating', 'author', 'avatar']) {
      if (p[key] != null) review[key] = p[key];
    }
    return review;
  }

  List<Map<String, dynamic>> reviewsOf(Map<String, dynamic> item) =>
      ((item['reviews'] as List?) ?? const [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

  return {
    'getSnapshot': domainAction((_) async => {
      'items': sortRows(await readRows(), null),
      'settings': await readSettings(),
    }),
    'getList': domainAction((p) async {
      var rows = sortRows(await readRows(), p['sortBy'] as String?)
          .where((r) => passesFilters(r, p))
          .toList();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'getById': domainAction((p) async {
      final rows = await readRows();
      return rows[domainIndex(rows, p['id'])];
    }),
    'create': domainAction((p) async {
      final rows = await readRows();
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Item exists');
      final item = <String, dynamic>{
        'kind': 'reading',
        'cover': 'sheep',
        'aspect': 1.42,
        'tags': <dynamic>[],
        'createdAt': DateTime.now().toIso8601String(),
        'reviews': <dynamic>[],
        ...patchOf(p),
        'id': id,
      };
      if (item['title'] is! String || (item['title'] as String).isEmpty)
        throw ArgumentError('title required');
      rows.insert(0, item);
      await saveRows(rows);
      return item;
    }),
    'update': domainAction((p) async {
      final rows = await readRows();
      final i = domainIndex(rows, p['id']);
      rows[i] = {...rows[i], ...patchOf(p)};
      await saveRows(rows);
      return rows[i];
    }),
    'delete': domainAction((p) async {
      final rows = await readRows();
      rows.removeAt(domainIndex(rows, p['id']));
      await saveRows(rows);
      return {'id': p['id']};
    }),
    'addReview': domainAction((p) async {
      final itemId = p['itemId'] ?? p['id'];
      if (itemId is! String || itemId.isEmpty)
        throw ArgumentError('itemId required');
      final rows = await readRows();
      final i = domainIndex(rows, itemId);
      final id = p['reviewId'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      final reviews = reviewsOf(rows[i]);
      final review = normalizeReview(p, id);
      final ri = reviews.indexWhere((r) => r['id'] == id);
      if (ri < 0) reviews.add(review); else reviews[ri] = review;
      reviews.sort((a, b) => '${b['timestamp'] ?? ''}'
          .compareTo('${a['timestamp'] ?? ''}'));
      rows[i] = {...rows[i], 'reviews': reviews};
      await saveRows(rows);
      return rows[i];
    }),
    'deleteReview': domainAction((p) async {
      final itemId = p['itemId'];
      final reviewId = p['reviewId'];
      if (itemId is! String || itemId.isEmpty)
        throw ArgumentError('itemId required');
      if (reviewId is! String || reviewId.isEmpty)
        throw ArgumentError('reviewId required');
      final rows = await readRows();
      final i = domainIndex(rows, itemId);
      rows[i] = {
        ...rows[i],
        'reviews': reviewsOf(rows[i])
            .where((r) => r['id'] != reviewId)
            .toList(),
      };
      await saveRows(rows);
      return rows[i];
    }),
    'getSettings': domainAction((_) => readSettings()),
    'updateSettings': domainAction((p) async {
      final settings = await readSettings();
      settings.addAll(domainPatch(p));
      await data.write(plugin, 'ui_settings.json', settings);
      return settings;
    }),
    'getStats': domainAction((_) async {
      final rows = await readRows();
      var ratings = 0.0;
      var ratedCount = 0;
      final counts = {'reading': 0, 'watching': 0};
      final finished = {'reading': 0, 'watching': 0};
      for (final row in rows) {
        final kind = row['kind'] == 'watching' ? 'watching' : 'reading';
        counts[kind] = (counts[kind] ?? 0) + 1;
        if (row['finishedAt'] != null) finished[kind] = (finished[kind] ?? 0) + 1;
        if (row['rating'] is num) {
          ratings += (row['rating'] as num).toDouble();
          ratedCount++;
        }
      }
      return {
        'total': rows.length,
        'reading': counts['reading'],
        'watching': counts['watching'],
        'finished': (finished['reading'] ?? 0) + (finished['watching'] ?? 0),
        'readingFinished': finished['reading'],
        'watchingFinished': finished['watching'],
        'avgRating': ratedCount > 0 ? ratings / ratedCount : null,
      };
    }),
    'exportData': domainAction((_) async => {
      'schemaVersion': 1,
      'items': sortRows(await readRows(), null),
      'settings': await readSettings(),
    }),
    'importData': domainAction((p) async {
      final payload = p['items'];
      if (payload is! List)
        throw const DomainFailure('CORRUPT_DATA', 'Expected array');
      final incoming = <Map<String, dynamic>>[];
      for (final e in payload) {
        if (e is! Map || e['id'] is! String)
          throw const DomainFailure('CORRUPT_DATA', 'Invalid import row');
        incoming.add(Map<String, dynamic>.from(e));
      }
      final rows = await readRows();
      final merged = [
        ...rows,
        ...incoming.where((e) => !rows.any((r) => r['id'] == e['id'])),
      ];
      await saveRows(merged);
      final settings = p['settings'];
      if (settings is Map && settings.isNotEmpty) {
        final current = await readSettings();
        current.addAll(Map<String, dynamic>.from(settings));
        await data.write(plugin, 'ui_settings.json', current);
      }
      return {
        'inserted': merged.length - rows.length,
        'total': merged.length,
      };
    }),
    'seedExamples': domainAction((p) async {
      var insertedItems = 0;
      final payload = p['items'];
      if (payload is List && payload.isNotEmpty) {
        final rows = await readRows();
        if (rows.isEmpty) {
          for (final e in payload) {
            if (e is! Map || e['id'] is! String)
              throw const DomainFailure('CORRUPT_DATA', 'Invalid example item');
            rows.add(Map<String, dynamic>.from(e));
          }
          await saveRows(rows);
          insertedItems = rows.length;
        }
      }
      return {'insertedItems': insertedItems};
    }),
  };
}
