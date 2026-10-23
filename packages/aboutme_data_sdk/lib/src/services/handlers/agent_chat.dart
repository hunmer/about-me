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

  // ===== 外围配置（tools/tool_templates/message_details/route_agent_configs/
  // test_runs/preferences）=====
  // 旧客户端把它们作为 agent_chat/ 前缀下的独立 JSON 文件直接读写；
  // 命令保持原文件布局，tools/tool_templates 可由客户端从 assets 重建
  // 不纳入迁移备份。

  String checkFileId(dynamic value, String label) {
    if (value is! String ||
        value.isEmpty ||
        value.contains('/') ||
        value.contains('\\') ||
        value.contains('..'))
      throw ArgumentError('$label required');
    return value;
  }

  const preferenceFiles = <String, String>{
    'quickToolbarActions': 'quick_toolbar_actions',
    'suggestedQuestionsCategory': 'suggested_questions_last_category',
  };

  void checkPreferenceValue(String key, dynamic value) {
    if (key == 'quickToolbarActions' &&
        (value is! List || !value.every((e) => e is String)))
      throw ArgumentError('quickToolbarActions must be a string list');
    if (key == 'suggestedQuestionsCategory' && value is! String)
      throw ArgumentError('suggestedQuestionsCategory must be a string');
  }

  return {
    // ---- 工具配置（每插件一个 Map + index.json 索引）----
    'getToolPlugin': domainAction(
      (p) => data.read(
        plugin,
        'tools/${checkFileId(p['pluginId'], 'pluginId')}.json',
      ),
    ),
    'saveToolPlugin': domainAction((p) async {
      final pluginId = checkFileId(p['pluginId'], 'pluginId');
      final tools = p['tools'];
      if (tools is! Map) throw ArgumentError('tools required');
      await data.write(plugin, 'tools/$pluginId.json', tools);
      return {'pluginId': pluginId, 'count': tools.length};
    }),
    'getToolIndexFile': domainAction((_) => data.read(plugin, 'tools/index.json')),
    'saveToolIndexFile': domainAction((p) async {
      final index = p['index'];
      if (index is! List) throw ArgumentError('index required');
      await data.write(plugin, 'tools/index.json', index);
      return {'count': index.length};
    }),
    // 恢复默认：清空 tools/ 下全部文件（客户端随后从 assets 重拷）
    'clearToolPlugins': domainAction((_) async {
      var count = 0;
      for (final file in await data.listFiles(plugin, 'tools/*.json')) {
        if (await data.delete(plugin, file)) count++;
      }
      return {'count': count};
    }),
    // ---- 工具模板（每模板一个文件，客户端从 assets 补默认模板）----
    'listToolTemplates': domainAction((_) async {
      final rows = <Map<String, dynamic>>[];
      for (final file in await data.listFiles(
        plugin,
        'tool_templates/*.json',
      )) {
        final raw = await data.read(plugin, file);
        if (raw is Map && raw['id'] is String)
          rows.add(Map<String, dynamic>.from(raw));
      }
      return rows;
    }),
    'saveToolTemplate': domainAction((p) async {
      final id = checkFileId(p['id'] ?? p['template']?['id'], 'id');
      final template = p['template'];
      if (template is! Map) throw ArgumentError('template required');
      await data.write(plugin, 'tool_templates/$id.json', template);
      return template;
    }),
    'deleteToolTemplate': domainAction((p) async {
      final id = checkFileId(p['id'], 'id');
      await data.delete(plugin, 'tool_templates/$id.json');
      return {'id': id};
    }),
    // ---- 消息详情（AI 输入/思考/工具调用，无扩展名单文件）----
    'getMessageDetail': domainAction(
      (p) => data.read(plugin, 'message_details/${checkFileId(p['messageId'], 'messageId')}'),
    ),
    'saveMessageDetail': domainAction((p) async {
      final messageId = checkFileId(p['messageId'], 'messageId');
      final detail = p['detail'];
      if (detail is! Map) throw ArgumentError('detail required');
      await data.write(plugin, 'message_details/$messageId', detail);
      return detail;
    }),
    'deleteMessageDetail': domainAction((p) async {
      final messageId = checkFileId(p['messageId'], 'messageId');
      await data.delete(plugin, 'message_details/$messageId');
      return {'messageId': messageId};
    }),
    // ---- 路由 Agent 配置（单文件 Map：routeName -> config）----
    'getRouteAgentConfigs': domainAction((_) async {
      final raw = await data.read(plugin, 'route_agent_configs');
      if (raw == null) return <String, dynamic>{};
      if (raw is! Map)
        throw const DomainFailure('CORRUPT_DATA', 'Expected object');
      return Map<String, dynamic>.from(raw);
    }),
    'saveRouteAgentConfigs': domainAction((p) async {
      final configs = p['configs'];
      if (configs is! Map) throw ArgumentError('configs required');
      await data.write(plugin, 'route_agent_configs', configs);
      return {'count': configs.length};
    }),
    // ---- 建议问题测试报告（每次运行一个文件）----
    'listTestRuns': domainAction((_) async {
      final rows = <Map<String, dynamic>>[];
      for (final file in await data.listFiles(plugin, 'test_runs/*.json')) {
        final raw = await data.read(plugin, file);
        if (raw is Map) rows.add(Map<String, dynamic>.from(raw));
      }
      return rows;
    }),
    'saveTestRun': domainAction((p) async {
      final report = p['report'];
      final runId = checkFileId(
        p['runId'] ?? report?['runId'],
        'runId',
      );
      if (report is! Map) throw ArgumentError('report required');
      await data.write(plugin, 'test_runs/$runId.json', report);
      return report;
    }),
    // ---- UI 偏好（key 白名单映射到旧文件名）----
    // 旧客户端对 String 值是原样文本写入（suggested_questions_last_category
    // 为裸文本非 JSON），读取会得到 CORRUPT_DATA；客户端按无配置兜底
    // （与旧 readPathText 失败即 null 一致），首次 setPreference 覆盖修复。
    'getPreference': domainAction(
      (p) => data.read(
        plugin,
        preferenceFiles[p['key']] ??
            (throw ArgumentError('Unknown preference: ${p['key']}')),
      ),
    ),
    'setPreference': domainAction((p) async {
      final key = p['key'];
      final file = preferenceFiles[key];
      if (file == null) throw ArgumentError('Unknown preference: $key');
      checkPreferenceValue(key, p['value']);
      await data.write(plugin, file, p['value']);
      return {'key': key};
    }),
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
