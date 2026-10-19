import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/period_score_gauge_card.dart';

class PeriodScoreGaugeCardExample extends StatelessWidget {
  const PeriodScoreGaugeCardExample({super.key});

  static final _periods = [
    ScorePeriodData(label: 'Weekly', score: '200', progress: 0.35),
    ScorePeriodData(label: 'Month', score: '480', progress: 0.65),
    ScorePeriodData(label: 'Year', score: '920', progress: 0.9),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('周期分数仪表卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('大高尺寸（点击周期切换）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 430,
                  child: PeriodScoreGaugeCardWidget(
                    periods: _periods,
                    size: const Large3Size(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _title('全宽尺寸'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 360,
                  child: PeriodScoreGaugeCardWidget(
                    periods: _periods,
                    initialSelectedIndex: 1,
                    size: const Wide2Size(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
    ),
  );
}
