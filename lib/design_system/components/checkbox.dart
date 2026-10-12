import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import 'icons.dart';

/// 手绘复选框（支持三态：未选中 / 选中 / 半选）
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

    // 选中/半选 → 主色实底；未选中 → 纸面 + 淡墨描边；禁用 → 灰
    final Color fill = disabled
        ? theme.disabled
        : (checked || indeterminate ? theme.primary : theme.surface);

    return Pressable(
      onPressed: disabled ? null : _toggle,
      cursor: SystemMouseCursors.click,
      semanticLabel: semanticLabel,
      builder: (context, states) {
        return Semantics(
          checked: checked,
          mixed: indeterminate,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: dsSketchDecoration(
                theme: theme,
                radius: theme.radii.sm,
                fillColor: fill,
                stroke:
                    (checked || indeterminate) && !disabled
                        ? null
                        : theme.textSub.withValues(
                            alpha: disabled ? 0.3 : 0.6,
                          ),
              ),
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
