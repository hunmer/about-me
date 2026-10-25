import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_manager_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
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

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('memory-manager-screen-');
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

  setUp(() async {
    await AboutmeDataService.instance.call('openai', 'alivenessSetDoc', {
      'kind': 'memory_libraries',
      'doc': {'libraries': []},
    });
  });

  Future<void> pumpManager(
    WidgetTester tester, {
    AlivenessConfig? config,
    ValueChanged<AlivenessConfig>? onChanged,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryManagerScreen(config: config, onConfigChanged: onChanged),
        ),
      );
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('未绑定入口显示全局库管理，不显示不可持久化的勾选框', (tester) async {
    await tester.runAsync(() async {
      await store.createMemoryLibrary('全局库');
    });
    await pumpManager(tester);

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
    expect(find.text('选择供当前 agent 使用的库；返回编辑页保存生效'), findsNothing);
  });

  testWidgets('绑定入口选择多个库并通过回调同步 memoryIds', (tester) async {
    final libraries = (await tester.runAsync(() async => [
      await store.createMemoryLibrary('库一'),
      await store.createMemoryLibrary('库二'),
    ]))!;
    AlivenessConfig? changed;

    await pumpManager(
      tester,
      config: const AlivenessConfig(memoryEnabled: true),
      onChanged: (config) => changed = config,
    );

    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('选择供当前 agent 使用的库；返回编辑页保存生效'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pump();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.memoryIds, containsAll(libraries.map((l) => l.id)));
  });
}
