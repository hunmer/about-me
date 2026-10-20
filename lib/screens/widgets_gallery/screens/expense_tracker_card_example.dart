import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/expense_tracker_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 支出追踪卡片示例
class ExpenseTrackerCardExample extends StatelessWidget {
  const ExpenseTrackerCardExample({super.key});

  static final _categories = [
    ExpenseCategoryData(
      label: 'Transfers',
      icon: Icons.sync_alt,
      color: Color(0xFF6170F8),
    ),
    ExpenseCategoryData(
      label: 'Shopping',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFFEC58F8),
    ),
    ExpenseCategoryData(
      label: 'Food & Beverages',
      icon: Icons.restaurant_outlined,
      color: Color(0xFF32E69C),
    ),
    ExpenseCategoryData(
      label: 'Utility/Bills',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF2AB6F6),
    ),
  ];

  static final _months = [
    ExpenseMonthData(label: 'Sep', amounts: [310, 190, 145, 95]),
    ExpenseMonthData(label: 'Oct', amounts: [360, 280, 120, 90]),
    ExpenseMonthData(label: 'Nov', amounts: [290, 320, 130, 75]),
    ExpenseMonthData(label: 'Dec', amounts: [400, 250, 100, 85]),
    ExpenseMonthData(label: 'Jan', amounts: [450, 180, 115, 110]),
    ExpenseMonthData(label: 'Feb', amounts: [340, 210, 160, 80]),
    ExpenseMonthData(label: 'Mar', amounts: [380, 240, 135, 95]),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('支出追踪卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('参考效果图（完整高度，点击分类行高亮弧段）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 620,
                    child: ExpenseTrackerCardWidget(
                      categories: _categories,
                      months: _months,
                      initialMonthIndex: 3,
                      inline: true,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸（列表可滚动）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: ExpenseTrackerCardWidget(
                      categories: _categories,
                      months: _months,
                      initialMonthIndex: 3,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('单月份（隐藏月份条）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: ExpenseTrackerCardWidget(
                      categories: _categories,
                      months: [
                        ExpenseMonthData(label: 'Dec', amounts: [400, 250, 100, 85]),
                      ],
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（仅弧段仪表）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: ExpenseTrackerCardWidget(
                      categories: _categories,
                      months: _months,
                      initialMonthIndex: 3,
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
