import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/health_score_ring_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 健康分数环形统计卡片示例
class HealthScoreRingCardExample extends StatelessWidget {
  const HealthScoreRingCardExample({super.key});

  static const _items = [
    HealthRingItemData(
      label: 'Endocrine system',
      icon: Icons.science_outlined,
      color: Color(0xFFF2CE5F),
      score: 8.3,
      value: 1,
    ),
    HealthRingItemData(
      label: 'Immune system',
      icon: Icons.shield_outlined,
      color: Color(0xFFA9BC69),
      score: 7.5,
      value: 1,
    ),
    HealthRingItemData(
      label: 'Cardiovascular',
      icon: Icons.favorite_border,
      color: Color(0xFFEFA9D9),
      score: 9.1,
      value: 1,
    ),
    HealthRingItemData(
      label: 'Nervous system',
      icon: Icons.psychology_outlined,
      color: Color(0xFF9FB6E8),
      score: 8.8,
      value: 1,
    ),
    HealthRingItemData(
      label: 'Musculoskeletal',
      icon: Icons.directions_run,
      color: Color(0xFFC0C96A),
      score: 7.9,
      value: 1,
    ),
    HealthRingItemData(
      label: 'Digestive system',
      icon: Icons.restaurant,
      color: Color(0xFFF5D98B),
      score: 8.5,
      value: 1,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('健康分数环形统计卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('小尺寸（仅圆环）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: HealthScoreRingCardWidget(
                      score: 8.8,
                      items: _items,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸（横排）'),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 384,
                    height: 170,
                    child: HealthScoreRingCardWidget(
                      score: 8.8,
                      title: 'Health systems',
                      filterLabel: 'All',
                      items: _items,
                      size: MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸（参考效果图）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: const HealthScoreRingCardWidget(
                      score: 8.8,
                      scoreLabel: 'your health score',
                      title: 'Health systems',
                      filterLabel: 'All',
                      items: _items,
                      size: Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大宽尺寸（横排）'),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 384,
                    height: 330,
                    child: HealthScoreRingCardWidget(
                      score: 8.8,
                      scoreLabel: 'your health score',
                      title: 'Health systems',
                      filterLabel: 'All',
                      items: _items,
                      size: Wide2Size(),
                    ),
                  ),
                ),
              ],
            ),
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
