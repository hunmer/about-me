import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻数字步进器：[−] 数值 [+]
class DSStepper extends StatelessWidget {
  const DSStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final disabled = onChanged == null;
    final canMinus = !disabled && value - step >= min;
    final canPlus = !disabled && value + step <= max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DSIconButton(
          icon: DsIconKind.minus,
          onPressed: canMinus ? () => onChanged?.call(value - step) : null,
          size: 38,
        ),
        SizedBox(width: theme.spacing.sm),
        JellyBox(
          width: 64,
          height: 38,
          radius: theme.radii.pill,
          alignment: Alignment.center,
          raised: false,
          child: Text(
            '$value',
            style: DsTypography.heading.copyWith(color: theme.text),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        DSIconButton(
          icon: DsIconKind.plus,
          onPressed: canPlus ? () => onChanged?.call(value + step) : null,
          size: 38,
        ),
      ],
    );
  }
}
