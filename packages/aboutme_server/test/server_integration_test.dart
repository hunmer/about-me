import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme_server/src/config.dart';
import 'package:aboutme_server/src/server_builder.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_server_test');
    final config = ServerConfig(
      port: 0,
      dataDir: tempDir.path,
      jwtSecret: 'integration-test-secret',
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
  });

  tearDown(() async {
    await server.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// 注册用户并用 Bearer Token 签发 API Key，
  /// 返回 (userId, apiKey, token)。
  Future<(String, String, String)> provisionUser(String username) async {
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
      'username': username,
      'password': 'secret66',
      'device_id': 'test-device',
      'device_name': 'Test',
    });
    expect(registered['success'], isTrue,
        reason: '注册失败: $registered');
    final token = registered['token'] as String;

    final apiKeyResponse = await post(
      '/api/v1/auth/api-keys',
      {'name': 'integration', 'expiry': 'never'},
      bearer: token,
    );
    expect(apiKeyResponse['success'], isTrue,
        reason: 'API Key 创建失败: $apiKeyResponse');
    client.close();
    return (
      registered['user_id'] as String,
      (apiKeyResponse['api_key'] as Map<String, dynamic>)['key'] as String,
      token,
    );
  }

  HttpStorage httpStorageOf(String apiKey, {String? deviceId}) => HttpStorage(
    serverUrl: baseUrl,
    authType: StorageAuthType.apiKey,
    credential: apiKey,
    deviceId: deviceId,
  );

  test('健康检查 / 存储健康', () async {
    final client = HttpClient();
    final health = await client.getUrl(Uri.parse('$baseUrl/health'));
    final healthResponse = await health.close();
    expect(healthResponse.statusCode, 200);
    client.close();

    final (_, apiKey, __) = await provisionUser('health-user');
    final storage = httpStorageOf(apiKey);
    await storage.testConnection();
  });

  test('未认证请求被拒绝', () async {
    final storage = HttpStorage(
      serverUrl: baseUrl,
      authType: StorageAuthType.apiKey,
      credential: 'mk_invalid_key',
    );
    await expectLater(
      storage.testConnection(),
      throwsA(
        isA<StorageException>().having(
          (e) => e.kind,
          'kind',
          StorageErrorKind.unauthorized,
        ),
      ),
    );
  });

  test('SDK HttpStorage 全链路：写入加密→读取解密→列表→删除', () async {
    final (_, apiKey, __) = await provisionUser('storage-user');
    final storage = httpStorageOf(apiKey);

    await storage.writeString('misc/list.json', jsonEncode({'items': [1, 2]}));
    expect(
      await storage.readString('misc/list.json'),
      jsonEncode({'items': [1, 2]}),
    );
    await storage.writeBytes(
      'images/a.bin',
      Uint8List.fromList([1, 2, 3]),
    );
    expect(await storage.readBytes('images/a.bin'), [1, 2, 3]);

    final keys = await storage.getKeysWithPrefix('misc/');
    expect(keys, contains('misc/list.json'));

    expect(await storage.hasData('misc/list.json'), isTrue);
    await storage.deleteFile('misc/list.json');
    expect(await storage.hasData('misc/list.json'), isFalse);
    expect(await storage.readBytes('misc/list.json'), isNull);
  });

  test('服务器落盘为明文（统一数据区 = 用户根目录）', () async {
    final (userId, apiKey, __) = await provisionUser('e2e-user');
    final storage = httpStorageOf(apiKey);
    await storage.writeString('secret.json', 'plain-text-data');

    // 统一数据区：storage files API 直接写入用户根目录（无 .storage 前缀）
    final raw = File('${tempDir.path}/users/$userId/secret.json');
    expect(await raw.exists(), isTrue);
    final content = await raw.readAsString();
    expect(content, 'plain-text-data');

    // storage API 写入的文件直接落在用户根目录（未封闭前缀）
    await storage.writeString('misc/tasks.json', '{"tasks":[{"id":"t1"}]}');
    expect(
      await File('${tempDir.path}/users/$userId/misc/tasks.json').exists(),
      isTrue,
    );
  });

  test('ETag 条件写：服务端返回 412 与冲突元数据', () async {
    final (_, apiKey, __) = await provisionUser('etag-user');
    final client = HttpClient();
    final uri = Uri.parse('$baseUrl/api/v1/storage/files/conflict.json');
    final baseHeaders = <String, String>{
      'X-API-Key': apiKey,
      'Content-Type': 'application/octet-stream',
    };

    Future<HttpClientResponse> put(Map<String, String> h) async {
      final request = await client.putUrl(uri);
      h.forEach(request.headers.set);
      request.add([9, 9, 9]);
      return request.close();
    }

    final first = await put({...baseHeaders, 'X-Force-Overwrite': 'true'});
    expect(first.statusCode, 200);
    final etag = first.headers.value('etag');
    expect(etag, isNotNull);
    await first.drain();

    // 版本一致的条件写成功
    final ok = await put({...baseHeaders, 'If-Match': etag!});
    expect(ok.statusCode, 200);
    await ok.drain();

    // 错误 etag 条件写 → 412，并带回报务器当前 ETag
    final conflict = await put({...baseHeaders, 'If-Match': '"stale"'});
    expect(conflict.statusCode, 412);
    expect(conflict.headers.value('etag'), etag);
    await conflict.drain();
    client.close();
  });

  test('WebSocket：设备 B 收到设备 A 写入的 file_updated 广播', () async {
    final (_, apiKey, __) = await provisionUser('ws-user');

    final wsUri = Uri.parse(baseUrl.replaceFirst('http', 'ws'))
        .replace(path: '/api/v1/storage/ws');

    Future<(WebSocketChannel, Stream)> connectWs(String deviceId) async {
      final channel = WebSocketChannel.connect(wsUri);
      await channel.ready;
      // 转广播流：取 auth_success 后仍可持续监听，且保持连接存活
      final messages = channel.stream.asBroadcastStream();
      final authFuture = messages
          .firstWhere((m) => jsonDecode(m as String)['type'] == 'auth_success')
          .timeout(const Duration(seconds: 5));
      channel.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': apiKey,
          'device_id': deviceId,
        }),
      );
      await authFuture;
      return (channel, messages);
    }

    final (deviceA, streamA) = await connectWs('device-a');
    // deviceA 保持监听（空处理）避免连接被取消订阅关闭
    final subA = streamA.listen((_) {});
    final (deviceB, streamB) = await connectWs('device-b');

    final received = Completer<Map<String, dynamic>>();
    final subB = streamB.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['type'] == 'file_updated' && !received.isCompleted) {
        received.complete(message['data'] as Map<String, dynamic>);
      }
    });

    final storage = httpStorageOf(apiKey, deviceId: 'device-a');
    await storage.writeString('sync/note.json', 'hello-sync');

    final data = await received.future.timeout(const Duration(seconds: 5));
    expect(data['file_path'], 'sync/note.json');
    expect(data['source_device_id'], 'device-a');

    await subA.cancel();
    await subB.cancel();
    await deviceA.sink.close();
    await deviceB.sink.close();
  });

  test('登录与 user-info / 设备列表', () async {
    final client = HttpClient();

    final login = await client.postUrl(
      Uri.parse('$baseUrl/api/v1/auth/login'),
    );
    login.headers.contentType = ContentType.json;
    login.write(jsonEncode({
      'username': 'admin',
      'password': 'admin123',
      'device_id': 'admin_panel',
    }));
    final loginResponse = await login.close();
    final loginBody =
        jsonDecode(await loginResponse.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    expect(loginBody['success'], isTrue);
    final token = loginBody['token'] as String;

    final userInfo = await client.getUrl(
      Uri.parse('$baseUrl/api/v1/auth/user-info'),
    );
    userInfo.headers.set('Authorization', 'Bearer $token');
    final userInfoResponse = await userInfo.close();
    final userInfoBody =
        jsonDecode(await userInfoResponse.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    expect(userInfoBody['success'], isTrue);
    expect(userInfoBody['user_info']['username'], 'admin');
    client.close();
  });
}
