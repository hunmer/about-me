import 'package:aboutme/widgets/moments_nyc_map_demo.dart';
import 'package:flutter/material.dart';

/// Moments 纽约互动地图组件示例页
class MomentsNycMapExample extends StatelessWidget {
  const MomentsNycMapExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moments 纽约地图')),
      body: const MomentsNycMapDemo(),
    );
  }
}
