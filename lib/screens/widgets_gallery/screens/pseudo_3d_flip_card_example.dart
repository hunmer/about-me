import 'package:aboutme/widgets/pseudo_3d_flip_card.dart';
import 'package:flutter/material.dart';

/// 图片伪3D翻转卡片示例页（移植自 3d.html 演示）
class Pseudo3DFlipCardExample extends StatefulWidget {
  const Pseudo3DFlipCardExample({super.key});

  @override
  State<Pseudo3DFlipCardExample> createState() =>
      _Pseudo3DFlipCardExampleState();
}

class _Pseudo3DFlipCardExampleState extends State<Pseudo3DFlipCardExample> {
  final _cardKey = GlobalKey<Pseudo3DFlipCardState>();

  Pseudo3DMode _mode = Pseudo3DMode.interactive;
  double _thickness = 16;
  double _maxTilt = 32;
  double _perspective = 900;
  bool _glareEnabled = true;
  bool _embossBack = true;
  double _poseX = 0;
  double _poseY = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('图片伪3D翻转效果'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 模式切换
            SegmentedButton<Pseudo3DMode>(
              segments: const [
                ButtonSegment(
                  value: Pseudo3DMode.interactive,
                  label: Text('鼠标跟随+点击翻转', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: Pseudo3DMode.spin360,
                  label: Text('360°旋转', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: Pseudo3DMode.wobble,
                  label: Text('悬浮摇摆', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 8),

            // 伪3D舞台
            Pseudo3DFlipCard(
              key: _cardKey,
              image: const AssetImage('assets/achievements/A14.webp'),
              thickness: _thickness.round(),
              maxTilt: _maxTilt,
              perspective: _perspective,
              glareEnabled: _glareEnabled,
              embossBack: _embossBack,
              mode: _mode,
              onRequestInteractiveMode: () =>
                  setState(() => _mode = Pseudo3DMode.interactive),
              onPoseChanged: (x, y) => setState(() {
                _poseX = x;
                _poseY = y;
              }),
            ),
            const SizedBox(height: 8),

            // 快捷翻转控制与姿态读数
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    _darkButton('↔ 水平翻转180°', () => _cardKey.currentState?.flipY()),
                    _darkButton('↕ 垂直翻转180°', () => _cardKey.currentState?.flipX()),
                    _darkButton('复位姿态', () => _cardKey.currentState?.resetPose()),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF020617),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Text(
                    'X: ${_poseX.round()}° | Y: ${_poseY.round()}° | 厚度: ${_thickness.round()}px',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Color(0xFF1E293B)),

            // 参数精调
            _buildSlider(
              label: '立体边缘厚度 (Z轴堆叠层)',
              value: _thickness,
              min: 0,
              max: 32,
              divisions: 16,
              display: '${_thickness.round()} px (${_thickness.round()}层)',
              onChanged: (v) => setState(() => _thickness = v),
            ),
            _buildSlider(
              label: '鼠标跟随最大倾角',
              value: _maxTilt,
              min: 10,
              max: 65,
              display: '${_maxTilt.round()}°',
              onChanged: (v) => setState(() => _maxTilt = v),
            ),
            _buildSlider(
              label: '3D 透视景深 (Perspective)',
              value: _perspective,
              min: 400,
              max: 1800,
              display: '${_perspective.round()} px',
              onChanged: (v) => setState(() => _perspective = v),
            ),

            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    title: const Text('动态流光高光',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                    value: _glareEnabled,
                    onChanged: (v) => setState(() => _glareEnabled = v),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    dense: true,
                    title: const Text('背面浮雕暗纹',
                        style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                    value: _embossBack,
                    onChanged: (v) => setState(() => _embossBack = v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE2E8F0),
        side: const BorderSide(color: Color(0xFF334155)),
        backgroundColor: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
            Text(display,
                style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 13,
                    fontFamily: 'monospace')),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
