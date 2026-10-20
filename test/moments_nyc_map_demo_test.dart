import 'package:aboutme/widgets/moments_nyc_map_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MomentsNycMapDemo 渲染地图与标题', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MomentsNycMapDemo())),
    );
    await tester.pump();

    expect(find.text('Moments'), findsOneWidget);
    expect(find.text('NEW YORK'), findsWidgets);
    expect(find.text('New Moment'), findsOneWidget);
  });

  testWidgets('点击大头针打开手账详情并可返回', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MomentsNycMapDemo())),
    );
    await tester.pump();

    // 点击 New Moment 打开 place-of-power 详情
    await tester.tap(find.text('New Moment'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PLACE OF POWER'), findsWidgets);
    expect(find.text('Preview'), findsOneWidget);

    // 返回地图
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('New Moment'), findsOneWidget);
  });
}
