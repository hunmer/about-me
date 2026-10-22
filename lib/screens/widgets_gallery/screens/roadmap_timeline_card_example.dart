import 'package:flutter/material.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/roadmap_timeline_card.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 路线图时间轴卡片示例
class RoadmapTimelineCardExample extends StatelessWidget {
  const RoadmapTimelineCardExample({super.key});

  static final _steps = [
    RoadmapStepData(
      title: 'You are here',
      subtitle: "You've made the greatest decision of your life",
    ),
    RoadmapStepData(
      title: 'Submit docs',
      subtitle: 'Plug your information into free templates!',
    ),
    RoadmapStepData(
      title: 'Reviews docs',
      subtitle: "We'll ensure your application is error free",
    ),
    RoadmapStepData(
      title: 'Submit to Govt.',
      subtitle: 'The embassy reviews your application',
    ),
    RoadmapStepData(
      title: 'Track status',
      subtitle: "We'll always update you on your visa",
    ),
    RoadmapStepData(
      title: 'Get visa on time!',
      subtitle: "You're ready to start packing for your trip!",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('路线图时间轴卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('小尺寸（仅轴线 + 节点 + 标题）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: RoadmapTimelineCardWidget(
                      steps: _steps,
                      currentStep: 3,
                      size: const SmallSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('中尺寸（宽条：标题/S 曲线在左，时间轴在右）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 170,
                    child: RoadmapTimelineCardWidget(
                      steps: _steps,
                      currentStep: 2,
                      size: MediumSize(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸 · 进行中（currentStep = 3）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 440,
                    child: RoadmapTimelineCardWidget(
                      steps: _steps,
                      currentStep: 3,
                      size: Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大高尺寸 · 刚开始（currentStep = 1，自定义数据色）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 440,
                    child: RoadmapTimelineCardWidget(
                      titleLine1: 'The Roadmap to',
                      titleLine2: 'Your Visa',
                      steps: _steps,
                      currentStep: 1,
                      activeColor: Color(0xFF2E9E5B),
                      size: Large3Size(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('大宽尺寸 · 全部完成（currentStep = 6）'),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 384,
                    height: 320,
                    child: RoadmapTimelineCardWidget(
                      steps: _steps,
                      currentStep: 6,
                      activeColor: Color(0xFFE8833A),
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
