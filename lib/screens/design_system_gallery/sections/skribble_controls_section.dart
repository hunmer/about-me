import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import 'gallery_section.dart';

/// skribble 原生组件示例 · 控件
///
/// 展示 skribble 自带的 Wired* 手绘控件（按钮/开关/滑块家族）。
/// 注意：业务页面仍应优先使用 design_system 的 DS* 组件；
/// 本区仅供对照与评估 skribble 能力。
class SkribbleControlsSection extends StatefulWidget {
  const SkribbleControlsSection({super.key});

  @override
  State<SkribbleControlsSection> createState() =>
      _SkribbleControlsSectionState();
}

class _SkribbleControlsSectionState extends State<SkribbleControlsSection> {
  bool _switch = true;
  bool _toggle = false;
  double _slider = 0.6;
  RangeValues _range = const RangeValues(0.2, 0.8);
  int _toggleBtnIndex = 0;
  Set<String> _segment = {'a'};
  int _cupertinoSeg = 0;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      index: 'SK-1',
      title: 'skribble 按钮开关',
      children: [
        const DemoBlock(
          label: 'WiredButton 家族 + IconButton/FAB',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              WiredButton(onPressed: null, child: Text('Button')),
              WiredFilledButton(onPressed: null, child: Text('Filled')),
              WiredElevatedButton(onPressed: null, child: Text('Elevated')),
              WiredOutlinedButton(onPressed: null, child: Text('Outlined')),
              WiredTextButton(onPressed: null, child: Text('Text')),
              WiredIconButton(onPressed: null, icon: Icons.favorite),
              WiredFloatingActionButton(onPressed: null, icon: Icons.add),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredToggleButtons / WiredSegmentedButton',
          child: Column(
            children: [
              WiredToggleButtons(
                isSelected: [
                  _toggleBtnIndex == 0,
                  _toggleBtnIndex == 1,
                  _toggleBtnIndex == 2,
                ],
                onPressed: (i) => setState(() => _toggleBtnIndex = i),
                children: const [Text('红'), Text('黄'), Text('蓝')],
              ),
              const SizedBox(height: 12),
              WiredSegmentedButton<String>(
                segments: const [
                  WiredButtonSegment(value: 'a', label: Text('日')),
                  WiredButtonSegment(value: 'b', label: Text('周')),
                  WiredButtonSegment(value: 'c', label: Text('月')),
                ],
                selected: _segment,
                onSelectionChanged: (v) => setState(() => _segment = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredSwitch / WiredToggle',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WiredSwitch(
                value: _switch,
                onChanged: (v) => setState(() => _switch = v),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 90,
                height: 44,
                child: WiredToggle(
                  value: _toggle,
                  // 注意受控协议：返回 true 表示接受变更
                  onChange: (v) {
                    setState(() => _toggle = v);
                    return true;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredSlider / WiredRangeSlider',
          child: Column(
            children: [
              WiredSlider(
                value: _slider,
                // 受控协议：回调返回 bool
                onChanged: (v) {
                  setState(() => _slider = v);
                  return true;
                },
              ),
              WiredRangeSlider(
                values: _range,
                // 受控协议：回调返回 bool
                onChanged: (v) {
                  setState(() => _range = v);
                  return true;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const DemoBlock(
          label: 'WiredCupertinoButton / SegmentedControl / ActivityIndicator',
          child: Column(
            children: [
              WiredCupertinoButton(
                onPressed: null,
                child: Text('Cupertino Button'),
              ),
              SizedBox(height: 12),
              WiredCupertinoActivityIndicator(radius: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoBlock(
          label: 'WiredCupertinoSegmentedControl',
          child: WiredCupertinoSegmentedControl<int>(
            children: const {
              0: Padding(padding: EdgeInsets.all(8), child: Text('一')),
              1: Padding(padding: EdgeInsets.all(8), child: Text('二')),
            },
            groupValue: _cupertinoSeg,
            onValueChanged: (v) => setState(() => _cupertinoSeg = v),
          ),
        ),
      ],
    );
  }
}
