import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_library_detail_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_manager_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
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

  Future<void> pumpDetail(
    WidgetTester tester,
    String memoryId,
    String memoryName,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: MemoryLibraryDetailScreen(
            memoryId: memoryId,
            memoryName: memoryName,
          ),
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

  Future<void> submitMemory(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, label));
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.byType(AlertDialog).evaluate().isEmpty ||
            find.textContaining('操作失败：').evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 100; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.textContaining('操作失败：').evaluate().isNotEmpty ||
            find.byType(AlertDialog).evaluate().isEmpty) {
          if (attempt >= 5) break;
        }
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final keyboardInset in [0.0, 240.0]) {
    testWidgets('添加碎片和事件可布局并保存，键盘高度 $keyboardInset', (tester) async {
      tester.view.physicalSize = const Size(480, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final library = (await tester.runAsync(
        () => store.createMemoryLibrary('布局测试'),
      ))!;
      await pumpDetail(tester, library.id, library.name);

      for (final isLoop in [false, true]) {
        if (isLoop) {
          await tester.tap(find.text('开环事件 (0)'));
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          await tester.tap(find.text(isLoop ? '添加事件' : '添加碎片'));
          await tester.pumpAndSettle();
        });
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        debugPrint(
          '[MemoryDialogTest] keyboard=$keyboardInset loop=$isLoop '
          'dialog=${tester.getSize(find.byType(AlertDialog))}',
        );
        final content = isLoop ? '测试后续事件' : '测试记忆内容';
        if (isLoop) {
          await tester.enterText(find.byType(TextField).first, content);
        } else {
          await tester.enterText(
            find.byType(TextField).first,
            'user.interview',
          );
          await tester.ensureVisible(find.byType(TextField).at(1));
          await tester.enterText(find.byType(TextField).at(1), content);
          await tester.ensureVisible(find.byType(TextField).last);
          await tester.enterText(find.byType(TextField).last, '工作,面试');
        }
        await submitMemory(tester, '添加');
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 100; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(AlertDialog).evaluate().isEmpty &&
                find.text(content).evaluate().isNotEmpty) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(content), findsOneWidget);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
      final fragments = await tester.runAsync(
        () => MemoryService.instance.loadFragments(library.id),
      );
      expect(fragments!.single.key, 'user.interview');
      expect(fragments.single.value, '测试记忆内容');
      expect(fragments.single.tags, ['工作', '面试']);
      expect(fragments.single.source, 'manual');
      final loops = await tester.runAsync(
        () => MemoryService.instance.loadOpenLoops(library.id),
      );
      expect(loops!.single.description, '测试后续事件');
    });
  }

  testWidgets('添加记忆校验空 key 和 value，取消后控制器安全释放', (tester) async {
    final library = (await tester.runAsync(
      () => store.createMemoryLibrary('必填校验'),
    ))!;
    await pumpDetail(tester, library.id, library.name);
    await tester.runAsync(() async {
      await tester.tap(find.text('添加碎片'));
      await tester.pumpAndSettle();
    });
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('请输入 key'), findsOneWidget);
    expect(find.text('请输入 value'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'user.language');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 key'), findsNothing);
    expect(find.text('请输入 value'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    final fragments = await tester.runAsync(
      () => MemoryService.instance.loadFragments(library.id),
    );
    expect(fragments, isEmpty);
  });

  testWidgets('编辑 key 只读，value 和标签可保存，同 key 添加覆盖原记忆', (tester) async {
    final library = (await tester.runAsync(
      () => store.createMemoryLibrary('编辑与覆盖'),
    ))!;
    final original = (await tester.runAsync(
      () => MemoryService.instance.upsertForTool(
        library.id,
        'user.language',
        '英语',
        ['语言'],
      ),
    ))!;
    await pumpDetail(tester, library.id, library.name);
    expect(find.text('user.language'), findsOneWidget);
    expect(find.text('英语'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
    });
    expect(
      tester.widget<TextField>(find.byType(TextField).first).readOnly,
      isTrue,
    );
    expect(find.text('Key 不可修改'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '   ');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('请输入 value'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '简体中文');
    await tester.enterText(find.byType(TextField).last, '中文，偏好');
    await submitMemory(tester, '保存');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('英语'), findsNothing);
    final edited = (await tester.runAsync(
      () => MemoryService.instance.loadFragments(library.id),
    ))!.single;
    expect(edited.id, original.id);
    expect(edited.key, 'user.language');
    expect(edited.value, '简体中文');
    expect(edited.tags, ['中文', '偏好']);
    expect(edited.source, 'manual');
    expect(edited.revision, greaterThan(original.revision));

    await tester.runAsync(() async {
      await tester.tap(find.text('添加碎片'));
      await tester.pumpAndSettle();
    });
    expect(find.text('同一记忆库中，已有相同 key 时将覆盖其 value 和标签。'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'user.language');
    await tester.enterText(find.byType(TextField).at(1), '粤语');
    await tester.enterText(find.byType(TextField).last, '口语');
    await submitMemory(tester, '添加');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('user.language'), findsOneWidget);
    expect(find.text('粤语'), findsOneWidget);
    expect(find.text('简体中文'), findsNothing);
    expect(find.text('记忆碎片 (1)'), findsOneWidget);
    final overwritten = (await tester.runAsync(
      () => MemoryService.instance.loadFragments(library.id),
    ))!.single;
    expect(overwritten.id, original.id);
    expect(overwritten.value, '粤语');
    expect(overwritten.tags, ['口语']);
    expect(overwritten.source, 'manual');
    expect(overwritten.revision, greaterThan(edited.revision));
  });

  testWidgets('编辑已被删除的 key 显示错误，保留输入并允许取消', (tester) async {
    final library = (await tester.runAsync(
      () => store.createMemoryLibrary('编辑失败'),
    ))!;
    final original = (await tester.runAsync(
      () => MemoryService.instance.upsertForTool(
        library.id,
        'user.language',
        '英语',
        ['语言'],
      ),
    ))!;
    await pumpDetail(tester, library.id, library.name);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
    });
    await tester.enterText(find.byType(TextField).at(1), '简体中文');
    await tester.runAsync(
      () => MemoryService.instance.deleteFragment(library.id, original.id),
    );
    await submitMemory(tester, '保存');
    expect(find.textContaining('操作失败：'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '简体中文',
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    final libraries = (await tester.runAsync(
      () async => [
        await store.createMemoryLibrary('库一'),
        await store.createMemoryLibrary('库二'),
      ],
    ))!;
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
