import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/widgets/gradient_progress_card.dart';

class GradientProgressCardExample extends StatelessWidget {
  const GradientProgressCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('渐变进度卡片')),
      body: Container(
        color: isDark ? Colors.black : const Color(0xFFF2F2F7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('宽型尺寸（可拖动）'),
              const SizedBox(height: 8),
              const Center(
                child: SizedBox(
                  width: 384,
                  height: 180,
                  child: GradientProgressCardWidget(
                    title: 'Average Progress',
                    label: 'Progress',
                    progress: 0.78,
                    icon: Icons.settings_suggest_rounded,
                    size: WideSize(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('加高尺寸'),
              const SizedBox(height: 8),
              const Center(
                child: SizedBox(
                  width: 384,
                  height: 240,
                  child: GradientProgressCardWidget(
                    title: 'Average Progress',
                    label: 'Progress',
                    progress: 0.56,
                    icon: Icons.settings_suggest_rounded,
                    size: Wide2Size(),
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
