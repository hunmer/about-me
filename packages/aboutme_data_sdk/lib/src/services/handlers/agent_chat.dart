import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

/// AgentChat 域业务：conversations.json 顶层 List 会话索引 +
/// 每会话 messages/{id}.json 分文件 + config 全局配置（无扩展名文件）。
/// 主集合首次成功写前把原始内容快照到 migration_v1_backup.json
/// （messages 分文件不纳入快照）。
PluginHandlers createAgentChatHandlers(PluginData data) {
  const plugin = 'agent_chat';

  Future<List<Map<String, dynamic>>> readConversations() async {
    final raw = await data.read(plugin, 'conversations.json');
    if (raw == null) return [];
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/conversations row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  /// 行校验：顶层 List（与旧客户端 ConversationService/MessageService
  /// 写入格式一致），每行必须是带字符串 id 的对象
  List<Map<String, dynamic>> parseRows(dynamic raw, String label) {
    if (raw is! List)
      throw const DomainFailure('CORRUPT_DATA', 'Expected array');
    final rows = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is! Map || e['id'] is! String)
        throw DomainFailure('CORRUPT_DATA', 'Invalid $plugin/$label row');
      rows.add(Map<String, dynamic>.from(e));
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> readMessages(String conversationId) async {
    final raw = await data.read(plugin, 'messages/$conversationId.json');
    if (raw == null) return [];
    return parseRows(raw, 'messages/$conversationId.json');
  }

  Future<Map<String, dynamic>> readConfig() async {
    // 全局配置为无扩展名文件 'agent_chat/config'，JSON 读写不受扩展名限制
    final raw = await data.read(plugin, 'config');
    if (raw == null) return <String, dynamic>{};
    if (raw is! Map)
      throw const DomainFailure('CORRUPT_DATA', 'Expected object');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> backup() async {
    if (await data.read(plugin, 'migration_v1_backup.json') != null) return;
    await data.write(plugin, 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'conversations': await data.read(plugin, 'conversations.json'),
      'config': await data.read(plugin, 'config'),
    });
  }

  Future<void> saveConversations(List<Map<String, dynamic>> rows) async {
    await backup();
    await data.write(plugin, 'conversations.json', rows);
  }

  void checkConversationId(dynamic value) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\'))
      throw ArgumentError('conversationId required');
  }

  // 与客户端统计同源：本地时区当天 [todayStart, todayEnd) 内的消息数
  Future<({int today, int total})> messageStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    var today = 0, total = 0;
    for (final file in await data.listFiles(plugin, 'messages/*.json')) {
      final conversationId = file.substring(
        'messages/'.length,
        file.length - '.json'.length,
      );
      for (final row in await readMessages(conversationId)) {
        total++;
        final timestamp = DateTime.tryParse('${row['timestamp'] ?? ''}');
        if (timestamp != null &&
            timestamp.isAfter(todayStart) &&
            timestamp.isBefore(todayEnd)) {
          today++;
        }
      }
    }
    return (today: today, total: total);
  }

  Map<String, dynamic> patchOf(Map<String, dynamic> p) => domainPatch(p)
    ..remove('id')
    ..remove('conversationId')
    ..remove('parentId');

  return {
    'getSnapshot': domainAction((_) async {
      final counts = <String, int>{};
      for (final file in await data.listFiles(plugin, 'messages/*.json')) {
        final conversationId = file.substring(
          'messages/'.length,
          file.length - '.json'.length,
        );
        counts[conversationId] =
            (await readMessages(conversationId)).length;
      }
      return {
        'conversations': await readConversations(),
        'config': await readConfig(),
        'messageCounts': counts,
      };
    }),
    'getList': domainAction((p) async {
      final rows = await readConversations();
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'getById': domainAction((p) async {
      final rows = await readConversations();
      return rows[domainIndex(rows, p['id'])];
    }),
    'create': domainAction((p) async {
      final rows = await readConversations();
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Conversation exists');
      final conversation = <String, dynamic>{
        ...patchOf(p),
        'id': id,
      };
      if (conversation['title'] is! String ||
          (conversation['title'] as String).isEmpty) {
        throw ArgumentError('title required');
      }
      rows.add(conversation);
      await saveConversations(rows);
      return conversation;
    }),
    'update': domainAction((p) async {
      final rows = await readConversations();
      final i = domainIndex(rows, p['id']);
      rows[i] = {...rows[i], ...patchOf(p)};
      await saveConversations(rows);
      return rows[i];
    }),
    'delete': domainAction((p) async {
      final rows = await readConversations();
      rows.removeAt(domainIndex(rows, p['id']));
      await saveConversations(rows);
      await data.delete(plugin, 'messages/${p['id']}.json');
      return {'id': p['id']};
    }),
    // 整表替换：客户端 ConversationService 保持全量缓存 + 串行保存链语义
    'saveConversations': domainAction((p) async {
      final payload = p['conversations'];
      if (payload is! List)
        throw ArgumentError('conversations required');
      final rows = parseRows(payload, 'conversations.json');
      await saveConversations(rows);
      return {'count': rows.length};
    }),
    'getMessages': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      final rows = await readMessages(conversationId);
      return createPaginatedResult(
        rows,
        offset: p['offset'] as int?,
        count: p['count'] as int? ?? rows.length,
      );
    }),
    'appendMessage': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      final id = p['id'] ?? generateUUID();
      if (id is! String || id.isEmpty) throw ArgumentError('ID无效');
      final rows = await readMessages(conversationId);
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Message exists');
      final message = <String, dynamic>{
        ...patchOf(p),
        'id': id,
        'conversationId': conversationId,
      };
      rows.add(message);
      await data.write(plugin, 'messages/$conversationId.json', rows);
      return message;
    }),
    'updateMessage': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      final rows = await readMessages(conversationId);
      final i = rows.indexWhere((e) => e['id'] == p['messageId']);
      if (i < 0) throw const DomainFailure('NOT_FOUND', 'Message not found');
      rows[i] = {
        ...rows[i],
        ...patchOf(p)..remove('messageId'),
      };
      await data.write(plugin, 'messages/$conversationId.json', rows);
      return rows[i];
    }),
    'deleteMessage': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      final rows = await readMessages(conversationId);
      final i = rows.indexWhere((e) => e['id'] == p['messageId']);
      if (i < 0) throw const DomainFailure('NOT_FOUND', 'Message not found');
      rows.removeAt(i);
      await data.write(plugin, 'messages/$conversationId.json', rows);
      return {'id': p['messageId']};
    }),
    // 删除会话消息文件（与旧客户端 deletePath 语义一致）
    'clearMessages': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      await data.delete(plugin, 'messages/$conversationId.json');
      return {'conversationId': conversationId};
    }),
    // 单会话消息全量替换：客户端 MessageService 保持全量缓存语义
    'saveMessages': domainAction((p) async {
      final conversationId = p['conversationId'] ?? p['parentId'];
      checkConversationId(conversationId);
      final payload = p['messages'];
      if (payload is! List) throw ArgumentError('messages required');
      final rows = parseRows(
        payload,
        'messages/$conversationId.json',
      );
      await data.write(plugin, 'messages/$conversationId.json', rows);
      return {'conversationId': conversationId, 'count': rows.length};
    }),
    'getConfig': domainAction((_) => readConfig()),
    'updateConfig': domainAction((p) async {
      final config = await readConfig();
      config.addAll(domainPatch(p));
      await data.write(plugin, 'config', config);
      return config;
    }),
    'getStats': domainAction((_) async {
      final stats = await messageStats();
      return {
        'todayMessageCount': stats.today,
        'totalMessageCount': stats.total,
      };
    }),
  };
}
