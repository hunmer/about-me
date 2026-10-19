import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/sparkle_stat_grid_card.dart';

class SparkleStatGridCardExample extends StatelessWidget {
  const SparkleStatGridCardExample({super.key});

  static final _scoreItems = [
    SparkleStatItemData(
      label: 'Achieved',
      value: '12',
      icon: Icons.verified_outlined,
      backgroundColor: const Color(0xFFCBE0DC),
      iconBackgroundColor: const Color(0xFFEEF5F4),
    ),
    SparkleStatItemData(
      label: 'Final Score',
      value: '60',
      icon: Icons.emoji_events_outlined,
      backgroundColor: const Color(0xFFFDE9A2),
      iconBackgroundColor: const Color(0xFFFFFDF7),
    ),
  ];

  static final _studyItems = [
    SparkleStatItemData(
      label: 'Lessons',
      value: '60',
      icon: Icons.menu_book_outlined,
      backgroundColor: const Color(0xFFCBE0DC),
      iconBackgroundColor: const Color(0xFFEEF5F4),
    ),
    SparkleStatItemData(
      label: 'Hours',
      value: '32',
      icon: Icons.alarm_outlined,
      backgroundColor: const Color(0xFFFDE9A2),
      iconBackgroundColor: const Color(0xFFFFFDF7),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('闪光统计网格卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('分数统计'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 220,
                  child: SparkleStatGridCardWidget(
                    items: _scoreItems,
                    size: const Wide2Size(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _title('学习统计'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 220,
                  child: SparkleStatGridCardWidget(
                    items: _studyItems,
                    size: const Wide2Size(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _title('大高尺寸'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 300,
                  child: SparkleStatGridCardWidget(
                    items: _scoreItems,
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

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.grey,
    ),
  );
}
