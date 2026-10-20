import 'package:aboutme/widgets/swatch_camera_frame.dart';
import 'package:flutter/material.dart';

/// Swatch 3D 相机相框示例（可切换相机背面 原始 / 9:16 / 16:9 三种比例样式）
class SwatchCameraFrameExample extends StatefulWidget {
  const SwatchCameraFrameExample({super.key});

  @override
  State<SwatchCameraFrameExample> createState() =>
      _SwatchCameraFrameExampleState();
}

class _SwatchCameraFrameExampleState extends State<SwatchCameraFrameExample> {
  SwatchFrameRatio _ratio = SwatchFrameRatio.original;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E3DC),
      appBar: AppBar(
        title: const Text('Swatch 3D 相机相框'),
        backgroundColor: const Color(0xFFE6E3DC),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<SwatchFrameRatio>(
              segments: const [
                ButtonSegment(
                  value: SwatchFrameRatio.original,
                  label: Text('原始'),
                ),
                ButtonSegment(
                  value: SwatchFrameRatio.portrait9x16,
                  label: Text('9:16'),
                ),
                ButtonSegment(
                  value: SwatchFrameRatio.landscape16x9,
                  label: Text('16:9'),
                ),
              ],
              selected: {_ratio},
              onSelectionChanged: (selection) =>
                  setState(() => _ratio = selection.first),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SwatchCameraFrame(
                  key: ValueKey(_ratio),
                  ratio: _ratio,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '切换比例改变相机形态 · 点击相机播放动画 · 奖励态点击任意处返回',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
