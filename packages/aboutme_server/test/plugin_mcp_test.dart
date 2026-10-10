import 'dart:convert';
import 'dart:io';

import 'package:aboutme_server/src/config.dart';
import 'package:aboutme_server/src/server_builder.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

/// 插件 REST API + MCP 端点集成测试。
void main() {
  late Directory tempDir;
  late HttpServer server;
  late String baseUrl;
  late String apiKey;
  late HttpClient client;

  const encryptionKey = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_plugin_test');
    final config = ServerConfig(
      port: 0,
      dataDir: tempDir.path,
      jwtSecret: 'plugin-test-secret',
      tokenExpiryDays: 30,
      enableCors: true,
      corsOrigins: ['*'],
      maxStorageFileSizeBytes: 1024 * 1024,
      storageRateLimitPerMinute: 10000,
      enableLogging: false,
      adminUsername: 'admin',
      adminPassword: 'admin123',
      allowRegister: true,
    );
    final handler = await buildServer(config);
    server = await serve(handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    client = HttpClient();

    // 注册用户并签发 API Key
    final register = await _post(
      client,
      baseUrl,
      '/api/v1/auth/register',
      {'username': 'plugin-user', 'password': 'secret66', 'device_id': 'd1'},
    );
    final token = (register['token'] as String?) ?? '';
    final keyResponse = await _post(
      client,
      baseUrl,
      '/api/v1/auth/api-keys',
      {'name': 'test', 'expiry': 'never'},
      bearer: token,
    );
    apiKey = ((keyResponse['api_key'] as Map)['key']) as String;
  });

  tearDown(() async {
    client.close();
    await server.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Map<String, String> _pluginHeaders() => {
    'X-API-Key': apiKey,
    'X-Encryption-Key': encryptionKey,
  };

  group('插件 REST API', () {
    test('缺少 X-Encryption-Key 返回 403；无效 API Key 返回 401', () async {
      final noKey = await client.getUrl(
        Uri.parse('$baseUrl/api/v1/plugins/chat/channels'),
      )
        ..headers.set('X-API-Key', apiKey);
      final noKeyResponse = await noKey.close();
      expect(noKeyResponse.statusCode, 403);
      await noKeyResponse.drain();

      final badKey = await client.getUrl(
        Uri.parse('$baseUrl/api/v1/plugins/chat/channels'),
      )
        ..headers.set('X-API-Key', 'mk_bad')
        ..headers.set('X-Encryption-Key', encryptionKey);
      final badKeyResponse = await badKey.close();
      expect(badKeyResponse.statusCode, 401);
      await badKeyResponse.drain();
    });

    test('chat：建频道 → 列表 → 发消息 → 查消息 → 删除', () async {
      final created = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/chat/channels',
        {'name': 'AI 日常'},
        headers: _pluginHeaders(),
      );
      expect(created['success'], isTrue, reason: '$created');
      final channel = created['data'] as Map<String, dynamic>;
      expect(channel['name'], 'AI 日常');
      expect(channel['id'], isNotNull);
      final channelId = channel['id'] as String;

      final sent = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/chat/channels/$channelId/messages',
        {
          'content': 'hello from test',
          'senderId': 'tester',
          'senderName': 'Tester',
        },
        headers: _pluginHeaders(),
      );
      expect(sent['success'], isTrue, reason: '$sent');
      expect(sent['data']['content'], 'hello from test');

      final messages = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/chat/channels/$channelId/messages',
        headers: _pluginHeaders(),
      );
      expect(
        ((messages['data'] as Map)['data'] as List).length,
        1,
      );

      final deleted = await _delete(
        client,
        baseUrl,
        '/api/v1/plugins/chat/channels/$channelId',
        headers: _pluginHeaders(),
      );
      expect(deleted['success'], isTrue);
    });

    test('通用 CRUD 插件（timer）：增查改删', () async {
      final created = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/timer/item',
        {'title': 'focus timer'},
        headers: _pluginHeaders(),
      );
      expect(created['success'], isTrue, reason: '$created');
      final id = (created['data'] as Map)['id'] as String;

      final updated = await _put(
        client,
        baseUrl,
        '/api/v1/plugins/timer/item/$id',
        {'title': 'focus timer 2'},
        headers: _pluginHeaders(),
      );
      expect(updated['success'], isTrue);
      expect((updated['data'] as Map)['title'], 'focus timer 2');

      final list = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/timer/items',
        headers: _pluginHeaders(),
      );
      expect(((list['data'] as Map)['data'] as List).length, 1);

      final deleted = await _delete(
        client,
        baseUrl,
        '/api/v1/plugins/timer/item/$id',
        headers: _pluginHeaders(),
      );
      expect(deleted['success'], isTrue);
    });

    test('插件数据落盘为旧版加密文件（无明文）', () async {
      await _post(
        client,
        baseUrl,
        '/api/v1/plugins/timer/item',
        {'title': 'secret-title'},
        headers: _pluginHeaders(),
      );
      final usersDir = Directory('${tempDir.path}/users');
      final dataFile = usersDir
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('timer/data.json'));
      final content = await dataFile.readAsString();
      expect(content.contains('secret-title'), isFalse);
      expect(content, contains('encrypted_data'));
    });

    test('diary：按日期创建/读取', () async {
      final created = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/diary/entries',
        {'date': '2026-10-11', 'content': '今天完成了移植', 'mood': '4'},
        headers: _pluginHeaders(),
      );
      expect(created['success'], isTrue, reason: '$created');

      final entry = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/diary/entries/2026-10-11',
        headers: _pluginHeaders(),
      );
      expect(entry['success'], isTrue);
      expect((entry['data'] as Map)['content'], contains('移植'));
    });

    test('notes：创建笔记/文件夹与搜索', () async {
      final created = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/notes/notes',
        {'title': '移植笔记', 'content': 'server 完成', 'tags': ['dart']},
        headers: _pluginHeaders(),
      );
      expect(created['success'], isTrue, reason: '$created');

      final searched = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/notes/search?keyword=移植',
        headers: _pluginHeaders(),
      );
      expect(searched['success'], isTrue);

      final folder = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/notes/folders',
        {'name': '工作'},
        headers: _pluginHeaders(),
      );
      expect(folder['success'], isTrue, reason: '$folder');
    });

    test('todo：创建/完成/统计', () async {
      final created = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/todo/tasks',
        {'title': '写测试', 'priority': 2},
        headers: _pluginHeaders(),
      );
      expect(created['success'], isTrue, reason: '$created');
      final id = (created['data'] as Map)['id'] as String;

      final completed = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/todo/tasks/$id/complete',
        {},
        headers: _pluginHeaders(),
      );
      expect(completed['success'], isTrue, reason: '$completed');

      final stats = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/todo/stats',
        headers: _pluginHeaders(),
      );
      expect(stats['success'], isTrue);
    });

    test('bill：账户与账单', () async {
      final account = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/bill/accounts',
        {'name': '现金'},
        headers: _pluginHeaders(),
      );
      expect(account['success'], isTrue, reason: '$account');
      final accountId = (account['data'] as Map)['id'] as String;

      final bill = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/bill/accounts/$accountId/bills',
        {'type': 'expense', 'amount': 25.5, 'category': '餐饮'},
        headers: _pluginHeaders(),
      );
      expect(bill['success'], isTrue, reason: '$bill');

      final bills = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/bill/accounts/$accountId/bills',
        headers: _pluginHeaders(),
      );
      expect(bills['success'], isTrue);
      expect(((bills['data'] as Map)['data'] as List).length, 1);
    });

    test('tracker/goal + record', () async {
      final goal = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/tracker/goals',
        {'name': '喝水', 'targetValue': 8, 'unitType': '杯'},
        headers: _pluginHeaders(),
      );
      expect(goal['success'], isTrue, reason: '$goal');
      final goalId = (goal['data'] as Map)['id'] as String;

      final record = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/tracker/records',
        {'goalId': goalId, 'value': 3, 'date': '2026-10-11'},
        headers: _pluginHeaders(),
      );
      expect(record['success'], isTrue, reason: '$record');

      final records = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/tracker/goals/$goalId/records',
        headers: _pluginHeaders(),
      );
      expect(records['success'], isTrue);
    });

    test('calendar/contact/day/goods/checkin/activity 各自主流程', () async {
      // calendar
      final event = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/calendar/events',
        {'title': '发布 Dart 服务器', 'startTime': '2026-10-11T10:00:00'},
        headers: _pluginHeaders(),
      );
      expect(event['success'], isTrue, reason: '$event');

      // contact
      final contact = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/contact/contacts',
        {'name': '张三', 'phone': '13800000000'},
        headers: _pluginHeaders(),
      );
      expect(contact['success'], isTrue, reason: '$contact');
      final searched = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/contact/contacts/search?keyword=张',
        headers: _pluginHeaders(),
      );
      expect(searched['success'], isTrue);

      // day
      final day = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/day/days',
        {'title': '纪念日', 'targetDate': '2026-12-31'},
        headers: _pluginHeaders(),
      );
      expect(day['success'], isTrue, reason: '$day');

      // goods
      final warehouse = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/goods/warehouses',
        headers: _pluginHeaders(),
      );
      expect(warehouse['success'], isTrue);

      // checkin
      final checkinItem = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/checkin/items',
        {'name': '早起'},
        headers: _pluginHeaders(),
      );
      expect(checkinItem['success'], isTrue, reason: '$checkinItem');

      // activity
      final activity = await _post(
        client,
        baseUrl,
        '/api/v1/plugins/activity/activities',
        {
          'title': '移植完成',
          'startTime': '2026-10-11T09:00:00',
          'endTime': '2026-10-11T12:00:00',
        },
        headers: _pluginHeaders(),
      );
      expect(activity['success'], isTrue, reason: '$activity');

      final todayStats = await _get(
        client,
        baseUrl,
        '/api/v1/plugins/activity/stats/today',
        headers: _pluginHeaders(),
      );
      expect(todayStats['success'], isTrue);
    });
  });

  group('MCP 端点', () {
    Map<String, String> _mcpHeaders() => {
      'X-API-Key': apiKey,
      'X-Encryption-Key': encryptionKey,
      'Content-Type': 'application/json',
    };

    test('GET/DELETE 返回 405', () async {
      final get = await client.getUrl(Uri.parse('$baseUrl/mcp'))
        ..headers.set('X-API-Key', apiKey);
      final getResponse = await get.close();
      expect(getResponse.statusCode, 405);
      await getResponse.drain();
    });

    test('initialize → tools/list → tools/call 全流程', () async {
      final init = await _post(
        client,
        baseUrl,
        '/mcp',
        {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '0'},
          },
        },
        headers: _mcpHeaders(),
      );
      expect(init['result']['serverInfo']['name'], isNotNull);
      expect(init['result']['protocolVersion'], '2025-03-26');

      final tools = await _post(
        client,
        baseUrl,
        '/mcp',
        {
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
          'params': {},
        },
        headers: _mcpHeaders(),
      );
      final toolList = (tools['result']['tools'] as List);
      expect(toolList.length, greaterThan(60));
      expect(
        toolList.map((t) => (t as Map)['name']),
        containsAll([
          'aboutme_chat_sendMessage',
          'aboutme_todo_createTask',
          'aboutme_diary_getStats',
        ]),
      );

      // 工具调用真实写数据
      final call = await _post(
        client,
        baseUrl,
        '/mcp',
        {
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/call',
          'params': {
            'name': 'aboutme_chat_createChannel',
            'arguments': {'name': 'mcp-channel'},
          },
        },
        headers: _mcpHeaders(),
      );
      final result = call['result'] as Map<String, dynamic>;
      expect(result['isError'], isNull);
      final text = ((result['content'] as List).first as Map)['text'] as String;
      expect(text, contains('mcp-channel'));

      // 未知工具返回 isError
      final unknown = await _post(
        client,
        baseUrl,
        '/mcp',
        {
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/call',
          'params': {'name': 'aboutme_nonexistent', 'arguments': {}},
        },
        headers: _mcpHeaders(),
      );
      expect((unknown['result'] as Map)['isError'], isTrue);

      // 通知（无 id）→ 202
      final notifyRequest = await client.postUrl(Uri.parse('$baseUrl/mcp'));
      _mcpHeaders().forEach(notifyRequest.headers.set);
      notifyRequest.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      final notifyResponse = await notifyRequest.close();
      expect(notifyResponse.statusCode, 202);
      await notifyResponse.drain();
    });
  });

  group('system 路由', () {
    test('非管理员 403 / 管理员可读插件列表', () async {
      final login = await _post(
        client,
        baseUrl,
        '/api/v1/auth/login',
        {'username': 'admin', 'password': 'admin123', 'device_id': 'admin_panel'},
      );
      final adminToken = login['token'] as String;

      final userToken = (await _post(
        client,
        baseUrl,
        '/api/v1/auth/login',
        {'username': 'plugin-user', 'password': 'secret66', 'device_id': 'd1'},
      ))['token'] as String;

      final forbidden = await client.getUrl(
        Uri.parse('$baseUrl/api/v1/system/plugins'),
      )
        ..headers.set('Authorization', 'Bearer $userToken');
      final forbiddenResponse = await forbidden.close();
      expect(forbiddenResponse.statusCode, 403);
      await forbiddenResponse.drain();

      final ok = await client.getUrl(
        Uri.parse('$baseUrl/api/v1/system/plugins'),
      )
        ..headers.set('Authorization', 'Bearer $adminToken');
      final okResponse = await ok.close();
      expect(okResponse.statusCode, 200);
      final body =
          jsonDecode(await okResponse.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['plugins'], isA<List>());
    });
  });
}

Future<Map<String, dynamic>> _post(
  HttpClient client,
  String baseUrl,
  String path,
  Map<String, dynamic> body, {
  String? bearer,
  Map<String, String>? headers,
}) async {
  final request = await client.postUrl(Uri.parse('$baseUrl$path'));
  request.headers.contentType = ContentType.json;
  (headers ?? const {}).forEach(request.headers.set);
  if (bearer != null) {
    request.headers.set('Authorization', 'Bearer $bearer');
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  return jsonDecode(await response.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _put(
  HttpClient client,
  String baseUrl,
  String path,
  Map<String, dynamic> body, {
  Map<String, String>? headers,
}) async {
  final request = await client.putUrl(Uri.parse('$baseUrl$path'));
  request.headers.contentType = ContentType.json;
  (headers ?? const {}).forEach(request.headers.set);
  request.write(jsonEncode(body));
  final response = await request.close();
  return jsonDecode(await response.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _get(
  HttpClient client,
  String baseUrl,
  String path, {
  Map<String, String>? headers,
}) async {
  final request = await client.getUrl(Uri.parse('$baseUrl$path'));
  (headers ?? const {}).forEach(request.headers.set);
  final response = await request.close();
  return jsonDecode(await response.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _delete(
  HttpClient client,
  String baseUrl,
  String path, {
  Map<String, String>? headers,
}) async {
  final request = await client.deleteUrl(Uri.parse('$baseUrl$path'));
  (headers ?? const {}).forEach(request.headers.set);
  final response = await request.close();
  return jsonDecode(await response.transform(utf8.decoder).join())
      as Map<String, dynamic>;
}
