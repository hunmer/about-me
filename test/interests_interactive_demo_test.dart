import 'package:aboutme/widgets/interests_interactive_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('选择兴趣后播放动画并更新计数', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InterestsInteractiveDemo())),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Camping'), findsOneWidget);

    await tester.tap(find.text('Football'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Football'));
    await tester.pump(const Duration(milliseconds: 520));

    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
