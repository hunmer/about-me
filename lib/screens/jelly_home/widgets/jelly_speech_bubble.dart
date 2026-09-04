import 'package:flutter/widgets.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';

/// 角色头顶的对话气泡：白色胶囊 + 下垂小尾巴
class JellySpeechBubble extends StatelessWidget {
  const JellySpeechBubble({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    final bubble = JellyBox(
      radius: theme.radii.pill,
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.xl,
        vertical: theme.spacing.md,
      ),
      // 白表面 + 浅紫描边，突出「云朵感」
      strokeColor: theme.primary.withValues(alpha: 0.30),
      child: Text(
        text,
        style: DsTypography.button.copyWith(
          fontSize: 15,
          color: theme.primaryText,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        onTap == null
            ? bubble
            : Pressable(
              onPressed: onTap,
              builder:
                  (context, states) =>
                      states.contains(WidgetState.pressed)
                          ? Opacity(opacity: 0.85, child: bubble)
                          : bubble,
            ),
        // 气泡尾巴：指向下方角色
        CustomPaint(
          size: const Size(26, 13),
          painter: _BubbleTailPainter(
            fill: theme.surface,
            line: theme.primary.withValues(alpha: 0.30),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.fill, required this.line});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final path =
        Path()
          ..moveTo(size.width * 0.08, 0)
          ..quadraticBezierTo(
            size.width * 0.30,
            size.height * 0.55,
            size.width * 0.46,
            size.height,
          )
          ..quadraticBezierTo(
            size.width * 0.62,
            size.height * 0.5,
            size.width * 0.92,
            0,
          )
          ..close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.fill != fill || old.line != line;
}
