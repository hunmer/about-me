import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/petal_radial_chart_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 花瓣径向统计卡片示例
class PetalRadialChartCardExample extends StatelessWidget {
  const PetalRadialChartCardExample({super.key});

  /// 深色模式配色（参考效果图）
  static const _darkItems = [
    PetalChartItemData(label: 'Happiness', value: 12, color: Color(0xFFF5F2EF)),
    PetalChartItemData(label: 'Awe', value: 10, color: Color(0xFFE6E2F2)),
    PetalChartItemData(label: 'Admiration', value: 5, color: Color(0xFFF2E4E9)),
    PetalChartItemData(label: 'Surprise', value: 12, color: Color(0xFFE9E4F4)),
    PetalChartItemData(label: 'Sadness', value: 6, color: Color(0xFFEAE6F6)),
    PetalChartItemData(label: 'Fear', value: 4, color: Color(0xFFEFEDE8)),
    PetalChartItemData(label: 'Anger', value: 2, color: Color(0xFFF5F2EF)),
    PetalChartItemData(label: 'Anticipation', value: 5, color: Color(0xFFF0EDE8)),
  ];

  /// 浅色模式配色（柔和 pastel）
  static const _lightItems = [
    PetalChartItemData(label: 'Happiness', value: 12, color: Color(0xFFF7C873)),
    PetalChartItemData(label: 'Awe', value: 10, color: Color(0xFFB8A9E8)),
    PetalChartItemData(label: 'Admiration', value: 5, color: Color(0xFFF0A9C0)),
    PetalChartItemData(label: 'Surprise', value: 12, color: Color(0xFFA9BCF5)),
    PetalChartItemData(label: 'Sadness', value: 6, color: Color(0xFF9FB6E8)),
    PetalChartItemData(label: 'Fear', value: 4, color: Color(0xFFC9C0B2)),
    PetalChartItemData(label: 'Anger', value: 2, color: Color(0xFFE8A58F)),
    PetalChartItemData(label: 'Anticipation', value: 5, color: Color(0xFFF5D76E)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = isDark ? _darkItems : _lightItems;

    return Scaffold(
      appBar: AppBar(title: const Text('花瓣径向统计卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('小尺寸（仅花瓣）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: PetalRadialChartCardWidget(
                      items: items,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 170,
                    child: PetalRadialChartCardWidget(
                      items: items,
                      size: const MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大尺寸（参考效果图）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 380,
                    child: PetalRadialChartCardWidget(
                      items: items,
                      size: const Large3Size(),
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
