import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 果冻复选框（支持三态：未选中 / 选中 / 半选）
class DSCheckbox extends StatelessWidget {
  const DSCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.semanticLabel,
  });

  /// true 选中；false 未选中；null 半选（需 [tristate]）
  final bool? value;

  /// 为 null 时为禁用态
  final ValueChanged<bool?>? onChanged;

  final bool tristate;
  final String? semanticLabel;

  void _toggle() {
    final next = tristate
        ? switch (value) {
            true => null,
            null => false,
            false => true,
          }
        : !(value ?? false);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final checked = value == true;
    final indeterminate = value == null;
    final disabled = onChanged == null;

    // 选中/半选 → 主色果冻；未选中 → 白表面；禁用 → 灰
    final Color? fill = disabled
        ? theme.disabled
        : (checked || indeterminate ? theme.primary : null);

    return Pressable(
      onPressed: disabled ? null : _toggle,
      cursor: SystemMouseCursors.click,
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Semantics(
          checked: checked,
          mixed: indeterminate,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: JellyBox(
              width: 26,
              height: 26,
              radius: theme.radii.sm,
              color: fill,
              strokeColor: (checked || indeterminate) && !disabled
                  ? null
                  : theme.textSub.withValues(alpha: disabled ? 0.3 : 0.6),
              raised: (checked || indeterminate) && !pressed && !disabled,
              alignment: Alignment.center,
              child: checked
                  ? DsIcon(
                      DsIconKind.check,
                      size: 17,
                      color: disabled ? theme.textSub : theme.onPrimary,
                    )
                  : indeterminate
                      ? DsIcon(
                          DsIconKind.minus,
                          size: 17,
                          color: disabled ? theme.textSub : theme.onPrimary,
                        )
                      : null,
            ),
          ),
        );
      },
    );
  }
}
