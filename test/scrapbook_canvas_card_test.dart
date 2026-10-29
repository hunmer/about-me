import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_canvas_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_item_content.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/scrapbook_canvas_card/scrapbook_item_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('缩放倍率保存恢复，旧数据默认原始大小', () {
    final item = ScrapItemData.fromMap({'kind': 'text'});
    expect(item.scale, 1);
    item.scale = 1.5;
    expect(ScrapItemData.fromMap(item.toMap()).scale, 1.5);
  });

  for (final kind in [ScrapItemKind.photo, ScrapItemKind.text]) {
    testWidgets('$kind 整体布局等比缩放且放大区域可点击', (tester) async {
      final item = ScrapItemData(
        id: 'item',
        kind: kind,
        x: 0,
        y: 0,
        width: 100,
        height: 60,
        captions: ['测试素材'],
      );
      var taps = 0;
      Future<void> render() => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: GestureDetector(
              key: const Key('content'),
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: buildScrapItemContent(item, false, (_) {}),
            ),
          ),
        ),
      );
      await render();
      final original = tester.getSize(find.byKey(const Key('content')));
      item.scale = 2;
      await render();
      final scaled = tester.getSize(find.byKey(const Key('content')));
      expect(scaled.width, closeTo(original.width * 2, 0.01));
      expect(scaled.height, closeTo(original.height * 2, 0.01));
      final rect = tester.getRect(find.byKey(const Key('content')));
      await tester.tapAt(rect.bottomRight - const Offset(2, 2));
      expect(taps, 1);
    });
  }

  testWidgets('大小按钮通知变更，支持撤销重做', (tester) async {
    List<ScrapItemData>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrapbookCanvasCardWidget(
            inline: true,
            items: [
              ScrapItemData(
                id: 'item',
                kind: ScrapItemKind.text,
                x: 50,
                y: 200,
                captions: ['测试素材'],
              ),
            ],
            onChanged: (items, _) => saved = items,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试素材'));
    await tester.pump();
    await tester.tap(find.byTooltip('等比放大'));
    await tester.pump();
    expect(saved!.single.scale, closeTo(1.1, 0.001));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(saved!.single.scale, 1);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(saved!.single.scale, closeTo(1.1, 0.001));
    await tester.tap(find.byTooltip('等比缩小'));
    await tester.pump();
    expect(saved!.single.scale, closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });
}
