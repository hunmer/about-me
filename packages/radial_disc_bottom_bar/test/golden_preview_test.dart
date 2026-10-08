import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radial_disc_bottom_bar/radial_disc_bottom_bar.dart';

/// 视觉验收用 golden：生成后与参考实现比对
void main() {
  List<RadialDiscTab> tabs() => [
        for (var i = 0; i < 5; i++)
          RadialDiscTab(
            label: 'Tab ${i + 1}',
            iconBuilder: (_, selected) => Icon(
              [Icons.home, Icons.grid_view, Icons.donut_small, Icons.search, Icons.person][i],
              size: 20,
              color: selected ? Colors.white : const Color(0xFF4B5563),
            ),
          ),
      ];

  testWidgets('浅色 · 子栏展开（Tab 1）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFFF0F2F5),
        child: Center(
          child: RadialDiscBottomBar(
            tabs: tabs(),
            activeIndex: 0,
            subLabels: const ('Option A', 'Option B'),
            leadingAction: const Icon(Icons.sports_esports),
            trailingAction: const Icon(Icons.visibility),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RadialDiscBottomBar),
      matchesGoldenFile('goldens/light_sub_bar.png'),
    );
  });

  testWidgets('深色 · 子栏折叠（Tab 4，auto 模式）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF0E1014),
        child: Center(
          child: RadialDiscBottomBar(
            tabs: tabs(),
            activeIndex: 3,
            subLabels: const ('Option A', 'Option B'),
            style: const RadialDiscBarStyle.dark(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RadialDiscBottomBar),
      matchesGoldenFile('goldens/dark_folded.png'),
    );
  });

  testWidgets('浅色 · 磨砂 + 子栏右圆钮位置浮动操作钮（仅 dock）', (tester) async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFFE8CBFF),
        child: Center(
          child: RadialDiscBottomBar(
            tabs: tabs(),
            activeIndex: 0,
            frosted: true,
            style: const RadialDiscBarStyle().copyWith(
              fillColor: const Color(0xB3FFFFFF),
            ),
            floatingAction: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF3498DB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RadialDiscBottomBar),
      matchesGoldenFile('goldens/light_docked_action.png'),
    );
  });
}
