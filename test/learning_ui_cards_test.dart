import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cutout_stat_grid_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/gradient_progress_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/illustrated_metric_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/striped_weekly_chart_card.dart';

void main() {
  testWidgets('插画指标卡片解析并展示数据', (tester) async {
    await _pumpCard(
      tester,
      IllustratedMetricCardWidget.fromProps({
        'title': 'Learning Units',
        'value': 12,
        'unit': 'lessons',
        'icon': Icons.auto_stories_rounded,
        'backgroundColor': '#CBC0EB',
        'illustrationBackgroundColor': '#F7EBC4',
        'iconColor': '#1E40AF',
      }, const WideSize()),
    );

    expect(find.text('Learning Units'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('lessons'), findsOneWidget);
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切角统计网格卡片解析并展示全部条目', (tester) async {
    await _pumpCard(
      tester,
      CutoutStatGridCardWidget.fromProps({
        'title': 'Learning Plan',
        'items': [
          {
            'label': 'My\nClasses',
            'value': 40,
            'unit': 'Total',
            'icon': Icons.school_rounded,
            'backgroundColor': '#DF82F9',
            'iconBackgroundColor': '#D395E5',
          },
          {
            'label': 'My\nLessons',
            'value': 12,
            'unit': 'Total',
            'icon': Icons.auto_stories_rounded,
            'backgroundColor': '#C8B9EC',
            'iconBackgroundColor': '#CCC0EC',
          },
          {
            'label': 'Class\nSchedule',
            'value': 32,
            'unit': 'Total',
            'icon': Icons.calendar_month_rounded,
            'backgroundColor': '#FAEBA6',
            'iconBackgroundColor': '#F5E7AD',
          },
        ],
      }, const Wide2Size()),
    );

    expect(find.text('Learning Plan'), findsOneWidget);
    expect(find.text('My\nClasses'), findsOneWidget);
    expect(find.text('My\nLessons'), findsOneWidget);
    expect(find.text('Class\nSchedule'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('渐变进度卡片支持拖动更新百分比', (tester) async {
    await _pumpCard(
      tester,
      GradientProgressCardWidget.fromProps({
        'title': 'Average Progress',
        'label': 'Progress',
        'progress': 0.78,
        'icon': Icons.settings_suggest_rounded,
        'accentColor': '#DF92F7',
      }, const WideSize()),
    );

    expect(find.text('78%'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('gradient-progress-track')),
      const Offset(1000, 0),
    );
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('斜线周图表支持选中柱形并切换提示', (tester) async {
    await _pumpCard(
      tester,
      StripedWeeklyChartCardWidget.fromProps({
        'title': 'Progress Learning',
        'subtitle': '04hr54min',
        'initialSelectedIndex': 4,
        'items': [
          {'label': 'Sun', 'value': 2.8, 'valueLabel': '2,8hr'},
          {'label': 'Mon', 'value': 1.9, 'valueLabel': '1,9hr'},
          {'label': 'Tue', 'value': 3.1, 'valueLabel': '3,1hr'},
          {'label': 'Wed', 'value': 3.6, 'valueLabel': '3,6hr'},
          {'label': 'Thr', 'value': 4.5, 'valueLabel': '4,5hr'},
          {'label': 'Fri', 'value': 3.0, 'valueLabel': '3,0hr'},
          {'label': 'Sat', 'value': 1.8, 'valueLabel': '1,8hr'},
        ],
      }, const Wide2Size()),
    );

    expect(find.text('4,5hr'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('striped-weekly-bar-2')));
    await tester.pump();

    expect(find.text('3,1hr'), findsOneWidget);
    expect(find.text('4,5hr'), findsNothing);
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
