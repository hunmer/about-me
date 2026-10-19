import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/striped_weekly_chart_card.dart';

class StripedWeeklyChartCardExample extends StatelessWidget {
  const StripedWeeklyChartCardExample({super.key});

  static final _items = [
    StripedWeeklyBarData(label: 'Sun', value: 2.8, valueLabel: '2,8hr'),
    StripedWeeklyBarData(label: 'Mon', value: 1.9, valueLabel: '1,9hr'),
    StripedWeeklyBarData(label: 'Tue', value: 3.1, valueLabel: '3,1hr'),
    StripedWeeklyBarData(label: 'Wed', value: 3.6, valueLabel: '3,6hr'),
    StripedWeeklyBarData(label: 'Thr', value: 4.5, valueLabel: '4,5hr'),
    StripedWeeklyBarData(label: 'Fri', value: 3.0, valueLabel: '3,0hr'),
    StripedWeeklyBarData(label: 'Sat', value: 1.8, valueLabel: '1,8hr'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('斜线周图表卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('全宽尺寸（点击柱形切换）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 330,
                  child: StripedWeeklyChartCardWidget(
                    title: 'Progress Learning',
                    subtitle: '04hr54min',
                    items: _items,
                    initialSelectedIndex: 4,
                    size: const Wide2Size(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('大高尺寸'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 430,
                  child: StripedWeeklyChartCardWidget(
                    title: 'Progress Learning',
                    subtitle: '04hr54min',
                    items: _items,
                    initialSelectedIndex: 2,
                    size: const Large3Size(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }
}
