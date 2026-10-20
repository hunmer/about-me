import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'jelly_box.dart';

/// 手绘分段控件：底盘墨线描边 + 滑动高亮块
class DSSegmentedControl extends StatelessWidget {
  const DSSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final disabled = onChanged == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / options.length;

        return Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          // 手绘底盘：淡紫实底 + 墨线胶囊描边
          decoration: dsSketchDecoration(
            theme: theme,
            radius: theme.radii.pill,
            fillColor: theme.surfaceAlt,
          ),
          child: Stack(
            children: [
              // 滑动高亮块（selected < 0 表示无选中，隐藏）
              if (selected >= 0)
                AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  -1 +
                      2 *
                          (selected /
                              (options.length - 1 == 0
                                  ? 1
                                  : options.length - 1)),
                  0,
                ),
                child: SizedBox(
                  width: itemWidth,
                  child: JellyBox(
                    height: double.infinity,
                    radius: theme.radii.pill,
                    color: disabled ? theme.disabled : theme.primary,
                  ),
                ),
              ),
              // 选项层
              Row(
                children: [
                  for (var i = 0; i < options.length; i++)
                    SizedBox(
                      width: itemWidth,
                      child: Pressable(
                        onPressed: disabled ? null : () => onChanged?.call(i),
                        builder: (context, states) => Center(
                          child: Text(
                            options[i],
                            maxLines: 1,
                            style: DsTypography.button.copyWith(
                              fontSize: 14,
                              color: i == selected
                                  ? (disabled ? theme.surface : theme.onPrimary)
                                  : theme.textSub,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
