import 'dart:convert';
import 'dart:io';

import 'package:aboutme_server/src/config.dart';
import 'package:aboutme_server/src/server_builder.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

/// System 域 SDK 化：顶层旧配置文件在启动时搬入 system/ 分区，
/// 管理路由经 SDK 命令读写。
void main() {
  late Directory tempDir;
  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_system_test');
    // 模拟老部署：dataDir 顶层的注册表/商店配置
    await File('${tempDir.path}/plugin_registry.json').writeAsString(
      jsonEncode({
        'plugins': {
          'diary': {'version': '1.0.0', 'enabled': true},
        },
        'updatedAt': '2026-10-01',
      }),
    );
    await File('${tempDir.path}/store_config.json').writeAsString(
      jsonEncode({'storeURL': 'https://old.example.com', 'lastSyncAt': ''}),
    );

    final config = ServerConfig(
      port: 0,
      dataDir: tempDir.path,
      jwtSecret: 'system-test-secret',
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
    server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    await server.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> adminLogin(HttpClient client) async {
    final login = await client.postUrl(
      Uri.parse('$baseUrl/api/v1/auth/login'),
    );
    login.headers.contentType = ContentType.json;
    login.write(jsonEncode({
      'username': 'admin',
      'password': 'admin123',
      'device_id': 'admin_panel',
    }));
    final response = await login.close();
    final body =
        jsonDecode(await response.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    return body['token'] as String;
  }

  Future<Map<String, dynamic>> request(
    HttpClient client, {
    required String method,
    required String path,
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final r = await client.openUrl(method, Uri.parse('$baseUrl$path'));
    if (token != null) r.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      r.headers.contentType = ContentType.json;
      r.write(jsonEncode(body));
    }
    final response = await r.close();
    return jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  }

  test('顶层旧配置搬入 system/ 分区并经 SDK 读写', () async {
    // 启动搬家后顶层旧文件消失、分区文件存在
    expect(
      await File('${tempDir.path}/plugin_registry.json').exists(),
      isFalse,
    );
    expect(
      await File(
        '${tempDir.path}/system/plugin_registry.json',
      ).exists(),
      isTrue,
    );

    final client = HttpClient();
    final token = await adminLogin(client);

    // 注册表读到旧内容
    final plugins = await request(
      client,
      method: 'GET',
      path: '/api/v1/system/plugins',
      token: token,
    );
    expect(plugins['success'], isTrue);
    expect(plugins['total'], 1);
    expect(plugins['plugins'].first['version'], '1.0.0');

    // 商店配置读到旧值
    final config = await request(
      client,
      method: 'GET',
      path: '/api/v1/system/plugins/config',
      token: token,
    );
    expect(config['success'], isTrue);
    expect(config['config']['storeURL'], 'https://old.example.com');

    // PUT 合并更新（SDK 命令）
    final updated = await request(
      client,
      method: 'PUT',
      path: '/api/v1/system/plugins/config',
      token: token,
      body: {'storeURL': 'https://new.example.com'},
    );
    expect(updated['success'], isTrue);
    expect(updated['config']['storeURL'], 'https://new.example.com');
    // 未传入的键保留
    expect(updated['config']['lastSyncAt'], '');

    final reread = await request(
      client,
      method: 'GET',
      path: '/api/v1/system/plugins/config',
      token: token,
    );
    expect(reread['config']['storeURL'], 'https://new.example.com');

    client.close();
  });
}
