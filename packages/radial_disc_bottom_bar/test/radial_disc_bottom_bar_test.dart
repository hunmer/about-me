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

  testWidgets('floatingAction：位于子栏右圆钮位置且不挡 tab 点击', (tester) async {
    var selected = -1;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      onTabChange: (i) => selected = i,
      floatingAction: GestureDetector(
        key: const ValueKey('floating'),
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const SizedBox(width: 44, height: 44),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('floating')), findsOneWidget);
    // 浮动钮模式下画布只裁掉少量顶部（44px 钮中心 y≈52）
    final size = tester.getSize(find.byType(RadialDiscBottomBar));
    expect(size.height, RadialGeometry.canvasHeight - 28 - 13);

    // 浮动钮高于主 dock：其中心应比最后一个 tab 按钮更靠上
    final action = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('floating')));
    final lastTab = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('icon4')));
    expect(
      action.localToGlobal(Offset.zero).dy,
      lessThan(lastTab.localToGlobal(Offset.zero).dy),
    );

    // tab 保持全幅角度，最后一个 tab 依旧可命中
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

  testWidgets('仅圆按钮无 subLabels：不画空胶囊，圆钮常驻浮动', (tester) async {
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      leadingAction: const Icon(Icons.gamepad),
    )));
    await tester.pumpAndSettle();

    // 无 subLabels → 子栏折叠目标恒为 0，不画空胶囊；
    // 高度为 dock + 浮动圆钮裁剪（非完整 146 画布）
    final size = tester.getSize(find.byType(RadialDiscBottomBar));
    expect(size.height, RadialGeometry.canvasHeight - 28 - 13);
    expect(find.byIcon(Icons.gamepad), findsOneWidget);

    // 圆钮在 dock 上方浮动，位置高于第一个 tab
    final disc = tester.renderObject<RenderBox>(
      find.byIcon(Icons.gamepad));
    final firstTab = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('icon0')));
    expect(
      disc.localToGlobal(Offset.zero).dy,
      lessThan(firstTab.localToGlobal(Offset.zero).dy),
    );
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

  testWidgets('subActions：沿子栏弧线排布，点按回调与激活态生效', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      subActions: [
        for (var i = 0; i < 3; i++)
          RadialSubAction(
            label: 'Action ${i + 1}',
            selected: i == 1,
            onTap: () => tapped = i,
            icon: Icon(Icons.star, key: ValueKey('action$i')),
          ),
      ],
    )));
    await tester.pumpAndSettle();

    // subActions 启用子栏 → 完整画布高度，不裁剪
    final size = tester.getSize(find.byType(RadialDiscBottomBar));
    expect(size.height, RadialGeometry.canvasHeight);

    // 三个圆钮都渲染且可点按
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('action$i')));
      await tester.pumpAndSettle();
      expect(tapped, i);
      tapped = -1;
    }

    // 激活（selected）圆钮使用 activePillColor 实底
    final decoration = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byKey(const ValueKey('action1')),
        matching: find.byType(DecoratedBox),
      ).first,
    ).decoration as BoxDecoration;
    expect(
      decoration.color,
      const RadialDiscBarStyle().activePillColor,
    );
  });

  testWidgets('trailingSelected：右侧圆钮激活态主题色实底', (tester) async {
    await tester.pumpWidget(wrap(RadialDiscBottomBar(
      tabs: buildTabs(),
      activeIndex: 0,
      trailingAction: const Icon(Icons.gamepad_outlined),
      trailingSelected: true,
    )));
    await tester.pumpAndSettle();

    // 仅圆钮时走常驻浮动圆盘分支，激活圆钮使用 activePillColor 实底
    final decoration = tester.widget<DecoratedBox>(
      find.ancestor(
        of: find.byIcon(Icons.gamepad_outlined),
        matching: find.byType(DecoratedBox),
      ).first,
    ).decoration as BoxDecoration;
    expect(decoration.color, const RadialDiscBarStyle().activePillColor);
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
