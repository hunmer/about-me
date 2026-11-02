import 'package:aboutme/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Home radial bubble panel's real, clickable speech-bubble previews.
class JellyBubbleStylePicker extends StatelessWidget {
  const JellyBubbleStylePicker({
    super.key,
    required this.selectedShape,
    required this.onSelected,
  });

  final DsSpeechBubbleShape selectedShape;
  final ValueChanged<DsSpeechBubbleShape> onSelected;

  static const _shapes = <DsSpeechBubbleShape>[
    DsSpeechBubbleShape.capsule,
    DsSpeechBubbleShape.roundedRectangle,
    DsSpeechBubbleShape.cloud,
    DsSpeechBubbleShape.starburst,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _shapes.length,
        separatorBuilder: (_, _) => SizedBox(width: theme.spacing.sm),
        itemBuilder: (context, index) {
          final shape = _shapes[index];
          final selected = shape == selectedShape;
          final label = _label(shape);
          return Semantics(
            button: true,
            selected: selected,
            label: '气泡样式：$label',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(shape),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 44,
                      child: DsSpeechBubble(
                        shape: shape,
                        fillColor: theme.surface,
                        strokeColor: selected ? theme.primary : theme.ink,
                        strokeWidth: selected ? 2.2 : 1.4,
                        tailHeight: 4,
                        tailWidth: 12,
                        tailXRatio: 0.5,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Center(
                          child: Text(
                            '嗨',
                            maxLines: 1,
                            style: DsTypography.caption.copyWith(
                              color: theme.primaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(
                        color: selected ? theme.primary : theme.textSub,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(DsSpeechBubbleShape shape) => switch (shape) {
    DsSpeechBubbleShape.capsule => '胶囊',
    DsSpeechBubbleShape.roundedRectangle => '圆角',
    DsSpeechBubbleShape.cloud => '云朵',
    DsSpeechBubbleShape.starburst => '星爆',
  };
}
