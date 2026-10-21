import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 手绘标签（Chip）的外观变种（配合 [DSChip.accent] 使用）
enum DsChipVariant {
  /// 实底：accent 纯色填充 + 主题墨线描边，反色文字
  solid,

  /// 描边：纸底 + accent 墨线描边 + accent 深色文字
  outlined,

  /// 虚线：同描边，但边框为「画 7 空 5」的手绘虚线
  dashed,

  /// 软底：accent 淡彩底 + accent 描边 + accent 深色文字
  soft,
}

/// 手绘标签（Chip）：默认 / 选中 / 可删除
///
/// 指定 [accent] 后按 [variant] 渲染（solid/outlined/dashed/soft 四种）；
/// 未指定时保持默认的选中/未选中语义配色。选中态切换时整体做
/// 0.92 → 1 的弹跳（墨线层静止，仅缩放变换）。
class DSChip extends StatelessWidget {
  const DSChip({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.badge,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.variant = DsChipVariant.solid,
    this.accent,
  });

  final String label;

  /// 可选前缀图标
  final DsIconKind? icon;

  /// 自定义前缀部件（如优先级色点），与 [icon] 二选一
  final Widget? leading;

  /// 角标文本（如过滤项当前值的简写），跟随选中态着色
  final String? badge;

  /// 是否处于选中态（主色实底高亮）
  final bool selected;

  /// 点击切换选中；为 null 时非交互
  final ValueChanged<bool>? onSelected;

  /// 删除回调；非 null 时显示 × 按钮
  final VoidCallback? onDeleted;

  /// 外观变种（[accent] 非空时生效，默认 solid）
  final DsChipVariant variant;

  /// 强调色：非空时按 [variant] 渲染，覆盖默认的选中/未选中语义配色；
  /// null = 保持现状语义色（默认）
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final interactive = onSelected != null;

    return Pressable(
      onPressed: interactive ? () => onSelected?.call(!selected) : null,
      semanticLabel: label,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);

        // ---- 配色：accent 模式按 variant 派生；默认模式保持语义色 ----
        final Color fg;
        final Color badgeBg;
        if (accent != null) {
          switch (variant) {
            case DsChipVariant.solid:
              // onPrimary 风格的反色文字；角标沿用选中态的反色透明底
              fg = accent!.mixWhite(0.92);
              badgeBg = fg.withValues(alpha: 0.25);
            case DsChipVariant.outlined || DsChipVariant.dashed:
              fg = accent!.mixBlack(0.15);
              badgeBg = accent!.withValues(alpha: 0.14);
            case DsChipVariant.soft:
              fg = accent!.mixBlack(0.2);
              badgeBg = accent!.withValues(alpha: 0.16);
          }
        } else {
          fg = selected
              ? (interactive ? theme.onPrimary : theme.surface)
              : theme.textSub;
          badgeBg = selected
              ? theme.onPrimary.withValues(alpha: 0.25)
              : theme.surfaceAlt;
        }

        final Widget content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(icon!, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: DsTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (badge != null && badge!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: theme.radii.pill,
                ),
                child: Text(
                  badge!,
                  style: DsTypography.label.copyWith(color: fg),
                ),
              ),
            ],
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                  ),
                  child: DsIcon(DsIconKind.close, size: 10, color: fg),
                ),
              ),
            ],
          ],
        );

        final Widget shell;
        if (accent != null) {
          shell = _buildAccentShell(theme, content);
        } else if (selected) {
          shell = JellyBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            radius: theme.radii.pill,
            color: interactive ? theme.primary : theme.disabled,
            raised: !pressed,
            child: content,
          );
        } else {
          // 未选中态：纸面实底 + 淡墨描边的手绘胶囊
          shell = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: dsSketchDecoration(
              theme: theme,
              fillColor: theme.surface,
              stroke: theme.textSub.withValues(alpha: 0.4),
              radius: theme.radii.pill,
            ),
            child: content,
          );
        }

        // 选中↔未选中切换：整体 0.92 → 1 弹跳（rough 墨线不可补间，
        // 动效只作用在外层缩放变换上）
        return _ChipBounce(trigger: selected, child: shell);
      },
    );
  }

  /// accent 模式外壳：按 [variant] 组合实底/描边/虚线（墨线统一走
  /// [dsSketchDecoration]，虚线变种的边框由私有虚线画笔画在边界层）
  Widget _buildAccentShell(AppThemeData theme, Widget content) {
    final Color fill;
    final Color? stroke;
    switch (variant) {
      case DsChipVariant.solid:
        fill = accent!;
        stroke = null; // 默认主题墨线
      case DsChipVariant.soft:
        fill = accent!.mixWhite(0.9);
        stroke = accent;
      case DsChipVariant.outlined:
        fill = theme.surface; // 纸底
        stroke = accent;
      case DsChipVariant.dashed:
        fill = theme.surface; // 纸底
        stroke = DsColors.transparent; // rough 实线隐藏，由虚线层画边框
    }
    return Container(
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: fill,
        stroke: stroke,
        radius: theme.radii.pill,
      ),
      child: Stack(
        children: [
          if (variant == DsChipVariant.dashed)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ChipDashedBorderPainter(
                    color: accent!,
                    radius: theme.radii.pill,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: content,
          ),
        ],
      ),
    );
  }
}

/// 选中态变化瞬间的一次性弹跳（0.92 → 1，弹性入场曲线）
///
/// 初始静置于 1（首次构建不弹跳，保持现状视觉）；
/// [trigger] 翻转（选中↔未选中）时重播一次。
class _ChipBounce extends StatefulWidget {
  const _ChipBounce({required this.trigger, required this.child});

  final bool trigger;
  final Widget child;

  @override
  State<_ChipBounce> createState() => _ChipBounceState();
}

class _ChipBounceState extends State<_ChipBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DsMotion.fast,
  );

  @override
  void initState() {
    super.initState();
    _controller.value = 1; // 初始静置，不弹跳
  }

  @override
  void didUpdateWidget(_ChipBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        !context.dsAnimationsDisabled) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1)
          .chain(CurveTween(curve: DsMotion.enter))
          .animate(_controller),
      child: widget.child,
    );
  }
}

/// 沿 chip 边界画虚线边框：圆角路径按「画 7 空 5」取段
/// （笔触与 sketch.dart 的 _DashedBorderPainter 同款）
class _ChipDashedBorderPainter extends CustomPainter {
  const _ChipDashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  static const double _strokeWidth = 1.6;
  static const double _dashLength = 7;
  static const double _gapLength = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = _strokeWidth / 2;
    final rect = Offset.zero & size;
    final path = Path()..addRRect(radius.toRRect(rect.deflate(half)));

    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final segment = drawing ? _dashLength : _gapLength;
        final next = math.min(distance + segment, metric.length);
        if (drawing) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        drawing = !drawing;
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..color = color;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_ChipDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
