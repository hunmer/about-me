import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/monthly_capsule_chart_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/period_score_gauge_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/sparkle_stat_grid_card.dart';

void main() {
  testWidgets('闪光统计网格卡片渲染数据', (tester) async {
    await _pumpCard(
      tester,
      SparkleStatGridCardWidget.fromProps({
        'items': [
          {
            'label': 'Achieved',
            'value': 12,
            'icon': Icons.verified_outlined,
            'backgroundColor': '#CBE0DC',
            'iconBackgroundColor': '#EEF5F4',
          },
          {
            'label': 'Final Score',
            'value': 60,
            'icon': Icons.emoji_events_outlined,
            'backgroundColor': '#FDE9A2',
            'iconBackgroundColor': '#FFFDF7',
          },
        ],
      }, const Wide2Size()),
    );

    expect(find.text('Achieved'), findsOneWidget);
    expect(find.text('Final Score'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('周期分数仪表卡片支持周期切换', (tester) async {
    await _pumpCard(
      tester,
      PeriodScoreGaugeCardWidget.fromProps({
        'periods': [
          {'label': 'Weekly', 'score': 200, 'progress': 0.35},
          {'label': 'Month', 'score': 480, 'progress': 0.65},
          {'label': 'Year', 'score': 920, 'progress': 0.9},
        ],
      }, const Large3Size()),
    );

    expect(find.text('200'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('score-period-1')));
    await tester.pumpAndSettle();
    expect(find.text('480'), findsOneWidget);
    expect(find.text('200'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('月度胶囊图表卡片渲染月度数据', (tester) async {
    await _pumpCard(
      tester,
      MonthlyCapsuleChartCardWidget.fromProps({
        'items': [
          {
            'label': 'May',
            'value': 23,
            'unit': 'lessons',
            'badge': 70,
            'progress': 0.41,
            'color': '#F1DD99',
          },
          {
            'label': 'June',
            'value': 44,
            'unit': 'lessons',
            'badge': 100,
            'progress': 0.77,
            'color': '#C7B3E8',
          },
          {
            'label': 'July',
            'value': 14,
            'unit': 'lessons',
            'badge': 50,
            'progress': 0.56,
            'color': '#CFE1DE',
          },
        ],
      }, const Large3Size()),
    );

    expect(find.text('May'), findsOneWidget);
    expect(find.text('June'), findsOneWidget);
    expect(find.text('July'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: card)),
    ),
  );
  await tester.pumpAndSettle();
}
