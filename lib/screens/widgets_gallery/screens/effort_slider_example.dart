import 'package:aboutme/widgets/effort_slider.dart';
import 'package:flutter/material.dart';

/// Effort 推理强度滑块示例页
class EffortSliderExample extends StatelessWidget {
  const EffortSliderExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('Effort 推理强度滑块'),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
      body: const SafeArea(
        child: Center(child: EffortSlider()),
      ),
    );
  }
}
