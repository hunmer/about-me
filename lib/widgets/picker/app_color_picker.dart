import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 默认预设颜色（常用 Material 色板）
const List<Color> kAppColorPresets = [
  Colors.black,
  Colors.grey,
  Colors.brown,
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.white,
];

/// 自定义颜色选择器：顶部预设颜色 + 下方常规取色器
///
/// 组件内部维护当前颜色，点击预设或拖动取色器都会回调 [onColorChanged]，
/// 外部通过 [selectedColor] 变更时也会同步（如对话框中的预览联动）。
class AppColorPicker extends StatefulWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  /// 顶部预设颜色，默认 [kAppColorPresets]；传空列表可隐藏预设区
  final List<Color>? presets;

  /// 是否启用透明通道
  final bool enableAlpha;

  /// 是否在取色器下方显示 RGB/HSV/HEX 标签
  final bool showLabels;

  const AppColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    this.presets,
    this.enableAlpha = false,
    this.showLabels = false,
  });

  @override
  State<AppColorPicker> createState() => _AppColorPickerState();
}

class _AppColorPickerState extends State<AppColorPicker> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.selectedColor;
  }

  @override
  void didUpdateWidget(covariant AppColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor != widget.selectedColor &&
        widget.selectedColor != _currentColor) {
      _currentColor = widget.selectedColor;
    }
  }

  void _setColor(Color color) {
    setState(() => _currentColor = color);
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final presets = widget.presets ?? kAppColorPresets;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (presets.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in presets)
                GestureDetector(
                  onTap: () => _setColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _currentColor.value == color.value
                            ? theme.primary
                            : theme.stroke,
                        width: _currentColor.value == color.value ? 2.5 : 1.4,
                      ),
                    ),
                    child:
                        _currentColor.value == color.value
                            ? Center(
                              child: DsIcon(
                                DsIconKind.check,
                                size: 20,
                                // 浅色圆点上用深色对勾，保证对比度
                                color:
                                    color.computeLuminance() > 0.6
                                        ? DsColors.black
                                        : DsColors.white,
                              ),
                            )
                            : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        ColorPicker(
          pickerColor: _currentColor,
          onColorChanged: _setColor,
          enableAlpha: widget.enableAlpha,
          displayThumbColor: true,
          showLabel: widget.showLabels,
          labelTypes: const [
            ColorLabelType.rgb,
            ColorLabelType.hsv,
            ColorLabelType.hex,
          ],
          pickerAreaHeightPercent: 0.7,
        ),
      ],
    );
  }
}
