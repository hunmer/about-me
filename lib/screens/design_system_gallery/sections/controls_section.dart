import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 02 选择控件：复选框（三态）/ 单选框 / 开关
class ControlsSection extends StatefulWidget {
  const ControlsSection({super.key});

  @override
  State<ControlsSection> createState() => _ControlsSectionState();
}

class _ControlsSectionState extends State<ControlsSection> {
  bool? _checkbox = true;
  bool? _tristate;
  int _radio = 2;
  bool _switchOn = true;
  bool _switchOff = false;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '02',
      title: '选择控件',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DemoSubHeader('复选框（Checkbox）三态'),
                  DemoFlow(
                    spacing: theme.spacing.sm,
                    children: [
                      DemoBlock(
                        label: '未选中',
                        child: DSCheckbox(
                          value: _checkbox,
                          onChanged: (v) => setState(() => _checkbox = v),
                        ),
                      ),
                      DemoBlock(
                        label: '选中',
                        child: DSCheckbox(
                          value: _checkbox,
                          onChanged: (v) => setState(() => _checkbox = v),
                        ),
                      ),
                      DemoBlock(
                        label: '禁用',
                        child: const DSCheckbox(value: true, onChanged: null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DemoSubHeader('单选框（Radio）'),
                  DemoFlow(
                    spacing: theme.spacing.sm,
                    children: [
                      DemoBlock(
                        label: '未选',
                        child: DSRadio<int>(
                          value: 1,
                          groupValue: _radio,
                          onChanged: (v) => setState(() => _radio = v ?? 1),
                        ),
                      ),
                      DemoBlock(
                        label: '选中',
                        child: DSRadio<int>(
                          value: 2,
                          groupValue: _radio,
                          onChanged: (v) => setState(() => _radio = v ?? 2),
                        ),
                      ),
                      DemoBlock(
                        label: '禁用',
                        child: const DSRadio<int>(
                          value: 3,
                          groupValue: 2,
                          onChanged: null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('开关（Switch）'),
        DemoFlow(
          children: [
            DemoBlock(
              label: '开',
              child: DSSwitch(
                value: _switchOn,
                onChanged: (v) => setState(() => _switchOn = v),
              ),
            ),
            DemoBlock(
              label: '关',
              child: DSSwitch(
                value: _switchOff,
                onChanged: (v) => setState(() => _switchOff = v),
              ),
            ),
            DemoBlock(
              label: '禁用',
              child: const DSSwitch(value: true, onChanged: null),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('半选（Tristate）'),
        DemoFlow(
          children: [
            DemoBlock(
              label: '半选态',
              child: DSCheckbox(
                tristate: true,
                value: _tristate,
                onChanged: (v) => setState(() => _tristate = v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
