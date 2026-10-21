import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import 'focus_ring.dart';
import 'ink_splash.dart';

/// 手绘复选框（支持三态：未选中 / 选中 / 半选）
///
/// - 选中态的对勾按进度两段描画（短上行 + 长下行），半选态画伸展横线
/// - 选中瞬间在元素外围播一次墨点扩散（取消选中不播）
/// - 键盘聚焦时外圈显示虚线焦点环
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

    final Color markColor = disabled ? theme.textSub : theme.onPrimary;
    // 对勾描画时长：快速档 × 1.3 ≈ 200ms；减弱动画时直接画完
    final Duration drawDuration = context.dsAnimationsDisabled
        ? Duration.zero
        : DsMotion.fast * 1.3;

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
            child: DsFocusRing(
              show: states.contains(WidgetState.focused),
              radius: theme.radii.sm,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                    // 对勾/横线改为 CustomPainter 按进度描画（圆头白线）；
                    // 未选态无内容无动画
                    child: checked
                        ? SizedBox.expand(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: drawDuration,
                              curve: DsMotion.curve,
                              builder: (context, progress, _) => CustomPaint(
                                painter: _CheckMarkPainter(
                                  progress: progress,
                                  color: markColor,
                                ),
                              ),
                            ),
                          )
                        : indeterminate
                            ? SizedBox.expand(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: drawDuration,
                                  curve: DsMotion.curve,
                                  builder: (context, progress, _) => CustomPaint(
                                    painter: _IndeterminateDashPainter(
                                      progress: progress,
                                      color: markColor,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                  ),
                  // 选中瞬间的一次性墨点扩散（取消选中不播；禁用不播）
                  Positioned.fill(
                    child: _CheckedSplash(
                      active: checked,
                      color: disabled ? null : theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 选中瞬间的一次性墨点扩散门控
///
/// [DsInkSplash] 的 trigger 只要变化就会重播，这里用生成计数把它
/// 收窄为「仅 [active] 由假变真（勾选瞬间）时重播一次」，
/// 取消选中不播；禁用时 color 为 null 自然不播。
class _CheckedSplash extends StatefulWidget {
  const _CheckedSplash({required this.active, this.color});

  final bool active;
  final Color? color;

  @override
  State<_CheckedSplash> createState() => _CheckedSplashState();
}

class _CheckedSplashState extends State<_CheckedSplash> {
  int _generation = 0;

  @override
  void didUpdateWidget(_CheckedSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) =>
      DsInkSplash(trigger: _generation, color: widget.color);
}

/// 对勾描画：进度 0→1 分两段（短上行 + 长下行），圆头线随盒尺寸缩放
///
/// 锚点相对 26px 盒定义，两段的进度占比按线长分配。
class _CheckMarkPainter extends CustomPainter {
  const _CheckMarkPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  /// 起点（左上短上行起点）
  static const Offset _start = Offset(7.5, 12.5);

  /// 拐点（对勾底角）
  static const Offset _corner = Offset(11.5, 16.5);

  /// 终点（右上长下行终点）
  static const Offset _end = Offset(19, 8);

  /// 第一段（短上行）占总线长的比例
  static final double _firstRatio =
      (_corner - _start).distance /
      ((_corner - _start).distance + (_end - _corner).distance);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final scale = size.width / 26;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final start = _start * scale;
    final corner = _corner * scale;
    final end = _end * scale;

    final first = (progress / _firstRatio).clamp(0.0, 1.0);
    if (first > 0) {
      canvas.drawLine(start, Offset.lerp(start, corner, first)!, paint);
    }
    final second = ((progress - _firstRatio) / (1 - _firstRatio)).clamp(
      0.0,
      1.0,
    );
    if (second > 0) {
      canvas.drawLine(corner, Offset.lerp(corner, end, second)!, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckMarkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// 半选横线：自中心向两侧按进度伸展的圆头横线
class _IndeterminateDashPainter extends CustomPainter {
  const _IndeterminateDashPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final scale = size.width / 26;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final half = 6 * scale * progress;
    canvas.drawLine(
      Offset(size.width / 2 - half, size.height / 2),
      Offset(size.width / 2 + half, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_IndeterminateDashPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
