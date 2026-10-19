import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/cutout_stat_grid_card.dart';

class CutoutStatGridCardExample extends StatelessWidget {
  const CutoutStatGridCardExample({super.key});

  static final _items = [
    CutoutStatItemData(
      label: 'My\nClasses',
      value: '40',
      unit: 'Total',
      icon: Icons.school_rounded,
      backgroundColor: const Color(0xFFDF82F9),
      iconBackgroundColor: const Color(0xFFD395E5),
      iconColor: const Color(0xFF2E1F27),
    ),
    CutoutStatItemData(
      label: 'My\nLessons',
      value: '12',
      unit: 'Total',
      icon: Icons.auto_stories_rounded,
      backgroundColor: const Color(0xFFC8B9EC),
      iconBackgroundColor: const Color(0xFFCCC0EC),
      iconColor: const Color(0xFF475569),
    ),
    CutoutStatItemData(
      label: 'Class\nSchedule',
      value: '32',
      unit: 'Total',
      icon: Icons.calendar_month_rounded,
      backgroundColor: const Color(0xFFFAEBA6),
      iconBackgroundColor: const Color(0xFFF5E7AD),
      iconColor: const Color(0xFF3B82F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('切角统计网格卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('全宽尺寸（参考效果图）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 240,
                  child: CutoutStatGridCardWidget(
                    title: 'Learning Plan',
                    items: _items,
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
                  height: 340,
                  child: CutoutStatGridCardWidget(
                    title: 'Learning Plan',
                    items: _items,
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
