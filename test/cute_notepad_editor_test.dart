import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';
import 'package:aboutme/widgets/common/cute_notepad_editor.dart';

void main() {
  testWidgets('贴图编辑器：样式切换/添加删除贴纸/待办行编辑', (tester) async {
    // 大视口：让预览卡片、内容编辑、样式/贴纸选择条全部可见可点
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      const MaterialApp(home: CuteNotepadEditorPage(initialText: '今天天气很好')),
    );
    await tester.pumpAndSettle();

    // 预览区贴纸 + 贴纸选择条缩略图（SvgThumb 内也是 SvgPicture；
    // 缩略图列表懒加载，用相对数量断言）
    int stickerCount() =>
        tester.widgetList<SvgPicture>(find.byType(SvgPicture)).length;
    final initialPresetStickerCount =
        cuteNotepadPresets.first.stickers.length;
    final base = stickerCount();
    expect(base, greaterThan(initialPresetStickerCount));

    // 编辑器直接处于编辑态：无组件自身右上角按钮
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.download), findsNothing);

    // 1. 添加贴纸：点击选择条第一项
    await tester.tap(find.byType(SvgThumb).first);
    await tester.pumpAndSettle();
    expect(stickerCount(), base + 1);

    // 2. 切换样式到 02（黄色 To Do 清单）：贴纸列表保留（编辑器接管）
    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(stickerCount(), base + 1);

    // 切到清单样式后内容编辑区为待办行编辑，可添加一行
    await tester.tap(find.text('添加一行'));
    await tester.pump();
    expect(find.byType(TextField), findsWidgets);

    // 3. 选中新增贴纸（预览区贴纸位于缩略图之前）→ 工具条出现删除按钮 → 删除
    await tester.tap(
      find.byType(SvgPicture).at(initialPresetStickerCount),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(stickerCount(), base);

    // 4. 底部动作按钮存在
    expect(find.text('分享'), findsOneWidget);
    expect(find.textContaining('保存到'), findsOneWidget);
  });
}
