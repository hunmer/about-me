import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

class ColorPickerSection extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerSection({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    // 定义常用颜色列表
    final List<Color> commonColors = [
      Colors.grey,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app_nodeColor'.tr,
          style: DsTypography.heading.copyWith(color: theme.text),
        ),
        const SizedBox(height: 8),
        // 使用单行水平滚动替代 Wrap
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: commonColors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final color = commonColors[index];
              final isSelected = selectedColor.value == color.value;
              return Pressable(
                onPressed: () => onColorChanged(color),
                builder: (context, states) {
                  final pressed = states.contains(WidgetState.pressed);
                  return AnimatedScale(
                    scale: pressed ? 0.88 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.primary : theme.stroke,
                          width: isSelected ? 2.5 : 1.4,
                        ),
                      ),
                      child:
                          isSelected
                              ? DsIcon(
                                DsIconKind.check,
                                size: 20,
                                // 浅色圆点上用深色对勾，保证对比度
                                color:
                                    color.computeLuminance() > 0.6
                                        ? DsColors.black
                                        : DsColors.white,
                              )
                              : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
