import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

import 'gallery_section.dart';

/// 04 选择器与滑杆
class PickersSection extends StatefulWidget {
  const PickersSection({super.key});

  @override
  State<PickersSection> createState() => _PickersSectionState();
}

class _PickersSectionState extends State<PickersSection> {
  final List<String> _selectOptions = const ['选项一', '选项二', '选项三', '选项四'];
  String? _selected = '选项三';
  DateTime? _pickedDay = DateTime(2024, 5, 15);
  double _slider = 0.75;
  int _segment = 1;
  final Set<String> _chips = {'默认标签'};

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SectionCard(
      index: '04',
      title: '选择器与滑杆',
      children: [
        Wrap(
          spacing: theme.spacing.xl,
          runSpacing: theme.spacing.lg,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('下拉选择框（收起态 → 展开态）'),
                DSSelect<String>(
                  width: 200,
                  hint: '请选择',
                  value: _selected,
                  items: [
                    for (final option in _selectOptions)
                      DSSelectItem(label: option, value: option),
                  ],
                  onChanged: (v) => setState(() => _selected = v),
                ),
                SizedBox(height: theme.spacing.md),
                const DemoSubHeader('分段控件（Segmented Control）'),
                DSSegmentedControl(
                  options: const ['日', '周', '月'],
                  selected: _segment,
                  onChanged: (i) => setState(() => _segment = i),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const DemoSubHeader('日期选择器（月历）'),
                DSCard(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: DSDatePicker(
                    value: _pickedDay,
                    onChanged: (d) => setState(() => _pickedDay = d),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('滑块（Slider）'),
        DSLinearProgress(
          value: _slider,
          thumb: DsIcon(DsIconKind.star, size: 26, color: theme.warning),
        ),
        SizedBox(height: theme.spacing.sm),
        DSSlider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
        SizedBox(height: theme.spacing.lg),
        const DemoSubHeader('标签组（Chips）'),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: [
            DSChip(
              label: '默认标签',
              selected: _chips.contains('默认标签'),
              onSelected:
                  (v) => setState(
                    () => v ? _chips.add('默认标签') : _chips.remove('默认标签'),
                  ),
            ),
            DSChip(
              label: '选中标签',
              selected: _chips.contains('选中标签'),
              onSelected:
                  (v) => setState(
                    () => v ? _chips.add('选中标签') : _chips.remove('选中标签'),
                  ),
            ),
            DSChip(
              label: '可删除',
              selected: false,
              onDeleted:
                  () => showDSToast(
                    context,
                    message: '标签已删除',
                    type: DSToastType.info,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
