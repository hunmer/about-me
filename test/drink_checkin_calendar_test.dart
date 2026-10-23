import 'package:aboutme/widgets/drink_checkin_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('饮品打卡日历 demo 渲染（含全部贴纸 SVG 解析）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: DrinkCheckinCalendarDemo()),
    );
    await tester.pumpAndSettle();

    expect(find.text('2月'), findsOneWidget);
    // 贴纸 SVG 全部成功解析渲染（月历格子 + 记录列表）
    expect(find.byType(SvgPicture), findsWidgets);
    // 记录列表首条（2月22日 拿铁）
    expect(find.text('2月22日'), findsOneWidget);
  });
}
