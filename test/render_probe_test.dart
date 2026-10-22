import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/line_chart_trend_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/smooth_line_chart_card.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/striped_weekly_chart_card.dart';

/// 渲染探针：dump 三张卡内所有 CustomPaint / 零尺寸 RenderBox
void main() {
  void dump(RenderObject ro, int depth) {
    if (ro is RenderCustomPaint && ro.painter != null) {
      // ignore: avoid_print
      print('${'  ' * depth}CP ${ro.painter.runtimeType} size=${ro.size}');
    }
    if (ro is RenderBox && (ro.size.width == 0 || ro.size.height == 0)) {
      // ignore: avoid_print
      print('${'  ' * depth}!! ZERO-SIZE ${ro.runtimeType} size=${ro.size}');
    }
    ro.visitChildren((child) => dump(child, depth + 1));
  }

  Future<void> probe(
    WidgetTester tester,
    String name,
    WidgetBuilder builder,
  ) async {
    await tester.pumpWidget(
      DSThemeBridge(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 220, height: 220, child: Builder(builder: builder)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print('==== $name ====');
    dump(tester.renderObject(find.byWidgetPredicate((w) => w is SizedBox && w.width == 220)), 0);
  }

  testWidgets('probe line chart', (tester) async {
    await probe(tester, 'LineChartTrendCard', (context) {
      return LineChartTrendCardWidget(
        size: const MediumSize(),
        value: 2583,
        label: 'Earned',
        changePercent: -5.34,
        dataPoints: const [85, 70, 78, 35, 45, 20, 65],
        unit: r'$',
      );
    });
  });

  testWidgets('probe smooth line', (tester) async {
    await probe(tester, 'SmoothLineChartCard', (context) {
      return SmoothLineChartCardWidget(
        size: const MediumSize(),
        title: 't',
        subtitle: 's',
        date: 'd',
        maxValue: 100,
        dataPoints: const [
          DataPoint(x: 0, y: 10),
          DataPoint(x: 1, y: 40),
          DataPoint(x: 2, y: 80),
        ],
        timeLabels: const ['A', 'B', 'C'],
        primaryColor: const Color(0xFF2196F3),
      );
    });
  });

  testWidgets('probe striped weekly', (tester) async {
    await probe(tester, 'StripedWeeklyChartCard', (context) {
      return StripedWeeklyChartCardWidget(
        size: const Large3Size(),
        title: 't',
        subtitle: 's',
        items: const [
          StripedWeeklyBarData(label: 'M', value: 3, valueLabel: '3'),
          StripedWeeklyBarData(label: 'T', value: 5, valueLabel: '5'),
          StripedWeeklyBarData(label: 'W', value: 2, valueLabel: '2'),
        ],
      );
    });
  });
}
