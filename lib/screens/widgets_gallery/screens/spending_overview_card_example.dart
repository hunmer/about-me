import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/spending_overview_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 支出概览卡片示例
class SpendingOverviewCardExample extends StatelessWidget {
  const SpendingOverviewCardExample({super.key});

  static final _categories3 = [
    SpendingCategoryData(
      label: 'Food',
      icon: Icons.ramen_dining,
      color: Color(0xFFE75C88),
    ),
    SpendingCategoryData(
      label: 'Housing',
      icon: Icons.apartment,
      color: Color(0xFF5B50E6),
    ),
    SpendingCategoryData(
      label: 'Other',
      icon: Icons.bubble_chart_outlined,
      color: Color(0xFF60BE36),
    ),
  ];

  static final _periods3 = [
    SpendingPeriodData(
      label: 'This month',
      total: 3480.00,
      trendText: '5.1%',
      amounts: [748.00, 3480.00, 696.00],
    ),
    SpendingPeriodData(
      label: 'Last month',
      total: 3310.00,
      trendText: '3.4%',
      amounts: [927.00, 1721.00, 662.00],
    ),
  ];

  static final _categories5 = [
    SpendingCategoryData(
      label: 'Food',
      icon: Icons.ramen_dining,
      color: Color(0xFFE75C88),
    ),
    SpendingCategoryData(
      label: 'Housing',
      icon: Icons.apartment,
      color: Color(0xFF5B50E6),
    ),
    SpendingCategoryData(
      label: 'Transport',
      icon: Icons.directions_car_filled_outlined,
      color: Color(0xFFF2A93B),
    ),
    SpendingCategoryData(
      label: 'Shopping',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFF2AB6F6),
    ),
    SpendingCategoryData(
      label: 'Other',
      icon: Icons.bubble_chart_outlined,
      color: Color(0xFF60BE36),
    ),
  ];

  static final _periods5 = [
    SpendingPeriodData(
      label: 'This month',
      total: 4230.00,
      trendText: '6.8%',
      amounts: [860.00, 1500.00, 420.00, 980.00, 470.00],
    ),
    SpendingPeriodData(
      label: 'Last month',
      total: 3980.00,
      trendText: '2.9%',
      trendUp: false,
      amounts: [790.00, 1500.00, 380.00, 820.00, 490.00],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('支出概览卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('参考效果图（3 分类，点击分类行高亮扇区）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 374,
                    child: SpendingOverviewCardWidget(
                      categories: _categories3,
                      periods: _periods3,
                      inline: true,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('5 分类（超过 3 类自动扩展）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: SpendingOverviewCardWidget(
                      categories: _categories5,
                      periods: _periods5,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（仅甜甜圈图）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: SpendingOverviewCardWidget(
                      categories: _categories3,
                      periods: _periods3,
                      size: const SmallSize(),
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
