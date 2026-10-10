import 'package:aboutme_data_sdk/io.dart';

import '../types.dart';
import '../utils.dart';

// Diary 插件专用处理器（移植自 nodejs handlers/diary.ts）。
//
// 数据格式：
// - {date}.json: 每天的日记文件
// - diary_index.json: 索引文件（包含日期列表和统计信息）

PluginHandlers createDiaryHandlers(PluginDataStore store) {
  // 读取索引文件
  Future<Map<String, dynamic>> readIndex(
    String userId,
    String encryptionKey,
  ) async {
    final data = await store.readPluginData(
      userId,
      'diary',
      'diary_index.json',
      encryptionKey,
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // 保存索引文件
  Future<void> saveIndex(
    String userId,
    String encryptionKey,
    Map<String, dynamic> index,
  ) {
    return store.writePluginData(
      userId,
      'diary',
      'diary_index.json',
      index,
      encryptionKey,
    );
  }

  // 读取单日日记
  Future<Map<String, dynamic>?> readEntry(
    String userId,
    String encryptionKey,
    String date,
  ) async {
    final data = await store.readPluginData(
      userId,
      'diary',
      '$date.json',
      encryptionKey,
    );
    if (data is! Map<String, dynamic>) return null;
    return data;
  }

  // 保存单日日记
  Future<void> saveEntry(
    String userId,
    String encryptionKey,
    Map<String, dynamic> entry,
  ) {
    final date = entry['date'] as String;
    return store.writePluginData(
      userId,
      'diary',
      '$date.json',
      entry,
      encryptionKey,
    );
  }

  // 读取所有日记（通过索引文件）
  Future<List<Map<String, dynamic>>> readAllEntries(
    String userId,
    String encryptionKey,
  ) async {
    final index = await readIndex(userId, encryptionKey);
    final entries = <Map<String, dynamic>>[];

    for (final key in index.keys.toList()) {
      // 跳过统计字段
      if (key == 'totalCharCount') continue;

      final entry = await readEntry(userId, encryptionKey, key);
      if (entry != null) {
        entries.add(entry);
      }
    }

    // 按日期降序排序
    entries.sort((a, b) {
      final aDate = (a['date'] as String?) ?? '';
      final bDate = (b['date'] as String?) ?? '';
      return bDate.compareTo(aDate);
    });

    return entries;
  }

  return {
    // 获取日记列表
    'getList': (userId, encryptionKey, params) async {
      try {
        var entries = await readAllEntries(userId, encryptionKey);

        // 按日期范围过滤
        final startDate = params['startDate'] as String?;
        final endDate = params['endDate'] as String?;

        if (startDate != null && startDate.isNotEmpty) {
          entries = entries
              .where(
                (e) => ((e['date'] as String?) ?? '').compareTo(startDate) >= 0,
              )
              .toList();
        }
        if (endDate != null && endDate.isNotEmpty) {
          entries = entries
              .where(
                (e) => ((e['date'] as String?) ?? '').compareTo(endDate) <= 0,
              )
              .toList();
        }

        return PluginResult.success(
          createPaginatedResult(
            entries,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取日记列表失败: $e');
      }
    },

    // 按日期获取
    'getByDate': (userId, encryptionKey, params) async {
      try {
        final date = params['date'].toString();
        final entry = await readEntry(userId, encryptionKey, date);

        if (entry == null) {
          return const PluginResult.failure('日记不存在', 'NOT_FOUND');
        }

        return PluginResult.success(entry);
      } catch (e) {
        return PluginResult.failure('获取日记失败: $e');
      }
    },

    // 创建日记
    'create': (userId, encryptionKey, params) async {
      try {
        final date = params['date'].toString();

        // 检查是否已存在
        final existing = await readEntry(userId, encryptionKey, date);
        if (existing != null) {
          return const PluginResult.failure('该日期已有日记', 'CONFLICT');
        }

        final now = jsIsoDateTime(DateTime.now());
        final newEntry = <String, dynamic>{
          ...params,
          'createdAt': now,
          'updatedAt': now,
        };

        // 保存日记文件
        await saveEntry(userId, encryptionKey, newEntry);

        // 更新索引
        final index = await readIndex(userId, encryptionKey);
        index[date] = {'lastUpdated': now};
        final totalCharCount = (index['totalCharCount'] as num?) ?? 0;
        index['totalCharCount'] =
            totalCharCount + (params['content'] ?? '').toString().length;
        await saveIndex(userId, encryptionKey, index);

        return PluginResult.success(newEntry);
      } catch (e) {
        return PluginResult.failure('创建日记失败: $e');
      }
    },

    // 按日期更新
    'updateByDate': (userId, encryptionKey, params) async {
      try {
        final date = params['date'].toString();
        final existing = await readEntry(userId, encryptionKey, date);

        if (existing == null) {
          return const PluginResult.failure('日记不存在', 'NOT_FOUND');
        }

        // 计算字数差异
        final oldLength = (existing['content'] ?? '').toString().length;
        final newLength = (params['content'] ?? '').toString().length;
        final lengthDiff = newLength - oldLength;

        final updatedEntry = <String, dynamic>{
          ...existing,
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };

        // 保存日记文件
        await saveEntry(userId, encryptionKey, updatedEntry);

        // 更新索引
        final index = await readIndex(userId, encryptionKey);
        final totalCharCount = (index['totalCharCount'] as num?) ?? 0;
        index['totalCharCount'] = totalCharCount + lengthDiff;
        index[date] = {'lastUpdated': jsIsoDateTime(DateTime.now())};
        await saveIndex(userId, encryptionKey, index);

        return PluginResult.success(updatedEntry);
      } catch (e) {
        return PluginResult.failure('更新日记失败: $e');
      }
    },

    // 按日期删除
    'deleteByDate': (userId, encryptionKey, params) async {
      try {
        final date = params['date'].toString();
        final existing = await readEntry(userId, encryptionKey, date);

        if (existing == null) {
          return const PluginResult.failure('日记不存在', 'NOT_FOUND');
        }

        // 获取内容长度
        final contentLength = (existing['content'] ?? '').toString().length;

        // 删除日记文件
        await store.deletePluginFile(userId, 'diary', '$date.json');

        // 从索引中移除
        final index = await readIndex(userId, encryptionKey);
        index.remove(date);
        final totalCharCount = (index['totalCharCount'] as num?) ?? 0;
        final remaining = totalCharCount - contentLength < 0
            ? 0
            : totalCharCount - contentLength;
        index['totalCharCount'] = remaining;
        await saveIndex(userId, encryptionKey, index);

        return PluginResult.success({'date': date});
      } catch (e) {
        return PluginResult.failure('删除日记失败: $e');
      }
    },

    // 搜索
    'search': (userId, encryptionKey, params) async {
      try {
        var entries = await readAllEntries(userId, encryptionKey);

        final keyword = params['keyword'];
        final startDate = params['startDate'];
        final endDate = params['endDate'];
        final mood = params['mood'];

        if (startDate != null && startDate.toString().isNotEmpty) {
          final start = startDate.toString();
          entries = entries
              .where(
                (e) => ((e['date'] as String?) ?? '').compareTo(start) >= 0,
              )
              .toList();
        }
        if (endDate != null && endDate.toString().isNotEmpty) {
          final end = endDate.toString();
          entries = entries
              .where((e) => ((e['date'] as String?) ?? '').compareTo(end) <= 0)
              .toList();
        }
        if (mood != null && mood.toString().isNotEmpty) {
          entries = entries.where((e) => e['mood'] == mood).toList();
        }
        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          entries = entries.where((e) {
            final title = (e['title'] ?? '').toString().toLowerCase();
            final content = (e['content'] ?? '').toString().toLowerCase();
            return title.contains(kw) || content.contains(kw);
          }).toList();
        }

        return PluginResult.success({'data': entries, 'total': entries.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },

    // 获取统计
    'getStats': (userId, encryptionKey, params) async {
      try {
        final entries = await readAllEntries(userId, encryptionKey);

        final totalEntries = entries.length;
        var totalWords = 0;
        for (final e in entries) {
          totalWords += (e['content'] ?? '').toString().length;
        }
        final averageWords = totalEntries > 0
            ? (totalWords / totalEntries).round()
            : 0;

        return PluginResult.success({
          'totalEntries': totalEntries,
          'totalWords': totalWords,
          'averageWords': averageWords,
        });
      } catch (e) {
        return PluginResult.failure('获取统计失败: $e');
      }
    },
  };
}
