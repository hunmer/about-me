import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 颜色选择组件
///
/// 功能特性：
/// - 支持预设颜色选择
/// - DS 果冻风格容器与选中对勾
/// - 支持 inline 模式（label在左，颜色选择器在右）
class ColorSelectorField extends StatelessWidget {
  /// 当前选中的颜色
  final Color selectedColor;

  /// 颜色变更回调
  final Function(Color) onColorChanged;

  /// 标签文本
  final String? labelText;

  /// 预设颜色列表
  final List<Color> colors;

  /// 颜色圆点大小
  final double colorSize;

  /// 颜色圆点间距
  final double spacing;

  /// 是否使用inline模式（label在左，颜色选择器在右）
  final bool inline;

  /// inline模式下是否允许水平滚动（单行滚动展示）
  final bool scrollable;

  /// inline模式下label的宽度
  final double labelWidth;

  const ColorSelectorField({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    this.labelText,
    this.colors = const [
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
    ],
    this.colorSize = 36,
    this.spacing = 8,
    this.inline = false,
    this.scrollable = false,
    this.labelWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    Widget swatches({bool scroll = false}) {
      final wrap = Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final color in colors) _buildSwatch(context, color)],
      );
      if (!scroll) return wrap;
      return SizedBox(
        height: colorSize + 6,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: wrap,
        ),
      );
    }

    // inline 模式：label 在左，颜色选择器在右
    if (inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelText != null) ...[
            SizedBox(
              width: labelWidth,
              child: Text(
                labelText!,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
            const SizedBox(height: 8),
          ],
          swatches(scroll: scrollable),
        ],
      );
    }

    // 默认模式：果冻卡片样式
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: DsTypography.body.copyWith(color: theme.text),
          ),
          const SizedBox(height: 8),
        ],
        JellyBox(
          radius: theme.radii.lg,
          padding: EdgeInsets.all(theme.spacing.md),
          child: swatches(),
        ),
      ],
    );
  }

  /// 单个颜色圆点：选中时描边 + 对勾
  Widget _buildSwatch(BuildContext context, Color color) {
    final theme = DSThemeBridge.resolve(context);
    final isSelected = selectedColor.value == color.value;

    return Pressable(
      onPressed: () => onColorChanged(color),
      semanticLabel:
          '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: colorSize,
            height: colorSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.primary : theme.stroke,
                width: isSelected ? 2.5 : 1.4,
              ),
              boxShadow: isSelected ? theme.shadows.soft : null,
            ),
            child:
                isSelected
                    ? DsIcon(
                      DsIconKind.check,
                      size: colorSize * 0.55,
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
  }
}
