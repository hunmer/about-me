import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import 'jelly_box.dart';

/// 果冻单选框
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

    final Color? fill = disabled
        ? theme.disabled
        : selected
            ? theme.primary
            : null;

    return Pressable(
      onPressed: disabled ? null : () => onChanged?.call(value),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Semantics(
          checked: selected,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: JellyBox(
              width: 26,
              height: 26,
              radius: theme.radii.circle,
              color: fill,
              strokeColor: !selected || disabled
                  ? theme.textSub.withValues(alpha: disabled ? 0.3 : 0.6)
                  : null,
              raised: selected && !pressed && !disabled,
              alignment: Alignment.center,
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
