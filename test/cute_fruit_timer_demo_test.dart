import 'package:aboutme/widgets/cute_fruit_timer_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('水果计时器支持计时、设置和快捷操作', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CuteFruitTimerDemo()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('Start Focus'));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Pause Focus'), findsOneWidget);
    expect(find.text('24:56'), findsOneWidget);

    await tester.tap(find.text('24:56'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Reading'));
    await tester.tap(find.text('5m'));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Reading'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Reset Timer'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Start Focus'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('水果卡片外部驱动模式：全屏 + 自定义按钮 + 进度果堆', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CuteFruitTimerCard(
            fruitKind: CuteFruitKind.lemon,
            fullscreen: true,
            progress: 0.5,
            timeText: '12:34',
            subtitle: '写作',
            isRunning: true,
            controls: ElevatedButton(
              onPressed: () {},
              child: const Text('自定义按钮'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('写作'), findsOneWidget);
    expect(find.text('自定义按钮'), findsOneWidget);
    expect(find.textContaining('已收获'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
