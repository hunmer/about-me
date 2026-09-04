import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 中部快捷操作：彩色果冻圆钮 + 下方文字（写日记 / 打卡 / 记账）
class JellyQuickAction extends StatelessWidget {
  const JellyQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.size = 60,
    this.onPressed,
  });

  final DsIconKind icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: pressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: JellyBox(
                width: size,
                height: size,
                radius: theme.radii.circle,
                color: color,
                raised: !pressed,
                shadows: pressed ? theme.pressedShadow(color, height: 7) : null,
                alignment: Alignment.center,
                child: DsIcon(icon, size: size * 0.46, color: theme.onPrimary),
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              label,
              style: DsTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.text,
              ),
            ),
          ],
        );
      },
    );
  }
}
