import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skribble/skribble.dart' show WiredIcon;

import 'package:aboutme/core/widgets/custom_bottom_bar.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 回归：底部导航栏贴底且不吞掉 bar 区域外的点击
///
/// 此前 bug：DSBottomNavigation 的 Center 在底部外壳给的全屏高松约束下
/// 撑满整屏，dock 被顶到屏幕垂直中心，且透明装饰盒吸收全屏命中，
/// 导致页面内容完全不可点。
void main() {
  testWidgets('CustomBottomBar：bar 贴底收缩、上方内容可点击', (tester) async {
    var tapped = false;
    final tabController = TabController(length: 2, vsync: tester);
    addTearDown(tabController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomBottomBar(
            tabController: tabController,
            currentIndex: 0,
            items: const [
              DSNavItem(icon: DsIconKind.home, label: 'A'),
              DSNavItem(icon: DsIconKind.user, label: 'B'),
            ],
            body: (context, controller) => ListView(
              controller: controller,
              children: [
                TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('target'),
                ),
                for (var i = 0; i < 30; i++) ListTile(title: Text('item $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. bar 只占内容高度（不撑满全屏）
    final barBox =
        tester.renderObject<RenderBox>(find.byType(DSBottomNavigation));
    expect(barBox.size.height, lessThan(150),
        reason: 'bar 应收缩为内容高度而非撑满松约束');

    // 2. bar 底边贴近视口底部（offset 12）
    final barBottom =
        barBox.localToGlobal(Offset.zero).dy + barBox.size.height;
    expect(barBottom, closeTo(600 - 12, 2), reason: 'bar 底边应贴底');

    // 3. bar 上方的页面内容可点击（不被透明区域遮挡）
    await tester.tap(find.text('target'));
    await tester.pump();
    expect(tapped, isTrue, reason: 'bar 区域外的点击应穿透到页面内容');
  });

  testWidgets('CustomBottomBar：tab 与停靠 fab 可点击', (tester) async {
    var fabTapped = false;
    final tabController = TabController(length: 2, vsync: tester);
    addTearDown(tabController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomBottomBar(
            tabController: tabController,
            currentIndex: 0,
            items: const [
              DSNavItem(icon: DsIconKind.home, label: 'A'),
              DSNavItem(icon: DsIconKind.user, label: 'B'),
            ],
            fab: GestureDetector(
              key: const ValueKey('fab'),
              behavior: HitTestBehavior.opaque,
              onTap: () => fabTapped = true,
              child: const SizedBox(width: 44, height: 44),
            ),
            body: (context, controller) => ListView(
              controller: controller,
              children: [for (var i = 0; i < 30; i++) ListTile(title: Text('i$i'))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // dock 右端停靠的 fab 可命中
    expect(find.byKey(const ValueKey('fab')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fab')));
    await tester.pump();
    expect(fabTapped, isTrue);

    // tab 2 可点击（经 tabController 切换）。
    // DsIcon 手绘化后内部是 WiredIcon（不再是 Icon），
    // 按 IconData 数据匹配而非 byIcon
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is WiredIcon && w.icon == Icons.person_outline,
      ),
    );
    await tester.pumpAndSettle();
    expect(tabController.index, 1);
  });
}
