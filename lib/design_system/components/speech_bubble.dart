import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 手绘气泡的外轮廓风格。
enum DsSpeechBubbleShape {
  /// 现有胶囊主体与下垂尾巴。
  capsule,

  /// 带圆角矩形主体与下垂尾巴。
  roundedRectangle,

  /// 波瓣云朵主体与下垂尾巴。
  cloud,

  /// 漫画爆炸形主体与下垂尾巴。
  starburst,
}

/// 手绘纸墨风对话气泡，支持胶囊、圆角、云朵和漫画爆炸轮廓。
/// 颜色沿用主题 surface/ink 与 wired drawConfig，尾巴与主体共用轮廓。
class DsSpeechBubble extends StatelessWidget {
  const DsSpeechBubble({
    super.key,
    required this.child,
    this.header,
    this.headerStyle,
    this.padding,
    this.tailHeight = 13,
    this.tailWidth = 26,
    this.tailXRatio = 0.44,
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1.8,
    this.shape = DsSpeechBubbleShape.capsule,
  });

  /// 气泡主体内容
  final Widget child;

  /// 顶部标题（如角色名）；为空则不占位
  final String? header;

  /// 标题样式；默认手写体 + primaryText 强调色
  final TextStyle? headerStyle;

  /// 内容内边距；默认水平 xl / 垂直 md
  final EdgeInsetsGeometry? padding;

  /// 尾巴高度（向下伸出组件边界）
  final double tailHeight;

  /// 尾巴根部宽度
  final double tailWidth;

  /// 尾巴尖端水平位置占宽度的比例（0~1，越小越靠左）
  final double tailXRatio;

  /// 填充色；默认纸底 `theme.surface`
  final Color? fillColor;

  /// 描边色；默认墨线 `theme.ink`
  final Color? strokeColor;

  /// 描边宽度
  final double strokeWidth;

  /// 手绘轮廓风格；默认保持原有胶囊形状
  final DsSpeechBubbleShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasHeader = header != null && header!.isNotEmpty;
    final safePadding = switch (shape) {
      DsSpeechBubbleShape.starburst => EdgeInsets.symmetric(
        horizontal: theme.spacing.xl + 12,
        vertical: theme.spacing.md + 6,
      ),
      DsSpeechBubbleShape.cloud => EdgeInsets.symmetric(
        horizontal: theme.spacing.xl + 4,
        vertical: theme.spacing.md + 2,
      ),
      _ => EdgeInsets.symmetric(
        horizontal: theme.spacing.xl,
        vertical: theme.spacing.md,
      ),
    };
    final resolvedPadding = padding ?? safePadding;
    Widget content = Padding(
      padding: EdgeInsets.only(bottom: tailHeight),
      child: Padding(
        padding: resolvedPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasHeader)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  header!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      headerStyle ??
                      DsTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.primaryText,
                      ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
    return CustomPaint(
      painter: _DsSpeechBubblePainter(
        drawConfig: theme.wired.drawConfig,
        fillColor: fillColor ?? theme.surface,
        strokeColor: strokeColor ?? theme.ink,
        strokeWidth: strokeWidth,
        tailHeight: tailHeight,
        tailWidth: tailWidth,
        tailXRatio: tailXRatio,
        shape: shape,
      ),
      child: content,
    );
  }
}

/// 胶囊 + 尾巴一体成形的 rough 画笔
class _DsSpeechBubblePainter extends CustomPainter {
  _DsSpeechBubblePainter({
    required this.drawConfig,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.tailHeight,
    required this.tailWidth,
    required this.tailXRatio,
    required this.shape,
  });

  final DrawConfig drawConfig;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double tailHeight;
  final double tailWidth;
  final double tailXRatio;
  final DsSpeechBubbleShape shape;

  RoughDrawing? _cached;
  Size? _cachedSize;
  DsSpeechBubbleShape? _cachedShape;

  @override
  void paint(Canvas canvas, Size size) {
    // 尺寸未变时复用已生成的墨迹；重建前重置随机数，保证同一形状
    // 每次重绘的墨迹完全一致（与 design_system 其他 rough 画笔一致）
    if (_cachedSize != size || _cached == null || _cachedShape != shape) {
      drawConfig.randomizer.reset();
      final generator = Generator(drawConfig, SolidFiller());
      final drawable = generator.polygon(_outlinePoints(size));
      _cached = RoughDrawing(
        drawable,
        ui.Paint()
          ..color = strokeColor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
        ui.Paint()..color = fillColor,
      );
      _cachedSize = size;
      _cachedShape = shape;
    }
    _cached!.paint(canvas, progress: 1, pressure: 0);
  }

  List<PointD> _outlinePoints(Size size) => switch (shape) {
    DsSpeechBubbleShape.capsule => _capsuleOutline(size),
    DsSpeechBubbleShape.roundedRectangle => _roundedRectangleOutline(size),
    DsSpeechBubbleShape.cloud => _scallopedOutline(
      size,
      lobeCount: 8,
      amplitude: 0.08,
    ),
    DsSpeechBubbleShape.starburst => _scallopedOutline(
      size,
      lobeCount: 12,
      amplitude: 0.22,
    ),
  };

  /// 保留历史默认胶囊轮廓，避免默认展示产生变化。
  List<PointD> _capsuleOutline(Size size) {
    final w = size.width;
    final actualTailHeight = tailHeight.clamp(0.0, size.height).toDouble();
    final h = size.height - actualTailHeight;
    final r = math.min(h / 2, w / 2);
    final leftCx = r;
    final rightCx = w - r;
    final cy = h / 2;

    final points = <PointD>[];
    const arcSteps = 16;
    // 右半圆：顶部 → 右侧 → 底部
    for (var i = 0; i <= arcSteps; i++) {
      final t = -math.pi / 2 + math.pi * i / arcSteps;
      points.add(PointD(rightCx + r * math.cos(t), cy + r * math.sin(t)));
    }
    // 底边向左插入尾巴（尖端位置与宽度都钳制在胶囊内）
    if (actualTailHeight > 0) {
      final halfTail = tailWidth / 2;
      final tipX = (w * tailXRatio).clamp(leftCx, rightCx);
      final tailRight = (tipX + halfTail).clamp(leftCx, rightCx);
      final tailLeft = (tipX - halfTail).clamp(leftCx, rightCx);
      points.add(PointD(tailRight, h));
      points.add(PointD(tipX, h + actualTailHeight));
      points.add(PointD(tailLeft, h));
    }
    // 左半圆：底部 → 左侧 → 顶部
    for (var i = 0; i <= arcSteps; i++) {
      final t = math.pi / 2 + math.pi * i / arcSteps;
      points.add(PointD(leftCx + r * math.cos(t), cy + r * math.sin(t)));
    }
    return points;
  }

  List<PointD> _roundedRectangleOutline(Size size) {
    final w = size.width;
    final actualTailHeight = tailHeight.clamp(0.0, size.height).toDouble();
    final h = size.height - actualTailHeight;
    final radius = math.min(math.min(w, h) / 2, math.min(w * 0.18, h * 0.28));
    final halfTail = tailWidth / 2;
    final tailX = (w * tailXRatio).clamp(radius, w - radius);
    final tailRight = (tailX + halfTail).clamp(radius, w - radius);
    final tailLeft = (tailX - halfTail).clamp(radius, w - radius);
    final points = <PointD>[];

    void addArc(double cx, double cy, double start, double end) {
      const arcSteps = 8;
      for (var i = 0; i <= arcSteps; i++) {
        final angle = start + (end - start) * i / arcSteps;
        points.add(
          PointD(cx + radius * math.cos(angle), cy + radius * math.sin(angle)),
        );
      }
    }

    addArc(w - radius, radius, -math.pi / 2, 0);
    points.add(PointD(w, h - radius));
    addArc(w - radius, h - radius, 0, math.pi / 2);
    points.add(PointD(tailRight, h));
    if (actualTailHeight > 0) {
      points.add(PointD(tailX, h + actualTailHeight));
    }
    points.add(PointD(tailLeft, h));
    points.add(PointD(radius, h));
    addArc(radius, h - radius, math.pi / 2, math.pi);
    points.add(PointD(0, radius));
    addArc(radius, radius, math.pi, math.pi * 1.5);
    points.add(PointD(w - radius, 0));
    return points;
  }

  /// Oval body with a scalloped or starburst edge and the shared bottom tail.
  List<PointD> _scallopedOutline(
    Size size, {
    required int lobeCount,
    required double amplitude,
  }) {
    final w = size.width;
    final actualTailHeight = tailHeight.clamp(0.0, size.height).toDouble();
    final h = size.height - actualTailHeight;
    if (w <= 0 || h <= 0) return _capsuleOutline(size);

    final cx = w / 2;
    final cy = h / 2;
    final rx = w / 2;
    final ry = h / 2;
    final halfTail = math.min(tailWidth / 2, rx * 0.9);
    final tailX = (w * tailXRatio).clamp(halfTail, w - halfTail);
    final rightBase = tailX + halfTail;
    final leftBase = tailX - halfTail;
    final rightAngle = math.acos(((rightBase - cx) / rx).clamp(-1.0, 1.0));
    final leftAngle = math.acos(((leftBase - cx) / rx).clamp(-1.0, 1.0));

    PointD contourPoint(double angle) {
      final wave =
          (1 + amplitude * math.cos(lobeCount * angle)) / (1 + amplitude);
      return PointD(
        cx + rx * wave * math.cos(angle),
        cy + ry * wave * math.sin(angle),
      );
    }

    const sampleCount = 96;
    const startAngle = -math.pi / 2;
    const endAngle = math.pi * 1.5;
    final points = <PointD>[];
    for (var i = 0; i < sampleCount; i++) {
      final angle = startAngle + (endAngle - startAngle) * i / sampleCount;
      if (angle < rightAngle) points.add(contourPoint(angle));
    }
    points.add(PointD(rightBase, h));
    if (actualTailHeight > 0) {
      points.add(PointD(tailX, h + actualTailHeight));
    }
    points.add(PointD(leftBase, h));
    for (var i = 0; i < sampleCount; i++) {
      final angle = startAngle + (endAngle - startAngle) * i / sampleCount;
      if (angle > leftAngle) points.add(contourPoint(angle));
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _DsSpeechBubblePainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.tailHeight != tailHeight ||
        oldDelegate.tailWidth != tailWidth ||
        oldDelegate.tailXRatio != tailXRatio ||
        oldDelegate.shape != shape ||
        oldDelegate.drawConfig != drawConfig;
  }
}
