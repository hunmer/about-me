import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻滑杆：渐变进度 + 星形滑块（对应设计稿）
class DSSlider extends StatefulWidget {
  const DSSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  /// 0.0 ~ 1.0
  final double value;
  final ValueChanged<double>? onChanged;
  final Color? activeColor;

  @override
  State<DSSlider> createState() => _DSSliderState();
}

class _DSSliderState extends State<DSSlider> {
  void _update(double ratio, BoxConstraints constraints) {
    final t = (ratio / constraints.maxWidth).clamp(0.0, 1.0);
    widget.onChanged?.call(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final color = widget.activeColor ?? theme.primary;
    final value = widget.value.clamp(0.0, 1.0);
    final disabled = widget.onChanged == null;

    return Semantics(
      slider: true,
      value: '${(value * 100).round()}%',
      increasedValue:
          '${(((value + 0.1).clamp(0.0, 1.0)) * 100).round()}%',
      decreasedValue:
          '${(((value - 0.1).clamp(0.0, 1.0)) * 100).round()}%',
      onIncrease: disabled
          ? null
          : () => widget.onChanged!((value + 0.1).clamp(0.0, 1.0)),
      onDecrease: disabled
          ? null
          : () => widget.onChanged!((value - 0.1).clamp(0.0, 1.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final starSize = width.clamp(0, 240) * 0.14 + 14;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: disabled
                ? null
                : (d) => _update(d.localPosition.dx, constraints),
            onPanStart: disabled
                ? null
                : (d) => _update(d.localPosition.dx, constraints),
            onPanUpdate: disabled
                ? null
                : (d) => _update(d.localPosition.dx, constraints),
            child: SizedBox(
              height: starSize + 8,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 轨道
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: JellyBox(
                      height: 13,
                      radius: theme.radii.pill,
                      raised: false,
                      color: disabled ? theme.disabled : theme.surfaceAlt,
                    ),
                  ),
                  // 渐变进度（带水晶玻璃罩）
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: theme.radii.pill,
                      child: Container(
                        width: (width - 4) * value + 4,
                        height: 13,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color,
                            theme.secondary,
                          ]),
                        ),
                        foregroundDecoration: JellyGlossDecoration(
                          radius: theme.radii.pill,
                          isDark: theme.isDark,
                        ),
                      ),
                    ),
                  ),
                  // 星形滑块
                  Positioned(
                    left: (width - starSize) * value,
                    bottom: -2,
                    child: DsIcon(
                      DsIconKind.star,
                      size: starSize,
                      color: disabled ? theme.disabled : color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 带百分比标签的滑杆（展示用组合）
class DSSliderWithLabel extends StatelessWidget {
  const DSSliderWithLabel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DSSlider(value: value, onChanged: onChanged),
        SizedBox(height: theme.spacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(value * 100).round()}%',
            style: DsTypography.caption.copyWith(color: theme.textSub),
          ),
        ),
      ],
    );
  }
}
