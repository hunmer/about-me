import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/markdown_content.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';

void main() {
  // DS 组件需要 AppTheme：外层包 DSThemeBridge
  Widget wrap(Widget child) =>
      DSThemeBridge(child: MaterialApp(home: child));

  testWidgets('贴图编辑器：样式切换/添加删除贴纸/待办行编辑/Markdown', (tester) async {
    // 大视口：让预览卡片、内容编辑、样式/贴纸选择条全部可见可点
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      wrap(const CuteNotepadEditorPage(initialText: '今天天气很好 **加粗**')),
    );
    await tester.pumpAndSettle();

    // 预览区贴纸 + 贴纸选择条缩略图（懒加载，用相对数量断言）
    int stickerCount() =>
        tester.widgetList<SvgPicture>(find.byType(SvgPicture)).length;
    final initialPresetStickerCount =
        cuteNotepadPresets.first.stickers.length;
    final base = stickerCount();
    expect(base, greaterThan(initialPresetStickerCount));

    // 编辑器直接处于编辑态：无组件自身右上角按钮
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);

    // Markdown 正文默认开启（MarkdownContent 渲染正文）
    expect(find.byType(MarkdownContent), findsOneWidget);

    // 1. 添加贴纸：点击选择条第一项
    await tester.tap(find.byType(SvgPicture).at(initialPresetStickerCount + 1));
    await tester.pumpAndSettle();
    expect(stickerCount(), base + 1);

    // 2. 切换样式到 02（清单型）：贴纸列表保留（编辑器接管）
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(stickerCount(), base + 1);

    // 清单样式：内容编辑区为待办行，可添加一行；Markdown 正文层随样式隐藏
    expect(find.byType(MarkdownContent), findsNothing);
    await tester.tap(find.text('app_addRow'));
    await tester.pump();
    expect(find.byType(DSInput), findsWidgets);

    // 切回 01：Markdown 正文恢复
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownContent), findsOneWidget);

    // 3. 底部动作按钮存在（桌面测试环境为「保存到文件」）
    expect(find.text('app_share'), findsOneWidget);
    expect(find.text('app_saveToFile'), findsOneWidget);
  });

  testWidgets('贴图编辑器：撤销与重置贴纸布局', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      wrap(const CuteNotepadEditorPage(initialText: '撤销测试')),
    );
    await tester.pumpAndSettle();

    int stickerCount() =>
        tester.widgetList<SvgPicture>(find.byType(SvgPicture)).length;
    final undoButton = find.byTooltip('app_undoSticker');
    final resetButton = find.byTooltip('app_resetSticker');

    // 初始撤销不可用
    expect(tester.widget<Tooltip>(undoButton).message, 'app_undoSticker');

    // 1. 添加贴纸 → 撤销恢复
    final base = stickerCount();
    await tester.tap(find.byType(SvgPicture).at(base + 1));
    await tester.pumpAndSettle();
    expect(stickerCount(), base + 1);

    await tester.tap(undoButton);
    await tester.pumpAndSettle();
    expect(stickerCount(), base);

    // 2. 拖动预设贴纸 → 帧末回传压栈 → 撤销位置还原
    final sticker0 = find.byType(SvgPicture).at(0);
    final before = tester.getTopLeft(sticker0);
    await tester.drag(sticker0, const Offset(60, 30));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sticker0).dx, greaterThan(before.dx + 30));

    await tester.tap(undoButton);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sticker0).dx, closeTo(before.dx, 1));

    // 3. 重置贴纸布局：删掉一贴纸后重置 → 恢复预设贴纸数
    //    （拖动过程已选中贴纸 0，先点一次取消再点一次重新选中）
    await tester.tap(sticker0);
    await tester.pumpAndSettle();
    await tester.tap(sticker0);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(stickerCount(), base - 1);

    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(stickerCount(), base);

    // 重置后撤销可还原删除操作
    await tester.tap(undoButton);
    await tester.pumpAndSettle();
    expect(stickerCount(), base - 1);
  });

  testWidgets('贴纸工具条：水平翻转与撤销', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      wrap(const CuteNotepadEditorPage(initialText: '翻转测试')),
    );
    await tester.pumpAndSettle();

    Matrix4 stickerTransform() {
      var matrix = Matrix4.identity();
      for (final e in find
          .ancestor(
            of: find.byType(SvgPicture).first,
            matching: find.byType(Transform),
          )
          .evaluate()) {
        matrix = (e.widget as Transform).transform * matrix;
      }
      return matrix;
    }

    // 选中第一个贴纸 → 工具条出现翻转按钮
    await tester.tap(find.byType(SvgPicture).at(0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.flip), findsOneWidget);

    // 初始未翻转：m00 > 0
    expect(stickerTransform().entry(0, 0), greaterThan(0));

    // 水平翻转：m00 变负
    await tester.tap(find.byIcon(Icons.flip));
    await tester.pumpAndSettle();
    expect(stickerTransform().entry(0, 0), lessThan(0));

    // 帧末回传含 flipX → 撤销可还原
    await tester.tap(find.byTooltip('app_undoSticker'));
    await tester.pumpAndSettle();
    expect(stickerTransform().entry(0, 0), greaterThan(0));
  });
}
