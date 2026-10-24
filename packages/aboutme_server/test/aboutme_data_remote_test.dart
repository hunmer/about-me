import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    final keyResponse = await post('/api/v1/auth/api-keys', {
      'name': 'test',
      'expiry': 'never',
    }, bearer: registered['token'] as String);
    apiKey = ((keyResponse['api_key'] as Map)['key']) as String;
    client.close();
  });

  tearDown(() async {
    await server.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('资源的 local/HTTP/REST/MCP 共用内容、引用和旧写保护', () async {
    final remote = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(remote.dispose);
    final bytes = Uint8List.fromList([0, 128, 255, 1]);
    final asset = await remote.assets.upload(bytes, fileName: '贴图.gif', mediaType: 'image/gif',
      clientMutationId: 'asset-once');
    final replay = await remote.assets.upload(bytes, fileName: '贴图.gif', mediaType: 'image/gif',
      clientMutationId: 'asset-once');
    expect(replay.id, asset.id);
    expect(await remote.assets.read(asset.id), bytes);
    final client = HttpClient(); addTearDown(client.close);
    final rest = await client.getUrl(Uri.parse('$baseUrl/api/v1/plugins/assets/${asset.id}/metadata'));
    rest.headers.set('X-API-Key', apiKey);
    final response = await rest.close();
    expect(response.statusCode, 200);
    final metadata = jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    expect(metadata['data'], asset.toJson());
    final mcp = await client.postUrl(Uri.parse('$baseUrl/mcp'));
    mcp.headers.set('X-API-Key', apiKey); mcp.headers.contentType = ContentType.json;
    mcp.write(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call', 'params': {
      'name': 'aboutme_data_call', 'arguments': {'pluginId': 'chat', 'action': 'createStickerCollection',
        'params': {'id': 'stickers-one', 'name': 'MCP collection', 'stickerPaths': [asset.reference]}},
    }}));
    final mcpResponse = await mcp.close();
    final rpc = jsonDecode(await mcpResponse.transform(utf8.decoder).join()) as Map;
    final committed = jsonDecode(rpc['result']['content'][0]['text'] as String) as Map;
    expect(committed['success'], isTrue, reason: '$committed');
    expect((await remote.call('assets', 'remove', {'id': asset.id}))['code'], 'CONFLICT');
    expect((await remote.get('chat', 'getStickerCollections'))['data'][0]['stickerPaths'], [asset.reference]);
    final userDir = (await Directory('${tempDir.path}/users').list().where((entity) => entity is Directory).first).path;
    final local = AboutmeData.local(userDir); addTearDown(local.dispose);
    expect(await local.assets.read(asset.id), bytes);
    for (final path in ['assets/${asset.id}.json', 'stickers/collections.json']) {
      final put = await client.putUrl(Uri.parse('$baseUrl/api/v1/storage/files/$path'));
      put.headers.set('X-API-Key', apiKey); put.headers.set('X-Force-Overwrite', 'true'); put.write('{}');
      final denied = await put.close(); expect(denied.statusCode, 426); await denied.drain<void>();
    }
    expect((await remote.call('chat', 'deleteStickerCollection', {'id': 'stickers-one'}))['success'], isTrue);
    expect(await remote.assets.remove(asset.id), isTrue);
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
    await data.writeFile('misc', 'tasks.json', {
      'tasks': [
        {'id': 'plain', 'title': '明文任务'},
      ],
    });

    final usersDir = Directory('${tempDir.path}/users');
    final dataFile = usersDir
        .listSync(recursive: true)
        .whereType<File>()
        .firstWhere(
          (f) => f.path.replaceAll('\\', '/').endsWith('misc/tasks.json'),
        );
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

  test('真实路由：SDK GET/POST/PUT/PATCH/DELETE、null 和字符串 ID', () async {
    final data = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(data.dispose);
    final created = await data.call('chat', 'create', {
      'id': '001',
      'title': 'old',
      'description': 'text',
    });
    expect(created['success'], isTrue);
    expect(
      (await data.get('chat', 'getById', {'id': '001'}))['data']['id'],
      '001',
    );
    final updated = await data.call('chat', 'update', {
      'id': '001',
      'title': 'new',
    });
    expect(updated['data']['title'], 'new');
    final patched = await data.call('chat', 'patch', {
      'id': '001',
      'description': null,
    });
    expect(patched['data']['description'], isNull);
    expect(patched['data']['title'], 'new');
    final found = await data.get('chat', 'findChannel', {
      'field': 'id',
      'value': '001',
      'fuzzy': false,
    });
    expect(found['data']['total'], 1);
    final deleted = await data.call('chat', 'delete', {
      'id': '001',
      'expectedVersion': patched['version'],
    });
    expect(deleted['success'], isTrue);
    expect(
      (await data.get('chat', 'getById', {'id': '001'}))['code'],
      'NOT_FOUND',
    );
  });

  test('显式 open 返回 HTTP 状态、认证用户和能力，MCP 使用同一动作表', () async {
    final data = await AboutmeData.open(
      DataConfig.http(
        serverUrl: baseUrl,
        credentialProvider: () async => apiKey,
      ),
    );
    addTearDown(data.dispose);
    expect(data.session.mode, DataMode.http);
    expect(data.session.connection, DataConnection.ready);
    expect(data.session.userId, isNotEmpty);
    expect(data.session.capabilities['protocolVersion'], 1);
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.postUrl(Uri.parse('$baseUrl/mcp'));
    request.headers.set('X-API-Key', apiKey);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {
          'name': 'aboutme_data_call',
          'arguments': {
            'pluginId': 'chat',
            'action': 'create',
            'params': {'id': 'generic-tool', 'title': 'Generic'},
          },
        },
      }),
    );
    final response = await request.close();
    final json =
        jsonDecode(await response.transform(utf8.decoder).join()) as Map;
    expect(json['result']['isError'], isNot(true));
    final created =
        jsonDecode(json['result']['content'][0]['text'] as String) as Map;
    expect(created['success'], isTrue);
    expect(created['version'], isA<int>());
    expect(
      (await data.get('chat', 'getById', {'id': 'generic-tool'}))['data'],
      created['data'],
    );
  });

  test('两个 SDK HTTP 客户端与 MCP 并发追加共享事务与幂等记录', () async {
    final first = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    final second = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await first.call('chat', 'create', {'id': 'shared', 'title': 'Shared'});
    final client = HttpClient();
    addTearDown(client.close);
    Future<Map<String, dynamic>> mcpSend(int index) async {
      final request = await client.postUrl(Uri.parse('$baseUrl/mcp'));
      request.headers.contentType = ContentType.json;
      request.headers.set('X-API-Key', apiKey);
      request.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': index,
          'method': 'tools/call',
          'params': {
            'name': 'aboutme_chat_sendMessage',
            'arguments': {
              'channelId': 'shared',
              'content': 'mcp-$index',
              'clientMutationId': 'mcp-$index',
            },
          },
        }),
      );
      final response = await request.close();
      return jsonDecode(await response.transform(utf8.decoder).join())
          as Map<String, dynamic>;
    }

    final results = await Future.wait([
      for (var index = 0; index < 10; index++) ...[
        first.call('chat', 'sendMessage', {
          'channelId': 'shared',
          'content': 'first-$index',
          'clientMutationId': 'first-$index',
        }),
        second.call('chat', 'sendMessage', {
          'channelId': 'shared',
          'content': 'second-$index',
          'clientMutationId': 'second-$index',
        }),
        mcpSend(index),
      ],
    ]);
    expect(
      results
          .where((result) => result.containsKey('success'))
          .every((result) => result['success'] == true),
      isTrue,
      reason: '${results.where((r) => r['success'] != true && r.containsKey('success'))}',
    );
    expect(
      results
          .where((result) => result.containsKey('jsonrpc'))
          .every((result) => result['result']['isError'] != true),
      isTrue,
    );
    final messages = (await first.get('chat', 'getMessages', {
      'channelId': 'shared',
    }))['data'];
    expect(messages['total'], 30);
    expect(
      (messages['data'] as List)
          .map((message) => message['content'])
          .toSet()
          .length,
      30,
    );
    final replay = await second.call('chat', 'sendMessage', {
      'channelId': 'shared',
      'content': 'first-0',
      'clientMutationId': 'first-0',
    });
    expect(replay['success'], isTrue);
    expect(
      (await first.get('chat', 'getMessages', {
        'channelId': 'shared',
      }))['data']['total'],
      30,
    );
    // 同一用户目录的本地 SDK 读取与 HTTP/REST/MCP 一致。
    final userDir = (await Directory(
      '${tempDir.path}/users',
    ).list().where((entity) => entity is Directory).first).path;
    final local = AboutmeData.local(userDir);
    addTearDown(local.dispose);
    expect(
      (await local.get('chat', 'getMessages', {'channelId': 'shared'}))['data'],
      messages,
    );
  });

  test('真实路由拒绝 body 覆盖路径身份与无效分页', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.openUrl(
      'PUT',
      Uri.parse('$baseUrl/api/v1/plugins/chat/channels/001'),
    );
    request.headers.set('X-API-Key', apiKey);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'id': 'other', 'title': 'bad'}));
    final response = await request.close();
    expect(response.statusCode, 400);
    await response.drain<void>();
    final query = await client.getUrl(
      Uri.parse('$baseUrl/api/v1/plugins/chat/channels?offset=-1'),
    );
    query.headers.set('X-API-Key', apiKey);
    final queried = await query.close();
    expect(queried.statusCode, 400);
    await queried.drain<void>();
  });
  test('Diary 的 local/HTTP/REST/MCP 契约一致，缺失读取和冲突均保留版本', () async {
    final remote = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(remote.dispose);
    final absent = await remote.get('diary', 'getByDate', {'date': '2026-01-01'});
    expect(absent['code'], 'NOT_FOUND');
    expect(absent['version'], 0);
    final created = await remote.call('diary', 'save', {
      'date': '2026-01-01', 'content': '[{"insert":"正文\\n"}]', 'title': 'old',
      'tags': ['tag'], 'extension': {'x': 1}, 'expectedVersion': absent['version'],
    });
    expect(created['success'], isTrue, reason: '$created');
    final client = HttpClient(); addTearDown(client.close);
    final mcp = await client.postUrl(Uri.parse('$baseUrl/mcp'));
    mcp.headers.set('X-API-Key', apiKey); mcp.headers.contentType = ContentType.json;
    mcp.write(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call', 'params': {
      'name': 'aboutme_data_call', 'arguments': {'pluginId': 'diary', 'action': 'updateByDate', 'params': {
        'date': '2026-01-01', 'title': 'MCP title', 'mood': null, 'expectedVersion': created['version'],
      }},
    }}));
    final mcpResponse = await mcp.close();
    final mcpBody = jsonDecode(await mcpResponse.transform(utf8.decoder).join()) as Map;
    final committed = jsonDecode(mcpBody['result']['content'][0]['text'] as String) as Map;
    expect(committed['success'], isTrue, reason: '$committed');
    final stale = await remote.call('diary', 'save', {'date': '2026-01-01', 'content': 'stale', 'expectedVersion': created['version']});
    expect(stale['code'], 'CONFLICT'); expect(stale['version'], committed['version']);
    final rest = await client.getUrl(Uri.parse('$baseUrl/api/v1/plugins/diary/entries/2026-01-01'));
    rest.headers.set('X-API-Key', apiKey);
    final restResponse = await rest.close();
    expect(restResponse.statusCode, 200);
    final restBody = jsonDecode(await restResponse.transform(utf8.decoder).join()) as Map;
    final userDir = (await Directory('${tempDir.path}/users').list().where((entity) => entity is Directory).first).path;
    final local = AboutmeData.local(userDir); addTearDown(local.dispose);
    expect((await local.get('diary', 'getByDate', {'date': '2026-01-01'}))['data'], restBody['data']);
    expect((await remote.get('diary', 'getByDate', {'date': '2026-01-01'}))['data'], restBody['data']);
    expect(restBody['data']['title'], 'MCP title'); expect(restBody['data']['tags'], ['tag']);
    expect(restBody['data']['extension'], {'x': 1});
    expect((await remote.get('diary', 'getStats'))['data']['totalWords'], 2);
  });

  test('Diary 旧文件 PUT/DELETE/前缀 clear 被拒绝，业务导入导出可用', () async {
    final remote = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(remote.dispose);
    final imported = await remote.call('diary', 'importEntries', {
      'schemaVersion': 1, 'entries': [{'date': '2026-01-01', 'content': 'keep', 'extension': true}],
    });
    expect(imported['success'], true, reason: '$imported');
    expect((await remote.get('diary', 'getMigrationReport'))['data']['verified'], true);
    final client = HttpClient(); addTearDown(client.close);
    for (final request in <(String, String)>[
      ('PUT', '/api/v1/storage/files/diary/2026-01-01.json'),
      ('PUT', '/api/v1/storage/files/DIARY/2026-01-01.json'),
      ('PUT', '/api/v1/storage/files/.SDK/state.json'),
      ('DELETE', '/api/v1/storage/files/diary/2026-01-01.json'),
      ('DELETE', '/api/v1/storage/files?prefix=d'),
      ('DELETE', '/api/v1/storage/files?prefix=diary/'),
      ('DELETE', '/api/v1/storage/files?prefix='),
      ('PUT', '/api/v1/storage/files/sdk_migrations/diary/v1.json'),
    ]) {
      final req = await client.openUrl(request.$1, Uri.parse('$baseUrl${request.$2}'));
      req.headers.set('X-API-Key', apiKey);
      req.headers.set('X-Force-Overwrite', 'true');
      if (request.$1 == 'PUT') { req.headers.contentType = ContentType.binary; req.write('{}'); }
      final response = await req.close();
      expect(response.statusCode, 426, reason: '${request.$1} ${request.$2}');
      expect(jsonDecode(await response.transform(utf8.decoder).join())['code'], 'UPGRADE_REQUIRED');
    }
    expect((await remote.diary.getEntry('2026-01-01')).entry!.content, 'keep');
    final page = await remote.diary.listEntries(); expect(page.total, 1);
    expect(page.data.single.toJson()['extension'], true);
    expect((await remote.get('diary', 'exportEntries'))['data']['entries'][0]['content'], 'keep');
  });

  test('system config 命令远端链路：斜杠 key、写删与 configs 封闭', () async {
    final remote = AboutmeData.remote(serverUrl: baseUrl, apiKey: apiKey);
    addTearDown(remote.dispose);

    // GET 走 query（json-v1 编码）：多段 key（bill/settings.json）与顶层键
    final missing = await remote.get(
      'system', 'getConfig', {'key': 'bill/settings.json'});
    expect(missing['success'], true, reason: '$missing');
    expect(missing['data']['value'], isNull);

    // PUT 走 body：对象/字符串值写读闭环
    final saved = await remote.get('system', 'setConfig', {
      'key': 'bill/settings.json',
      'value': {'currency': 'CNY'},
    });
    expect(saved['success'], true, reason: '$saved');
    final read = await remote.get(
      'system', 'getConfig', {'key': 'bill/settings.json'});
    expect(read['data']['value']['currency'], 'CNY');

    final savedId = await remote.get('system', 'setConfig', {
      'key': 'webview_app_source_current.json',
      'value': 'uuid-1',
    });
    expect(savedId['success'], true, reason: '$savedId');
    final readId = await remote.get(
      'system', 'getConfig', {'key': 'webview_app_source_current.json'});
    expect(readId['data']['value'], 'uuid-1');

    // 落盘 configs/ 前缀原位（server 按认证用户隔离在 users/<id>/ 下）
    final userFiles = Directory('${tempDir.path}/users')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .toList();
    expect(
      userFiles.any((p) => p.endsWith('/configs/bill/settings.json')),
      true,
      reason: '$userFiles',
    );

    // DELETE 走 body
    final removed = await remote.get(
      'system', 'deleteConfig', {'key': 'bill/settings.json'});
    expect(removed['data']['deleted'], true);

    // configs 原始文件写被封闭（426）
    final client = HttpClient(); addTearDown(client.close);
    final req = await client.putUrl(
      Uri.parse('$baseUrl/api/v1/storage/files/configs/app_config.json'));
    req.headers.set('X-API-Key', apiKey);
    req.headers.set('X-Force-Overwrite', 'true');
    req.headers.contentType = ContentType.binary;
    req.write('{}');
    final response = await req.close();
    expect(response.statusCode, 426);
    expect(
      jsonDecode(await response.transform(utf8.decoder).join())['code'],
      'UPGRADE_REQUIRED',
    );

    // capabilities 对外声明保护前缀
    final capsReq = await client.getUrl(
      Uri.parse('$baseUrl/api/v1/plugins/capabilities'));
    capsReq.headers.set('X-API-Key', apiKey);
    final caps = jsonDecode(
      await (await capsReq.close()).transform(utf8.decoder).join())
      as Map<String, dynamic>;
    expect((caps['protectedPrefixes'] as List).contains('configs'), true);
  });
}
