import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/live2d/screens/video_pet_editor_screen.dart';
import 'package:aboutme/plugins/live2d/video/video_pet_manifest.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest = VideoPetManifest(
    id: 'custom',
    name: '自定义宠物',
    canvasWidth: 640,
    canvasHeight: 360,
    animations: [
      VideoPetAnimation(id: 'idle', name: '待机', sources: {'webm': 'idle.webm'}),
      VideoPetAnimation(
        id: 'walk',
        name: '自定义走路',
        sources: {'webm': 'walk.webm'},
      ),
    ],
    idleAnimationId: 'idle',
  );

  testWidgets('无区域时仍可选择无分类动作并保存 movement', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VideoPetManifest? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<VideoPetManifest>(
                MaterialPageRoute(
                  builder: (_) => const VideoPetEditorScreen(
                    manifest: manifest,
                    baseUri: '',
                  ),
                ),
              );
            },
            child: const Text('打开编辑器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    expect(find.text('随机移动'), findsOneWidget);
    // 移动动画 5 个选择器已切换为 DS 可搜索下拉（DSCombobox）。
    final combos = find.byType(DSCombobox<String>);
    expect(combos, findsNWidgets(5));
    await tester.ensureVisible(combos.at(0));
    await tester.tap(combos.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义走路').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(combos.at(4));
    await tester.tap(combos.at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义走路').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.movement.leftAnimationId, 'walk');
    expect(saved!.movement.dragAnimationId, 'walk');
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏布局下可通过「移动与动作」Tab 编辑 facing / moving', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<VideoPetManifest>(
              MaterialPageRoute(
                builder: (_) => const VideoPetEditorScreen(
                  manifest: manifest,
                  baseUri: '',
                ),
              ),
            ),
            child: const Text('打开编辑器'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();

    // 窄屏底部工具区有四个 Tab：区域 / 动画 / 随机移动 / 动作编辑。
    expect(
      find.byKey(const ValueKey('videoPetNarrowAnimationTab')),
      findsOneWidget,
    );
    final actionTab = find.byKey(const ValueKey('videoPetNarrowActionTab'));
    expect(actionTab, findsOneWidget);

    // 先在「动画」Tab 点选动画，再切「动作编辑」配置 facing / moving。
    await tester.tap(find.byKey(const ValueKey('videoPetNarrowAnimationTab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义走路'));
    await tester.pumpAndSettle();

    await tester.tap(actionTab);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp('动作资源|选择上方动画')), findsOneWidget);

    // 向下滚动配置面板直到 facing / moving 编辑器可见。
    for (var i = 0; i < 6; i++) {
      if (tester.any(find.byKey(const ValueKey('videoPetFacing')))) break;
      await tester.drag(find.byType(TabBarView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('videoPetFacing')), findsOneWidget);
    expect(find.byKey(const ValueKey('videoPetMovingMode')), findsOneWidget);
    // 该 fixture 无 spritesheet（webm 源）：应有禁用说明。
    expect(find.textContaining('缺少 spritesheet'), findsOneWidget);

    // 拖拽分隔条可调整工具区高度。
    final divider = find.byKey(const ValueKey('videoPetNarrowDivider'));
    final tools = find.byType(DefaultTabController);
    final before = tester.getSize(tools).height;
    await tester.drag(divider, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(tester.getSize(tools).height - before, closeTo(80, 2));
    expect(tester.takeException(), isNull);
  });
}
