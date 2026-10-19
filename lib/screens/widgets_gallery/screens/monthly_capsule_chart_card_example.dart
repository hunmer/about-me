import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/monthly_capsule_chart_card.dart';

class MonthlyCapsuleChartCardExample extends StatelessWidget {
  const MonthlyCapsuleChartCardExample({super.key});

  static final _items = [
    MonthlyCapsuleData(
      label: 'May',
      value: '23',
      unit: 'lessons',
      badge: '70',
      progress: 0.41,
      color: const Color(0xFFF1DD99),
    ),
    MonthlyCapsuleData(
      label: 'June',
      value: '44',
      unit: 'lessons',
      badge: '100',
      progress: 0.77,
      color: const Color(0xFFC7B3E8),
    ),
    MonthlyCapsuleData(
      label: 'July',
      value: '14',
      unit: 'lessons',
      badge: '50',
      progress: 0.56,
      color: const Color(0xFFCFE1DE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('月度胶囊图表卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('大高尺寸（参考效果图）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 430,
                  child: MonthlyCapsuleChartCardWidget(
                    items: _items,
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
                  height: 350,
                  child: MonthlyCapsuleChartCardWidget(
                    items: _items,
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
