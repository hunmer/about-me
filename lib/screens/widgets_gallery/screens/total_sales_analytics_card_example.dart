import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/total_sales_analytics_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 总销售分析卡片示例
class TotalSalesAnalyticsCardExample extends StatelessWidget {
  const TotalSalesAnalyticsCardExample({super.key});

  static final _periods = [
    SalesPeriodData(
      label: 'for all time',
      total: 90744,
      activeIndex: 4,
      bars: [
        SalesBarData(label: 'Feb', value: 8420),
        SalesBarData(label: 'Mar', value: 11350),
        SalesBarData(label: 'Apr', value: 14280),
        SalesBarData(label: 'May', value: 11640),
        SalesBarData(label: 'Jun', value: 16520),
        SalesBarData(label: 'Jul', value: 13410),
        SalesBarData(label: 'Aug', value: 15124),
      ],
    ),
    SalesPeriodData(
      label: 'this year',
      total: 64210,
      activeIndex: 6,
      bars: [
        SalesBarData(label: 'Feb', value: 7120),
        SalesBarData(label: 'Mar', value: 8040),
        SalesBarData(label: 'Apr', value: 9850),
        SalesBarData(label: 'May', value: 10420),
        SalesBarData(label: 'Jun', value: 11900),
        SalesBarData(label: 'Jul', value: 8130),
        SalesBarData(label: 'Aug', value: 14750),
      ],
    ),
    SalesPeriodData(
      label: 'last quarter',
      total: 42890,
      activeIndex: 2,
      bars: [
        SalesBarData(label: 'Feb', value: 6310),
        SalesBarData(label: 'Mar', value: 8920),
        SalesBarData(label: 'Apr', value: 12450),
        SalesBarData(label: 'May', value: 7180),
        SalesBarData(label: 'Jun', value: 5640),
        SalesBarData(label: 'Jul', value: 4890),
        SalesBarData(label: 'Aug', value: 7500),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('总销售分析卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('参考效果图（点柱切换激活，筛选按钮弹周期菜单）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 455,
                    child: TotalSalesAnalyticsCardWidget(
                      periods: _periods,
                      notificationCount: 3,
                      inline: true,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸（默认高度）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: TotalSalesAnalyticsCardWidget(
                      periods: _periods,
                      notificationCount: 3,
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('单周期 + 无通知红点'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: TotalSalesAnalyticsCardWidget(
                      title: 'Revenue',
                      periods: [_periods.first],
                      size: const Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('小尺寸（仅柱状图）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: TotalSalesAnalyticsCardWidget(
                      periods: _periods,
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
