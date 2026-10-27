import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/illustrated_metric_card.dart';

class IllustratedMetricCardExample extends StatelessWidget {
  const IllustratedMetricCardExample({super.key});

  static final _learningUnits = IllustratedMetricData(
    title: 'Learning Units',
    value: '12',
    unit: 'lessons',
    icon: Icons.auto_stories_rounded,
    backgroundColor: const Color(0xFFCBC0EB),
    illustrationBackgroundColor: const Color(0xFFF7EBC4),
    iconColor: const Color(0xFF1E40AF),
  );

  static final _studyHours = IllustratedMetricData(
    title: 'Study Hours',
    value: '43',
    unit: 'Hours',
    icon: Icons.alarm_rounded,
    backgroundColor: const Color(0xFFFAEEAB),
    illustrationBackgroundColor: const Color(0xFFCBC0EB),
    iconColor: const Color(0xFF7C52D4),
  );

  // 无插画数据：icon / 颜色均可省略
  static final _focusMinutes = IllustratedMetricData(
    title: 'Focus Minutes',
    value: '96',
    unit: 'min',
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('插画指标卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('宽型尺寸（学习单元）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 170,
                  child: IllustratedMetricCardWidget(
                    data: _learningUnits,
                    size: const WideSize(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 170,
                  child: IllustratedMetricCardWidget(
                    data: _studyHours,
                    size: const WideSize(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('加高尺寸（学习时长）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 240,
                  child: IllustratedMetricCardWidget(
                    data: _studyHours,
                    size: const Wide2Size(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('无插画模式（纯文字，可点击）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 170,
                  child: IllustratedMetricCardWidget(
                    data: _focusMinutes,
                    size: const WideSize(),
                    showIllustration: false,
                    onTap: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('点击了卡片')));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('自定义插画内容'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 170,
                  child: IllustratedMetricCardWidget(
                    data: _studyHours,
                    size: const WideSize(),
                    illustration: const Text(
                      '✏️',
                      style: TextStyle(fontSize: 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('无框模式（无外层纸卡与动作钮）'),
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 384,
                  height: 150,
                  child: IllustratedMetricCardWidget(
                    data: _learningUnits,
                    size: const WideSize(),
                    framed: false,
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
