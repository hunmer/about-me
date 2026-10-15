import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cute_notepad_variants.dart';

void main() {
  testWidgets('编辑模式：按钮切换 / 贴纸选中旋转缩放拖动 / 导出态', (tester) async {
    // toast 走 styled_toast（需要 navigator context）
    final navKey = GlobalKey<NavigatorState>();
    ToastService.instance.setNavigatorKey(navKey);

    Widget buildCard(bool editable) {
      return MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: Center(
            child: CuteNotepadCardWidget(
              variant: resolveCuteNotepadVariant('pinkGridBunny'),
              text: '写点内容',
              editable: editable,
            ),
          ),
        ),
      );
    }

    // 1. editable=false：无编辑按钮
    await tester.pumpWidget(buildCard(false));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsNothing);

    // 2. editable=true：右上角编辑按钮
    await tester.pumpWidget(buildCard(true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsOneWidget);

    // 3. 点击编辑 → 切换为导出按钮
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.download), findsOneWidget);

    // 4. 点击第一个贴纸（左上角红蝴蝶结）选中 → 出现工具条
    expect(find.byIcon(Icons.rotate_left), findsNothing);
    await tester.tap(find.byType(SvgPicture).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.rotate_left), findsOneWidget);

    Matrix4 stickerTransform() {
      final transforms = find
          .ancestor(
            of: find.byType(SvgPicture).first,
            matching: find.byType(Transform),
          )
          .evaluate();
      var matrix = Matrix4.identity();
      for (final e in transforms) {
        final t = e.widget as Transform;
        matrix = t.transform * matrix;
      }
      return matrix;
    }

    // 5. 工具条右转 15° → 出现旋转分量
    await tester.tap(find.byIcon(Icons.rotate_right));
    await tester.pump();
    expect(stickerTransform().entry(0, 1), closeTo(-0.2588, 0.01));

    // 6. 工具条放大 → 复合矩阵 m00 = 1.1 × cos15° ≈ 1.0625
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(stickerTransform().entry(0, 0), closeTo(1.0625, 0.02));

    // 7. 拖动贴纸 → 位置变化（touch-slop 阶段不派发，实际位移略小于拖动量）
    final before = tester.getTopLeft(find.byType(SvgPicture).first);
    await tester.drag(find.byType(SvgPicture).first, const Offset(40, 24));
    await tester.pump();
    final after = tester.getTopLeft(find.byType(SvgPicture).first);
    expect(after.dx, greaterThan(before.dx + 15));
    expect(after.dy, greaterThan(before.dy + 4));

    // 8. 点击导出 → 按钮进入 loading 导出态
    //    （engine 的 toByteData 在 flutter_test 软件渲染下不派发完成回调，
    //     完整 PNG 导出链路需真机/桌面验收）
    await tester.tap(find.byIcon(Icons.download));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
