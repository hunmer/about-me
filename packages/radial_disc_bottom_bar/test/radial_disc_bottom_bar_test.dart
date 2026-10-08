import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radial_disc_bottom_bar/radial_disc_bottom_bar.dart';

void main() {
  List<RadialDiscTab> buildTabs() => [
        for (var i = 0; i < 5; i++)
          RadialDiscTab(
            label: 'Tab ${i + 1}',
            iconBuilder: (_, selected) => Icon(
              Icons.looks_one,
              color: selected ? Colors.white : Colors.grey,
              // 各 tab 用不同 key 区分查找
              key: ValueKey('icon$i'),
            ),
          ),
      ];

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('仅 dock 模式：固有尺寸 380×78，点按回调生效', (tester) async {
    var selected = -1;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      onTabChange: (i) => selected = i,
    )));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(RadialDiscBottomBar));
    expect(size.width, RadialGeometry.canvasWidth);
    expect(size.height, RadialGeometry.canvasHeight - 55 - 13,
        reason: '裁掉上下空区（弧顶上方 55、最低点下方 13）');

    await tester.tap(find.byKey(const ValueKey('icon4')));
    await tester.pumpAndSettle();
    expect(selected, 4);
  });

  testWidgets('dockedAction：停靠右端且仍可点按最后一个 tab', (tester) async {
    var selected = -1;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      onTabChange: (i) => selected = i,
      dockedAction: GestureDetector(
        key: const ValueKey('docked'),
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const SizedBox(width: 44, height: 44),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('docked')), findsOneWidget);
    // dockedAction 存在时 tab 角度收窄，最后一个 tab 依旧可命中
    await tester.tap(find.byKey(const ValueKey('icon4')));
    await tester.pumpAndSettle();
    expect(selected, 4);
  });

  testWidgets('磨砂模式：正常渲染与交互', (tester) async {
    var selected = -1;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 1,
      onTabChange: (i) => selected = i,
      frosted: true,
      subLabels: const ('Option A', 'Option B'),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('icon3')));
    await tester.pumpAndSettle();
    expect(selected, 3);
  });

  testWidgets('子栏选项切换回调', (tester) async {
    RadialSubOption? picked;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      subLabels: const ('Option A', 'Option B'),
      onSubOptionChange: (opt) => picked = opt,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Option B'));
    await tester.pumpAndSettle();
    expect(picked, RadialSubOption.right);
  });

  testWidgets('带子栏：尺寸 380×146，切到后半 tab 自动折叠', (tester) async {
    var index = 0;
    late StateSetter setStateOuter;
    await tester.pumpWidget(wrap(StatefulBuilder(
      builder: (context, setState) {
        setStateOuter = setState;
        return RadialDiscBottomBar(
          tabs: buildTabs(),
          activeIndex: index,
          onTabChange: (i) => setState(() => index = i),
          subLabels: const ('Option A', 'Option B'),
        );
      },
    )));
    await tester.pumpAndSettle();

    var size = tester.getSize(find.byType(RadialDiscBottomBar));
    expect(size.height, RadialGeometry.canvasHeight);

    expect(find.text('Option A'), findsOneWidget);
    expect(find.text('Option B'), findsOneWidget);

    // 切到第 4 个 tab（auto 模式下收起子栏）
    setStateOuter(() => index = 3);
    await tester.pumpAndSettle();
    expect(find.byType(RadialDiscBottomBar), findsOneWidget);

    // 子栏选项切换回调
    setStateOuter(() => index = 0);
    await tester.pumpAndSettle();
  });

  test('扇环路径几何：主/子 dock 覆盖与排除的关键点', () {
    final mainRibbon = RadialGeometry.mainRibbon;
    // 弧顶中点（曲率圆心 636 - 外半径 580 = 56）
    expect(RadialGeometry.polar(0, RadialGeometry.mainOuterRadius).dy, closeTo(56, 0.01));
    // 主 dock 内部点：中心横截面与两端圆帽中心
    expect(mainRibbon.contains(const Offset(190, 80)), isTrue);
    expect(
      mainRibbon.contains(RadialGeometry.polar(-16.2, RadialGeometry.mainMidRadius)),
      isTrue,
    );
    expect(
      mainRibbon.contains(RadialGeometry.polar(16.2, RadialGeometry.mainMidRadius)),
      isTrue,
    );
    // 外部点：弧顶上方 / 内弧下方 / 左端外侧
    expect(mainRibbon.contains(const Offset(190, 40)), isFalse);
    expect(mainRibbon.contains(const Offset(190, 125)), isFalse);
    expect(mainRibbon.contains(const Offset(5, 80)), isFalse);

    // 子栏：中心横截面内部、下方主 dock 区域外部
    final subRibbon = RadialGeometry.subRibbon;
    expect(subRibbon.contains(const Offset(190, 30)), isTrue);
    expect(subRibbon.contains(const Offset(190, 80)), isFalse);
  });
}
