import 'package:aboutme/widgets/lucky_wheel.dart';
import 'package:flutter/material.dart';

/// 时计幸运转盘示例页
class LuckyWheelExample extends StatelessWidget {
  const LuckyWheelExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F6F2),
      body: SafeArea(child: LuckyWheel()),
    );
  }
}
