import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 果冻标签页：文字 + 底部滑动果冻指示条
class DSTabs extends StatelessWidget {
  const DSTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final disabled = onChanged == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Pressable(
                  onPressed: disabled ? null : () => onChanged!(i),
                  semanticLabel: labels[i],
                  builder: (context, states) {
                    final hovered = states.contains(WidgetState.hovered);
                    final active = i == selected;
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: theme.spacing.sm + 2,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: DsTypography.button.copyWith(
                            fontSize: 14,
                            color: active
                                ? theme.primaryText
                                : theme.textSub.withValues(
                                    alpha: hovered ? 0.9 : 0.75),
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        // 滑动果冻指示条
        SizedBox(
          height: 5,
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              labels.length <= 1
                  ? -1
                  : -1 + 2 * (selected / (labels.length - 1)),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 5,
                margin: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    theme.primary,
                    theme.secondary,
                  ]),
                  borderRadius: theme.radii.pill,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
