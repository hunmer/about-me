import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'jelly_box.dart';

/// 线性手绘进度条：纯色填充，可选末端挂件（如星星）
class DSLinearProgress extends StatelessWidget {
  const DSLinearProgress({
    super.key,
    required this.value,
    this.height = 14,
    this.thumb,
    this.color,
  });

  /// 0.0 ~ 1.0
  final double value;

  /// 进度末端挂件（设计稿中为一颗星星）
  final Widget? thumb;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final v = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: height + (thumb != null ? 14 : 0),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 轨道
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: thumb != null ? 0 : null,
                    top: thumb != null ? 14 : 0,
                    child: JellyBox(
                      radius: theme.radii.pill,
                      color: theme.surfaceAlt,
                      raised: false,
                    ),
                  ),
                  // 纯色填充（手绘风格：无渐变、无玻璃高光）
                  Positioned(
                    left: 0,
                    top: thumb != null ? 14 : 0,
                    child: ClipRRect(
                      borderRadius: theme.radii.pill,
                      child: Container(
                        width: math.max((width - 2) * t + 2, 12),
                        height: height,
                        decoration: BoxDecoration(
                          color: color ?? theme.primary,
                        ),
                      ),
                    ),
                  ),
                  // 末端挂件
                  if (thumb != null)
                    Positioned(
                      left: (width - 26) * t,
                      top: 0,
                      child: SizedBox(width: 26, height: 26, child: thumb!),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 圆环手绘进度：中心自定义内容
class DSRingProgress extends StatelessWidget {
  const DSRingProgress({
    super.key,
    required this.value,
    required this.child,
    this.size = 110,
    this.strokeWidth = 13,
    this.color,
  });

  /// 0.0 ~ 1.0
  final double value;
  final Widget child;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final v = value.clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: t,
                trackColor: theme.ink.withValues(alpha: 0.3),
                progressColor: color ?? theme.primary,
                drawConfig: theme.wired.drawConfig,
                strokeWidth: strokeWidth,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 手绘圆环：底环淡墨整圈 + 进度弧主色，均由 skribble rough 引擎画弧
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.drawConfig,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final DrawConfig drawConfig;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // 墨线中心内收半个笔宽，避免墨迹出界
    final diameter = size.width - strokeWidth;
    if (diameter <= 0) return;
    final generator = Generator(drawConfig, NoFiller());
    final Paint ink = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    // 底环：淡墨整圈（每次生成前重置随机流，动画各帧墨迹稳定不抖变）
    drawConfig.randomizer.reset();
    canvas.drawRough(
      generator.arc(center.dx, center.dy, diameter, diameter, 0, 2 * math.pi),
      ink..color = trackColor,
      ink,
    );

    // 进度弧：12 点方向起顺时针
    if (progress > 0) {
      drawConfig.randomizer.reset();
      canvas.drawRough(
        generator.arc(
          center.dx,
          center.dy,
          diameter,
          diameter,
          -math.pi / 2,
          -math.pi / 2 + 2 * math.pi * progress,
        ),
        ink..color = progressColor,
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.trackColor != trackColor;
}

/// 进度数值组合（中心文字：如 6/8 打卡）
class DSRingProgressLabeled extends StatelessWidget {
  const DSRingProgressLabeled({
    super.key,
    required this.value,
    required this.label,
    this.subLabel,
    this.size = 110,
    this.color,
  });

  final double value;
  final String label;
  final String? subLabel;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DSRingProgress(
      value: value,
      size: size,
      color: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: DsTypography.title.copyWith(color: theme.primaryText),
          ),
          if (subLabel != null)
            Text(
              subLabel!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
        ],
      ),
    );
  }
}
