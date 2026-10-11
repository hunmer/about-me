import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme_server/src/config.dart';
import 'package:aboutme_server/src/server_builder.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';

/// 客户端形态端到端：AboutmeData.remote（SDK facade）连接真实服务器，
/// 文件层 + 业务层 + 事件转发 + MCP 同数据 全链路验证。
void main() {
  late Directory tempDir;
  late HttpServer server;
  late String apiKey;
  late String baseUrl;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_remote_test');
    final config = ServerConfig(
      port: 0,
      dataDir: tempDir.path,
      jwtSecret: 'facade-test',
      tokenExpiryDays: 30,
      enableCors: false,
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

    // 注册并签发 API Key
    final client = HttpClient();
    Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body, {
      String? bearer,
    }) async {
      final request = await client.postUrl(Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (bearer != null) {
        request.headers.set('Authorization', 'Bearer $bearer');
      }
      request.write(jsonEncode(body));
      final response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    }

    final registered = await post('/api/v1/auth/register', {
      'username': 'facade-user',
      'password': 'secret66',
      'device_id': 'd1',
    });
    final keyResponse = await post(
      '/api/v1/auth/api-keys',
      {'name': 'test', 'expiry': 'never'},
      bearer: registered['token'] as String,
    );
    apiKey = ((keyResponse['api_key'] as Map)['key']) as String;
    client.close();
  });

  tearDown(() async {
    await server.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('远程模式：文件层与业务层操作同一份数据', () async {
    final data = AboutmeData.remote(
      serverUrl: baseUrl,
      apiKey: apiKey,
      deviceId: 'device-x',
    );
    expect(await data.testConnection(), isTrue);

    // 业务层创建任务（与 REST/MCP 同一处理器）
    final created = await data.call('todo', 'create', {'title': 'facade 任务'});
    expect(created['success'], isTrue, reason: '$created');

    // 文件层读到的就是业务层写的结果（同一数据区）
    final file = await data.readFile('todo', 'tasks.json');
    expect(file, isA<Map>());
    expect((file as Map)['tasks'].length, 1);

    // 业务层统计
    final stats = await data.get('todo', 'getStats');
    expect((stats['data'] as Map)['total'], 1);

    // 未知动作给出明确错误
    final unknown = await data.call('todo', 'nonexistent');
    expect(unknown['success'], isFalse);
  });

  test('远程模式：服务端落盘明文（无加密）', () async {
    final data = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    await data.writeFile('todo', 'tasks.json', {
      'tasks': [
        {'id': 'plain', 'title': '明文任务'},
      ],
    });

    final usersDir = Directory('${tempDir.path}/users');
    final dataFile = usersDir
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('todo/tasks.json'));
    expect(await dataFile.readAsString(), contains('明文任务'));
  });

  test('远程模式：publishRemoteEvent 转发进本地事件流', () async {
    final data = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    final events = <DataChangeEvent>[];
    final sub = data.events.listen(events.add);

    // 模拟 WS 收到 MCP 写 todo 的广播后转发
    data.publishRemoteEvent(
      const DataChangeEvent(
        pluginId: 'todo',
        filePattern: 'todo/tasks.json',
        source: 'mcp',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.single.source, 'mcp');
    await sub.cancel();
  });
}
