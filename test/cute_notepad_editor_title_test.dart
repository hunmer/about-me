import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_card.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';

void main() {
  // DS 组件需要 AppTheme：外层包 DSThemeBridge
  Widget wrap(Widget child) =>
      DSThemeBridge(child: MaterialApp(home: child));

  testWidgets('编辑器：模板小标题编辑（无标题样式隐藏输入，切换跟随预设）', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      wrap(const CuteNotepadEditorPage(initialText: '标题编辑测试')),
    );
    await tester.pumpAndSettle();

    // 默认 01 样式无标题位：不显示标题输入
    expect(find.text('app_notepadTitle'), findsNothing);

    // 切到 03（带预设标题 Small steps）：标题输入出现并预填预设文字
    await tester.tap(find.text('03'));
    await tester.pumpAndSettle();
    expect(find.text('app_notepadTitle'), findsOneWidget);
    expect(find.text('Small steps\nbig progress ♡'), findsOneWidget);

    // 编辑标题 → 预览画布上的标题文字同步更新
    await tester.enterText(
      find.text('Small steps\nbig progress ♡'),
      '我的小标题',
    );
    await tester.pumpAndSettle();
    expect(find.text('我的小标题'), findsOneWidget);

    // 已手动编辑：标题跨样式保留（与正文/贴纸一致），不跟随预设
    await tester.tap(find.text('08'));
    await tester.pumpAndSettle();
    expect(find.text('我的小标题'), findsOneWidget);
    await tester.tap(find.text('03'));
    await tester.pumpAndSettle();
    expect(find.text('我的小标题'), findsOneWidget);
  });

  testWidgets('样式预览条：固定演示内容，实例缓存不随正文重建', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      wrap(const CuteNotepadEditorPage(initialText: '预览缓存测试')),
    );
    await tester.pumpAndSettle();

    // [0] 为主预览卡片，其后为样式条迷你预览（懒挂载，至少 1 个）
    final before = tester
        .widgetList<CuteNotepadCardWidget>(
          find.byType(CuteNotepadCardWidget),
        )
        .toList();
    expect(before.length, greaterThan(1));
    final miniBefore = before[1];

    // 修改正文触发整页 setState：主预览换新实例，迷你预览保持同一实例
    await tester.enterText(find.text('预览缓存测试'), '新正文内容');
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<CuteNotepadCardWidget>(
          find.byType(CuteNotepadCardWidget),
        )
        .toList();
    expect(after[1], same(miniBefore));
    expect(after[0], isNot(same(before[0])));
  });
}
