import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/widgets_gallery/screens/ai_picks_demo/ai_picks_demo_screen.dart';
import 'package:aboutme/screens/widgets_gallery/screens/ai_picks_demo/book_cover.dart';
import 'package:aboutme/screens/widgets_gallery/screens/ai_picks_demo/book_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AI-Picks for You DEMO 复刻：首页 / 详情页渲染与交互冒烟
void main() {
  testWidgets('AI-Picks DEMO 首页渲染、点开详情、关闭返回', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(const MaterialApp(home: AiPicksDemoScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 首页关键元素：大标题 + 封面网格
    expect(find.text('AI-Picks for You'), findsOneWidget);
    expect(find.byType(BookCover), findsWidgets);

    // 点开第一本书 → 详情页（带 320ms 淡入过渡）
    await tester.tap(find.byType(BookCover).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byType(BookDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 详情页关键区块
    expect(find.text('Book Overview'), findsOneWidget);
    expect(find.text('Start Reading'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // 滚动详情页
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 关闭按钮返回首页
    await tester.tap(find.byWidgetPredicate(
      (w) => w is DsIcon && w.kind == DsIconKind.close,
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byType(BookDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
