import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(
    () async => root = await Directory.systemTemp.createTemp('sdk_runtime_'),
  );
  tearDown(() async => root.delete(recursive: true));

  test('同一 runtime 并发 REST/MCP 请求的来源和设备信息独立', () async {
    final events = <DataChangeEvent>[];
    final backend = LocalPluginBackend(root.path, onEvent: events.add);
    final invoker = PluginInvoker();
    await Future.wait([
      for (var i = 0; i < 12; i++) backend.withRequestContext(
        () => invoker.invokeAction(backend, 'chat', 'create', {'id': 'c-$i'}),
        source: i.isEven ? 'rest' : 'mcp', sourceDeviceId: 'device-$i',
      ),
    ]);
    expect(events.length, 12);
    for (var i = 0; i < 12; i++) {
      final event = events.singleWhere((event) => event.entityId == 'c-$i');
      expect(event.source, i.isEven ? 'rest' : 'mcp');
      expect(event.sourceDeviceId, 'device-$i');
    }
    await invoker.invokeAction(backend, 'chat', 'create', {'id': 'outside'});
    expect(events.last.source, 'local');
    expect(events.last.sourceDeviceId, isNull);
  });

  test('独立 backend 实例按数据目录共享锁，100 个并发追加不丢消息', () async {
    final data = AboutmeData.local(root.path);
    await data.call('chat', 'create', {'id': 'channel', 'title': 'test'});
    final results = await Future.wait(
      List.generate(
        100,
        (index) => AboutmeData.local(root.path).call('chat', 'sendMessage', {
          'channelId': 'channel',
          'content': 'message-$index',
          'clientMutationId': 'mutation-$index',
        }),
      ),
    );
    expect(results.every((result) => result['success'] == true), isTrue);
    final messages =
        (await data.get('chat', 'getMessages', {
              'channelId': 'channel',
              'count': 200,
            }))['data']
            as Map;
    expect(messages['total'], 100);
    expect(
      (messages['data'] as List)
          .map((message) => message['content'])
          .toSet()
          .length,
      100,
    );
  });

  test('幂等结果持久化，新 backend 重放返回同一消息；换参数拒绝', () async {
    final data = AboutmeData.local(root.path);
    await data.call('chat', 'create', {'id': 'channel'});
    final command = {
      'channelId': 'channel',
      'content': 'once',
      'clientMutationId': 'one',
    };
    final first = await data.call('chat', 'sendMessage', command);
    final replay = await AboutmeData.local(
      root.path,
    ).call('chat', 'sendMessage', command);
    expect(replay, first);
    final conflict = await data.call('chat', 'sendMessage', {
      ...command,
      'content': 'different',
    });
    expect(conflict['code'], 'CONFLICT');
    expect(
      (await data.get('chat', 'getMessages', {
        'channelId': 'channel',
      }))['data']['total'],
      1,
    );
  });

  test('expectedVersion 冲突不写入、不发事件，元数据不混入实体', () async {
    final data = AboutmeData.local(root.path);
    final events = <DataChangeEvent>[];
    final sub = data.events.listen(events.add);
    final created = await data.call('chat', 'create', {
      'id': 'channel',
      'clientMutationId': 'create',
    });
    final changed = await data.call('chat', 'update', {
      'id': 'channel',
      'title': 'new',
      'expectedVersion': created['version'],
    });
    expect(changed['success'], isTrue);
    expect((changed['data'] as Map).containsKey('expectedVersion'), isFalse);
    final conflict = await data.call('chat', 'delete', {
      'id': 'channel',
      'expectedVersion': created['version'],
    });
    expect(conflict['code'], 'CONFLICT');
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 2);
    expect(events.map((event) => event.version), [1, 2]);
    await sub.cancel();
  });

  test('损坏 JSON 返回 CORRUPT_DATA，原始内容不被覆盖', () async {
    final folder = Directory('${root.path}/chat');
    await folder.create();
    final file = File('${folder.path}/channels.json');
    await file.writeAsString('{broken');
    final result = await AboutmeData.local(
      root.path,
    ).call('chat', 'create', {'id': 'new'});
    expect(result['code'], 'CORRUPT_DATA');
    expect(await file.readAsString(), '{broken');
    expect(await File('${folder.path}/channel/new.json').exists(), isFalse);
  });

  test('业务失败丢弃全部暂存写入', () async {
    final backend = LocalPluginBackend(root.path);
    final result = await backend.execute(
      pluginId: 'chat',
      action: 'failing',
      resource: 'channels',
      isQuery: false,
      params: {},
      operation: (transaction) async {
        await transaction.write('chat', 'channels.json', {
          'channels': ['never'],
        });
        return {'success': false, 'code': 'INVALID_PARAMS'};
      },
    );
    expect(result['success'], isFalse);
    expect(await backend.read('chat', 'channels.json'), isNull);
  });

  test('提交中断后，下一实例先恢复全部文件和幂等记录，再执行查询', () async {
    final files = <String, String>{};
    final events = <DataChangeEvent>[];
    final faulty = _MemoryPersistence(
      files,
      'memory-recovery',
      failAt: 'chat/messages/channel.json',
    );
    final backend = PersistentPluginBackend(faulty, onEvent: events.add);
    final result = await PluginInvoker().invoke(
      backend,
      'post',
      '/api/v1/plugins/chat/channels',
      body: {'id': 'channel', 'clientMutationId': 'create'},
    );
    expect(result['success'], isFalse);
    expect(files.containsKey('.sdk/pending.json'), isTrue);
    expect(events, isEmpty);
    final recovered = AboutmeData.withPersistence(
      _MemoryPersistence(files, 'memory-recovery'),
    );
    expect((await recovered.get('chat', 'getList'))['data']['total'], 1);
    expect(files.containsKey('.sdk/pending.json'), isFalse);
    expect(
      jsonDecode(files['chat/messages/channel.json']!)['messages'],
      isEmpty,
    );
    final replay = await recovered.call('chat', 'create', {
      'id': 'channel',
      'clientMutationId': 'create',
    });
    expect(replay['success'], isTrue);
    expect(replay['version'], 1);
  });

  test('拒绝路径穿越', () async {
    final data = AboutmeData.local(root.path);
    final result = await data.call('chat', 'create', {'id': '../escape'});
    expect(result['success'], isFalse);
    expect(await File('${root.path}/escape.json').exists(), isFalse);
  });
}

class _MemoryPersistence implements PluginPersistence {
  _MemoryPersistence(this.files, this.identity, {this.failAt});
  final Map<String, String> files;
  final String? failAt;
  @override
  final String identity;
  @override
  Future<String?> read(String path) async => files[path];
  @override
  Future<void> write(String path, String content) async {
    if (path == failAt) throw StateError('injected process interruption');
    files[path] = content;
  }

  @override
  Future<bool> remove(String path) async => files.remove(path) != null;
  @override
  Future<List<String>> keys(String prefix) async =>
      files.keys.where((key) => key.startsWith(prefix)).toList();
}
