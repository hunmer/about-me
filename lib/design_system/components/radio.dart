import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';

/// 手绘单选框
class DSRadio<T> extends StatelessWidget {
  const DSRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.semanticLabel,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final selected = value == groupValue;
    final disabled = onChanged == null;

    // 选中 → 主色实底；未选中 → 纸面 + 淡墨描边；禁用 → 灰
    final Color fill = disabled
        ? theme.disabled
        : selected
            ? theme.primary
            : theme.surface;

    return Pressable(
      onPressed: disabled ? null : () => onChanged?.call(value),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        return Semantics(
          checked: selected,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: dsSketchDecoration(
                theme: theme,
                circle: true,
                fillColor: fill,
                stroke:
                    !selected || disabled
                        ? theme.textSub.withValues(alpha: disabled ? 0.3 : 0.6)
                        : null,
              ),
              child: selected
                  ? Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: disabled ? theme.textSub : theme.onPrimary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
