import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import 'jelly_box.dart';

/// 果冻开关：滑块带表情（开=微笑，关=睡觉）
class DSSwitch extends StatelessWidget {
  const DSSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 开启时轨道颜色，默认取主题辅助色（设计稿中的粉色）
  final Color? activeColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final trackColor = activeColor ?? theme.secondary;

    return Pressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        final disabled = onChanged == null;
        return Semantics(
          toggled: value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 62,
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: value && !disabled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: theme.jellyGradient(trackColor),
                      stops: theme.jellyStops,
                    )
                  : null,
              color: !value || disabled
                  ? (disabled ? theme.disabled : theme.surfaceAlt)
                  : null,
              borderRadius: theme.radii.pill,
              border: Border.all(
                color: value && !disabled
                    ? theme.jellyRim(trackColor)
                    : theme.textSub.withValues(alpha: disabled ? 0.25 : 0.45),
                width: 1.2,
              ),
              boxShadow: value && !disabled
                  ? theme.jellyShadow(trackColor, height: 4)
                  : theme.shadows.soft,
            ),
            // 开启态：轨道叠加水晶玻璃罩
            foregroundDecoration: value && !disabled
                ? JellyGlossDecoration(
                    radius: theme.radii.pill, isDark: theme.isDark)
                : null,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      DsColors.white,
                      theme.isDark ? theme.surfaceAlt : const Color(0xFFF3EDFF),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (value ? trackColor : theme.text)
                          .withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _SwitchFacePainter(
                    happy: value,
                    faceColor: (value ? trackColor : theme.textSub)
                        .mixBlack(0.15),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 滑块表情：开=圆眼+微笑；关=闭眼
class _SwitchFacePainter extends CustomPainter {
  const _SwitchFacePainter({required this.happy, required this.faceColor});

  final bool happy;
  final Color faceColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30);

    final paint = Paint()
      ..color = faceColor
      ..style = PaintingStyle.fill;

    // 两只眼睛
    canvas.drawCircle(const Offset(10, 12.5), happy ? 1.8 : 0, paint);
    canvas.drawCircle(const Offset(20, 12.5), happy ? 1.8 : 0, paint);

    if (happy) {
      // 微笑弧线
      canvas.drawArc(
        const Rect.fromLTRB(9.5, 12, 20.5, 21),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..color = faceColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // 闭眼的两条短弧
      final closed = Paint()
        ..color = faceColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        const Rect.fromLTRB(7.6, 10.4, 12.4, 13.6),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        closed,
      );
      canvas.drawArc(
        const Rect.fromLTRB(17.6, 10.4, 22.4, 13.6),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        closed,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwitchFacePainter oldDelegate) =>
      oldDelegate.happy != happy || oldDelegate.faceColor != faceColor;
}
