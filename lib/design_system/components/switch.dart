import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';

/// 手绘开关：滑块带表情（开=微笑，关=睡觉）
///
/// 轨道/滑块为 skribble 墨线描边 + 纯色实底；表情与カチッ挤压动画保留。
/// 切换动画参考 yui540 motions/26「カチッ」（squash & stretch）：
/// 1. 滑块先沿运动方向压扁（scale 1.4×0.75）
/// 2. 冲过终点（位移约 116% 行程，scale 0.85×1.2）
/// 3. 回弹到过冲的反向（位移约 94% 行程，scale 1.08×0.94）
/// 4. 归位；轨道同步做 1.14×0.9 → 0.94×1.08 → 1 的挤压形变
/// 5. 开启后右上方划出两条反馈短线（仅开启时播放一次）
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

  /// 滑块行程：轨道宽 62 - 两侧 padding 3*2 - 滑块 30
  static const double _travel = 26;

  /// カチッ总时长：压扁 120 + 过冲 120 + 回弹 80 + 归位 80
  static const Duration _toggleDuration = Duration(milliseconds: 400);

  /// 轨道挤压总时长：120 + 120 + 100（先于滑块归位，与 CSS 节拍一致）
  static const Duration _trackDuration = Duration(milliseconds: 340);

  static TweenSequenceItem<T> _seg<T>(
    T begin,
    T end,
    Curve curve,
    int weight,
  ) => TweenSequenceItem(
    tween: Tween<T>(begin: begin, end: end).chain(CurveTween(curve: curve)),
    weight: weight.toDouble(),
  );

  /// 滑块位移 keyframes（对应 CSS toggle-knob 的 translate）：
  /// 0 → 37.5% → 116%（过冲）→ 94%（回弹）→ 100% 行程
  static final Animatable<double> _knobDx = TweenSequence<double>([
    _seg(0, _travel * 0.375, Curves.easeIn, 120),
    _seg(_travel * 0.375, _travel * 1.16, Curves.easeOut, 120),
    _seg(_travel * 1.16, _travel * 0.94, Curves.easeInOut, 80),
    _seg(_travel * 0.94, _travel, Curves.easeOut, 80),
  ]);

  /// 滑块形变 keyframes（对应 CSS toggle-knob 的 scale）：
  /// (1,1) → (1.4,0.75) 压扁 → (0.85,1.2) 拉伸 → (1.08,0.94) 回弹 → (1,1)
  static final Animatable<Offset> _knobScale = TweenSequence<Offset>([
    _seg(const Offset(1, 1), const Offset(1.4, 0.75), Curves.easeIn, 120),
    _seg(const Offset(1.4, 0.75), const Offset(0.85, 1.2), Curves.easeOut, 120),
    _seg(
      const Offset(0.85, 1.2),
      const Offset(1.08, 0.94),
      Curves.easeInOut,
      80,
    ),
    _seg(const Offset(1.08, 0.94), const Offset(1, 1), Curves.easeOut, 80),
  ]);

  /// 轨道挤压 keyframes（对应 CSS toggle-bg 的 scale）：
  /// (1,1) → (1.14,0.9) → (0.94,1.08) → (1,1)
  static final Animatable<Offset> _trackScale = TweenSequence<Offset>([
    _seg(const Offset(1, 1), const Offset(1.14, 0.9), Curves.easeIn, 120),
    _seg(
      const Offset(1.14, 0.9),
      const Offset(0.94, 1.08),
      Curves.easeOut,
      120,
    ),
    _seg(const Offset(0.94, 1.08), const Offset(1, 1), Curves.easeOut, 100),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final trackColor = activeColor ?? theme.secondary;
    final disabled = onChanged == null;

    return Pressable(
      onPressed: disabled ? null : () => onChanged!(!value),
      semanticLabel: semanticLabel,
      builder: (context, states) {
        return Semantics(
          toggled: value,
          // 外框 72×54 > 轨道 62×36：顶部与两侧留白给反馈线和轨道挤压形变，
          // 所有绘制都在布局边界内，任何父级裁剪都不会切到动效
          child: SizedBox(
            width: 72,
            height: 54,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 5,
                  bottom: 2,
                  child: _buildTrack(theme, trackColor, disabled)
                      // カチッ：轨道挤压形变（跟随滑块节拍）。
                      // 注意：flutter_animate 同名效果是嵌套叠加而非替换，
                      // 多段 keyframe 必须用单个 custom + TweenSequence 表达。
                      .animate(target: value ? 1 : 0)
                      .custom(
                        duration: _trackDuration,
                        builder: (context, t, child) {
                          final s = _trackScale.transform(t);
                          return Transform.scale(
                            scaleX: s.dx,
                            scaleY: s.dy,
                            child: child,
                          );
                        },
                      ),
                ),
                // カチッ：开启瞬间右上方划过的反馈短线
                Positioned(
                  right: 8,
                  top: 3,
                  child: _KachiLines(
                    color: disabled ? theme.disabled : trackColor.mixWhite(0.3),
                    active: value && !disabled,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrack(AppThemeData theme, Color trackColor, bool disabled) {
    final on = value && !disabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 62,
      height: 36,
      padding: const EdgeInsets.all(3),
      // 手绘轨道：开=activeColor 实底+墨线描边；关=淡紫实底+淡墨描边。
      // RoughBoxDecoration 间无补间，开关切换时直接换装饰
      decoration: dsSketchDecoration(
        theme: theme,
        radius: theme.radii.pill,
        fillColor: on
            ? trackColor
            : (disabled ? theme.disabled : theme.surfaceAlt),
        stroke: on
            ? theme.ink
            : theme.textSub.withValues(alpha: disabled ? 0.25 : 0.45),
        strokeWidth: 1.2,
      ),
      // 裁剪到轨道圆角内：滑块过冲时顶到轨道边缘而非溢出
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: _buildKnob(theme, trackColor, disabled)
            // カチッ：滑块 squash & stretch 四段式（单个 custom 避免同名效果叠加）
            .animate(target: value ? 1 : 0)
            .custom(
              duration: _toggleDuration,
              builder: (context, t, child) {
                final s = _knobScale.transform(t);
                return Transform.translate(
                  offset: Offset(_knobDx.transform(t), 0),
                  child: Transform.scale(
                    scaleX: s.dx,
                    scaleY: s.dy,
                    child: child,
                  ),
                );
              },
            ),
      ),
    );
  }

  Widget _buildKnob(AppThemeData theme, Color trackColor, bool disabled) {
    // 白色滑块圆 + 墨线描边（手绘风格：无渐变、无投影）
    return Container(
      width: 30,
      height: 30,
      decoration: dsSketchDecoration(
        theme: theme,
        circle: true,
        fillColor: DsColors.white,
      ),
      child: CustomPaint(
        painter: _SwitchFacePainter(
          happy: value,
          faceColor: (value ? trackColor : theme.textSub).mixBlack(0.15),
        ),
      ),
    );
  }
}

/// カチッ反馈短线：开启后滑块右上方两条圆角短线依次划过（仅播放一次）
class _KachiLines extends StatelessWidget {
  const _KachiLines({required this.color, required this.active});

  final Color color;

  /// 是否处于开启态（开启瞬间播放划线动画）
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(0.24),
          const SizedBox(height: 4),
          Padding(padding: const EdgeInsets.only(left: 6), child: _line(-0.24)),
        ],
      ),
    );
  }

  /// 划线 keyframes（对应 CSS line-slide）：
  /// 右側 120% → 左侧 -122%（过冲）→ 回稳 -100%（完全滑出）
  static final Animatable<double> _lineSlide = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.2,
        end: -1.22,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 280,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -1.22,
        end: -1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 120,
    ),
  ]);

  Widget _line(double angle) {
    return Transform.rotate(
      angle: angle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 22,
          height: 3,
          // 滑入 → 稍过冲 → 回稳；反向（关闭）时被 AnimatedOpacity 隐藏
          child:
              Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  )
                  .animate(target: active ? 1 : 0)
                  .custom(
                    delay: 320.ms,
                    duration: 400.ms,
                    builder: (context, t, child) => FractionalTranslation(
                      translation: Offset(_lineSlide.transform(t), 0),
                      child: child,
                    ),
                  ),
        ),
      ),
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
