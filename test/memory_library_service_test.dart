import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform originalPaths;
  final store = AlivenessStore.instance;
  final memory = MemoryService.instance;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('memory_libraries_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(root.path);
    globalStorage = StorageManager();
    await AboutmeDataService.instance.initialize();
  });

  tearDownAll(() async {
    await AboutmeDataService.instance.data.dispose();
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  test('批量按非空key查询，去重保序并报告未命中key', () async {
    final library = await store.createMemoryLibrary('批量查询');
    await memory.upsertForTool(library.id, 'user.name', '小明', []);
    await memory.upsertForTool(library.id, 'user.age', '20', []);
    await memory.upsertForTool(library.id, 'user.archived', '旧值', []);
    final fragments = await memory.loadFragments(library.id);
    fragments
            .firstWhere((fragment) => fragment.key == 'user.archived')
            .archived =
        true;
    await memory.saveFragments(library.id, fragments);

    final result = await memory.searchKeysForTool(library.id, [
      'user.age',
      'user.name',
      'user.age',
      'missing.key',
      'user.archived',
    ]);
    expect((result['fragments'] as List).map((item) => item['key']), [
      'user.age',
      'user.name',
      'user.archived',
    ]);
    expect(result['missingKeys'], ['missing.key']);
    expect((result['fragments'] as List).last['value'], '旧值');
    await expectLater(
      memory.searchKeysForTool(library.id, []),
      throwsArgumentError,
    );
    await expectLater(
      memory.searchKeysForTool(library.id, ['user.name', '  ']),
      throwsArgumentError,
    );
    await expectLater(
      memory.searchKeysForTool(library.id, ['user.name', 42]),
      throwsArgumentError,
    );
  });

  test('单条查询要求非空完整key', () async {
    final library = await store.createMemoryLibrary('单条查询');
    await expectLater(
      memory.searchKeysForTool(library.id, [null]),
      throwsArgumentError,
    );
    await expectLater(
      memory.searchKeysForTool(library.id, ['  ']),
      throwsArgumentError,
    );
  });

  test('逐层枚举key，按层级边界匹配且不返回value', () async {
    final library = await store.createMemoryLibrary('层级枚举');
    await memory.saveFragments(library.id, [
      for (final key in [
        'user.name',
        'user.age',
        'user.preference.drink',
        'user.preference.food',
        'event.interview.date',
        'username',
        'single',
      ])
        MemoryFragment(id: key, key: key, content: '不应出现在枚举结果', tags: []),
    ]);
    expect(await memory.listKeysForTool(library.id), [
      'event',
      'single',
      'user',
      'username',
    ]);
    expect(await memory.listKeysForTool(library.id, prefix: 'user'), [
      'user.age',
      'user.name',
      'user.preference',
    ]);
    expect(await memory.listKeysForTool(library.id, prefix: ' user. '), [
      'user.age',
      'user.name',
      'user.preference',
    ]);
    expect(
      await memory.listKeysForTool(library.id, prefix: 'user.preference'),
      ['user.preference.drink', 'user.preference.food'],
    );
    expect(
      await memory.listKeysForTool(library.id, prefix: 'user.name'),
      isEmpty,
    );
    expect(await memory.listKeysForTool(library.id, prefix: 'us'), isEmpty);
    expect(
      await memory.listKeysForTool(library.id, prefix: 'missing'),
      isEmpty,
    );
    expect(
      await memory.listKeysForTool(library.id, prefix: ''),
      await memory.listKeysForTool(library.id),
    );
    final other = await store.createMemoryLibrary('空库');
    expect(await memory.listKeysForTool(other.id), isEmpty);
    await expectLater(memory.listKeysForTool('agent-id'), throwsStateError);
    await expectLater(
      memory.listKeysForTool(library.id, prefix: 'user name'),
      throwsArgumentError,
    );
  });

  test('旧格式归档记忆可以从legacy枚举，再按完整key读取，枚举不截断', () async {
    final library = await store.createMemoryLibrary('旧库枚举');
    await store.saveMemory(library.id, {
      'fragments': [
        for (var i = 0; i < 60; i++)
          {'id': 'old$i', 'content': '旧值$i', 'archived': true},
      ],
    });
    expect(await memory.listKeysForTool(library.id), ['legacy']);
    final keys = await memory.listKeysForTool(library.id, prefix: 'legacy');
    expect(keys.length, 60);
    expect(keys, contains('legacy.old59'));
    expect(
      (await memory.searchForTool(
        library.id,
        null,
        key: keys.first,
      )).single['value'],
      startsWith('旧值'),
    );
    expect(
      (await store.loadMemory(library.id)).containsKey('fragments'),
      isTrue,
    );
  });

  test('同库同key覆盖并递增版本，其他库相同key独立', () async {
    final a = await store.createMemoryLibrary('键值A');
    final b = await store.createMemoryLibrary('键值B');
    final first = await memory.upsertForTool(a.id, 'user.language', '中文', []);
    final updated = await memory.upsertForTool(a.id, 'user.language', '英语', [
      '语言',
    ]);
    await memory.upsertForTool(b.id, 'user.language', '日语', []);
    expect(updated.id, first.id);
    expect(updated.createdAt, first.createdAt);
    expect(updated.revision, 2);
    expect(updated.updatedAt.isBefore(first.updatedAt), isFalse);
    expect((await memory.loadFragments(a.id)).length, 1);
    expect(
      (await memory.searchForTool(
        a.id,
        null,
        key: 'user.language',
      )).single['value'],
      '英语',
    );
    expect(
      (await memory.searchForTool(
        b.id,
        null,
        key: 'user.language',
      )).single['value'],
      '日语',
    );
    expect(
      await memory.searchForTool(a.id, null, key: 'user.missing'),
      isEmpty,
    );
    expect(await memory.searchForTool(a.id, '完全不相关'), isEmpty);
    expect(await memory.searchForTool(a.id, null, prefix: 'self.'), isEmpty);
    await memory.updateByKey(a.id, 'user.language', '德语', []);
    expect(
      (await memory.searchForTool(
        a.id,
        null,
        prefix: 'user.',
      )).single['revision'],
      3,
    );
    final doc = await store.loadMemory(a.id);
    expect(doc['schemaVersion'], 2);
    expect((doc['entries'] as Map)['user.language']['value'], '德语');
    expect(doc.containsKey('fragments'), isFalse);
    await memory.deleteByKey(a.id, 'user.language');
    expect(await memory.loadFragments(a.id), isEmpty);
    await expectLater(
      memory.updateByKey(a.id, 'unknown', 'x', []),
      throwsStateError,
    );
    await expectLater(memory.deleteByKey(a.id, 'unknown'), throwsStateError);
    await expectLater(
      memory.upsertForTool(a.id, ' ', 'x', []),
      throwsArgumentError,
    );
    await expectLater(
      memory.upsertForTool(a.id, 'user.name', ' ', []),
      throwsArgumentError,
    );
  });

  test('并发写相同key只留一个当前值，版本不丢失', () async {
    final library = await store.createMemoryLibrary('并发键值');
    await Future.wait([
      for (var i = 0; i < 8; i++)
        memory.upsertForTool(library.id, 'project.status', '状态$i', []),
    ]);
    final record = (await memory.loadFragments(library.id)).single;
    expect(record.value, '状态7');
    expect(record.revision, 8);
  });

  test('旧碎片以稳定legacy key读取，写入后迁移且保留标记与归档', () async {
    final library = await store.createMemoryLibrary('旧记忆');
    await store.saveMemory(library.id, {
      'fragments': [
        {
          'id': 'old',
          'content': '旧值',
          'userMarked': true,
          'archived': true,
          'createdAt': '2024-01-01T00:00:00.000Z',
        },
      ],
    });
    final old = (await memory.loadFragments(library.id)).single;
    expect(old.key, 'legacy.old');
    expect(old.value, '旧值');
    expect(
      (await memory.searchForTool(
        library.id,
        null,
        key: old.key,
      )).single['value'],
      '旧值',
    );
    await memory.upsertForTool(library.id, 'user.language', '中文', []);
    final migrated = (await memory.loadFragments(library.id)).first;
    expect(migrated.id, old.id);
    expect(migrated.userMarked, isTrue);
    expect(migrated.archived, isTrue);
    expect(migrated.createdAt, old.createdAt);
  });

  test('合并同key更新，导入不覆盖手动记录', () async {
    final library = await store.createMemoryLibrary('导入合并');
    await memory.upsertForTool(library.id, 'user.language', '中文', []);
    await memory.upsertForTool(
      library.id,
      'user.name',
      '手动姓名',
      [],
      source: 'manual',
    );
    await memory.mergeFragments(library.id, [
      MemoryFragment(
        id: 'import-1',
        key: 'user.language',
        content: '英语',
        tags: [],
        source: 'chat_import',
      ),
      MemoryFragment(
        id: 'import-2',
        key: 'user.name',
        content: '错误姓名',
        tags: [],
        source: 'chat_import',
      ),
    ]);
    final records = await memory.loadFragments(library.id);
    expect(records.length, 2);
    expect(records.first.value, '英语');
    expect(records.first.revision, 2);
    expect(records.last.value, '手动姓名');
  });

  test('不同key允许相同value，导入不会按value误合并', () async {
    final library = await store.createMemoryLibrary('独立事实');
    await memory.mergeFragments(library.id, [
      MemoryFragment(
        id: 'first',
        key: 'user.language',
        content: '中文',
        tags: [],
      ),
      MemoryFragment(
        id: 'second',
        key: 'project.language',
        content: '中文',
        tags: [],
      ),
    ]);
    expect((await memory.loadFragments(library.id)).length, 2);
  });

  test('创建独立库，按ID读写隔离，并返回可用于修改删除的碎片ID', () async {
    final a = await store.createMemoryLibrary('偏好库');
    final b = await store.createMemoryLibrary('工作库');
    expect(a.id, isNot(b.id));
    final fragmentId = await memory.addManual(a.id, '喜欢咖啡', ['咖啡']);
    final hits = await memory.searchForTool(a.id, '咖啡');
    expect(hits.single['id'], fragmentId);
    expect(hits.single['memoryId'], a.id);
    expect(await memory.searchForTool(b.id, null), isEmpty);
    await memory.updateForTool(a.id, fragmentId, '喜欢红茶', ['红茶']);
    expect((await memory.searchForTool(a.id, '红茶')).single['content'], '喜欢红茶');
    await memory.deleteFragment(a.id, fragmentId);
    expect(await memory.loadFragments(a.id), isEmpty);
    expect(await memory.loadFragments(b.id), isEmpty);
  });

  test('未知库ID不隐式创建，agent ID不能当作记忆库ID', () async {
    final before = (await store.loadMemoryLibraries()).map((l) => l.id).toSet();
    await expectLater(memory.addManual('agent-id', '内容', []), throwsStateError);
    await expectLater(memory.searchForTool('', null), throwsArgumentError);
    expect(
      (await store.loadMemoryLibraries()).map((l) => l.id).toSet(),
      before,
    );
  });

  test('并发创建库不会丢失索引，同库并发添加不会覆盖碎片', () async {
    final libraries = await Future.wait([
      store.createMemoryLibrary('共享库A'),
      store.createMemoryLibrary('共享库B'),
    ]);
    expect(
      (await store.loadMemoryLibraries()).map((l) => l.id),
      containsAll(libraries.map((l) => l.id)),
    );
    final library = libraries.first;
    await Future.wait([
      for (var i = 0; i < 5; i++)
        memory.addManual(library.id, '事实$i', ['标签$i']),
    ]);
    expect((await memory.loadFragments(library.id)).length, 5);
  });

  test('无库不注入，多库提示包含准确库名与memoryId', () async {
    final a = await store.createMemoryLibrary('用户偏好');
    final b = await store.createMemoryLibrary('用户计划');
    final agent = AIAgent.fromJson({
      'id': 'agent',
      'name': 'test',
      'description': '',
      'serviceProviderId': 'test',
      'baseUrl': 'https://example.com/v1',
    });
    expect(await memory.buildAgentInjectionSuffix(agent, '咖啡'), isEmpty);
    final enabled = agent.copyWith(
      alivenessConfig: AlivenessConfig(
        memoryEnabled: true,
        memoryIds: [a.id, b.id],
      ),
    );
    await memory.addManual(a.id, '喜欢咖啡', ['咖啡']);
    await memory.addManual(b.id, '周末出游', ['出游']);
    final suffix = await memory.buildAgentInjectionSuffix(enabled, '咖啡');
    expect(suffix, contains('用户偏好'));
    expect(suffix, contains(a.id));
    expect(suffix, contains('用户计划'));
    expect(suffix, contains(b.id));
    expect(suffix, contains('喜欢咖啡'));
    expect(suffix, contains('周末出游'));
  });
}
