import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/semicircle_gauge_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 半圆仪表盘统计卡片示例
class SemicircleGaugeCardExample extends StatelessWidget {
  const SemicircleGaugeCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('半圆仪表盘统计卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('中尺寸（参考效果图 1250/1600 kcal）'),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 384,
                    height: 190,
                    child: SemicircleGaugeCardWidget(
                      value: 1250,
                      maxValue: 1600,
                      hatchedValue: 1433,
                      unit: 'kcal',
                      size: MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸'),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 384,
                    height: 430,
                    child: SemicircleGaugeCardWidget(
                      value: 1250,
                      maxValue: 1600,
                      hatchedValue: 1433,
                      unit: 'kcal',
                      size: Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('无斜纹段（仅进度 + 剩余）'),
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 384,
                    height: 190,
                    child: SemicircleGaugeCardWidget(
                      value: 68,
                      maxValue: 100,
                      unit: '%',
                      backgroundColor: Color(0xFF7C5CFF),
                      size: MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('可交互（拖拽指针调节，双击重置）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 190,
                    child: _InteractiveDemo(),
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

/// 可交互演示（拖拽更新数值）
class _InteractiveDemo extends StatefulWidget {
  @override
  State<_InteractiveDemo> createState() => _InteractiveDemoState();
}

class _InteractiveDemoState extends State<_InteractiveDemo> {
  double _value = 1250;

  @override
  Widget build(BuildContext context) {
    return SemicircleGaugeCardWidget(
      value: _value,
      maxValue: 1600,
      hatchedValue: 1433,
      unit: 'kcal',
      interactive: true,
      onChanged: (v) => setState(() => _value = v),
      size: const MediumSize(),
    );
  }
}
