import 'dart:async';
import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

/// AboutmeData 统一数据入口：本地模式全链路（文件层 + 业务层 + 事件）。
void main() {
  late Directory tempDir;
  late AboutmeData data;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_data_test');
    data = AboutmeData.local(tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('文件层：readFile/writeFile/deleteFile 明文 JSON', () async {
    expect(await data.readFile('todo', 'tasks.json'), isNull);

    await data.writeFile('todo', 'tasks.json', {
      'tasks': [
        {'id': 't1', 'title': '本地任务'},
      ],
      'viewMode': 'ViewMode.quadrant',
    });
    expect(
      await data.readFile('todo', 'tasks.json'),
      {
        'tasks': [
          {'id': 't1', 'title': '本地任务'},
        ],
        'viewMode': 'ViewMode.quadrant',
      },
    );

    // 落盘明文
    final raw = await File(
      '${tempDir.path}/todo/tasks.json',
    ).readAsString();
    expect(raw, contains('本地任务'));

    expect(await data.deleteFile('todo', 'tasks.json'), isTrue);
    expect(await data.readFile('todo', 'tasks.json'), isNull);
  });

  test('业务层：与 REST/MCP 同一套处理器（本地直调）', () async {
    final created = await data.call('todo', 'create', {'title': 'SDK 创建'});
    expect(created['success'], isTrue, reason: '$created');
    final task = created['data'] as Map<String, dynamic>;
    expect(task['id'], isNotNull);

    final stats = await data.get('todo', 'getStats');
    expect(stats['success'], isTrue);
    expect((stats['data'] as Map)['total'], 1);

    final completed = await data.call('todo', 'completeTask', {
      'id': task['id'],
    });
    expect(completed['success'], isTrue);
    expect((completed['data'] as Map)['completed'], isTrue);
  });

  test('业务层保留文件级额外字段（与客户端整文件写共存）', () async {
    await data.writeFile('todo', 'tasks.json', {
      'tasks': <dynamic>[],
      'completedTasks': [
        {'id': 'old'},
      ],
      'viewMode': 'ViewMode.list',
    });

    await data.call('todo', 'create', {'title': '新增'});
    final file = await data.readFile('todo', 'tasks.json') as Map;
    expect(file.containsKey('viewMode'), isTrue);
    expect((file['completedTasks'] as List).length, 1);
    expect((file['tasks'] as List).length, 1);
  });

  test('事件流：本地写操作广播 DataChangeEvent', () async {
    final events = <DataChangeEvent>[];
    final sub = data.events.listen(events.add);

    await data.call('chat', 'create', {'name': '事件频道'});
    await data.writeFile('todo', 'tasks.json', {'tasks': []});

    await Future<void>.delayed(Duration.zero);
    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.any((e) => e.pluginId == 'chat'), isTrue);
    expect(events.any((e) => e.pluginId == 'todo'), isTrue);
    expect(events.first.source, 'local');
    await sub.cancel();
  });

  test('publishRemoteEvent：远端变更可转发进本地事件流', () async {
    final received = <DataChangeEvent>[];
    final sub = data.events.listen(received.add);

    data.publishRemoteEvent(
      const DataChangeEvent(
        pluginId: 'todo',
        filePattern: 'tasks.json',
        source: 'mcp',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(received.single.source, 'mcp');
    await sub.cancel();
  });

  test('本地模式 testConnection 恒真', () async {
    expect(await data.testConnection(), isTrue);
  });

  test('全路径读写：与 StorageManager 语义对齐（默认值/文本/存在/列举/清除）', () async {
    // readPath 不存在 → 缺省 {}（与 StorageManager.read 历史语义一致）
    expect(await data.readPath('notes/x.json'), <String, dynamic>{});
    expect(await data.readPath('notes/x.json', {'d': 1}), {'d': 1});

    // JSON 写读
    await data.writePath('notes/x.json', {'k': 'v'});
    expect(await data.readPath('notes/x.json'), {'k': 'v'});

    // 文本写读
    await data.writePath('scripts/a.js', 'console.log(1)');
    expect(await data.readPathText('scripts/a.js'), 'console.log(1)');

    // 存在/列举/删除/清除
    expect(await data.existsPath('notes/x.json'), isTrue);
    final keys = await data.listPathKeys('notes/');
    expect(keys, contains('notes/x.json'));
    expect(await data.deletePath('notes/x.json'), isTrue);
    expect(await data.existsPath('notes/x.json'), isFalse);

    await data.writePath('tmp/1.json', {});
    await data.writePath('tmp/2.json', {});
    await data.clearPathPrefix('tmp/');
    expect(await data.listPathKeys('tmp/'), isEmpty);

    // 全路径写也触发事件（pluginId = 首段）
    final events = <DataChangeEvent>[];
    final sub = data.events.listen(events.add);
    await data.writePath('goods/items.json', {'items': []});
    await Future<void>.delayed(Duration.zero);
    expect(events.any((e) => e.pluginId == 'goods'), isTrue);
    await sub.cancel();
  });
}
