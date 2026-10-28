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
    final selectors = find.byType(DropdownButtonFormField<String>);
    expect(selectors, findsNWidgets(4));
    await tester.tap(selectors.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义走路').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.movement.leftAnimationId, 'walk');
    expect(tester.takeException(), isNull);
  });
}
