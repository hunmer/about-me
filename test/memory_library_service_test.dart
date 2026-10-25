import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
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
