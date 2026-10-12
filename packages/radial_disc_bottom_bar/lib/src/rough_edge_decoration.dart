import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart'
    show
        Drawable,
        DrawConfig,
        Generator,
        NoFiller,
        RoughBoxDecoration,
        RoughBoxShape,
        RoughDrawing,
        RoughDrawingStyle;

/// [RoughBoxDecoration] 的贴边版：填充与描边画在容器真实边界上
///
/// skribble 原版 painter 会把形状整体 deflate 墨迹出血量
/// （约 3~6px），小尺寸控件（药丸/圆钮）上实底和墨线都明显
/// 缩在里面。本类仅内缩半个线宽：墨线完全在界内且贴边；
/// `padding` 同步置零，出血不再叠加到内容上。
class RoughEdgeBoxDecoration extends RoughBoxDecoration {
  const RoughEdgeBoxDecoration({
    required super.borderStyle,
    required super.fillStyle,
    required super.drawConfig,
    required super.seed,
    super.shape = RoughBoxShape.roundedRectangle,
    super.borderRadius,
    super.filler,
  });

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RoughEdgeBoxPainter(this, onChanged);
}

class _RoughEdgeBoxPainter extends BoxPainter {
  _RoughEdgeBoxPainter(this.decoration, [VoidCallback? onChanged])
      : super(onChanged);

  final RoughEdgeBoxDecoration decoration;

  Size? _size;
  late RoughDrawing _drawing;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    if (_size != size) {
      _drawing = _prepare(size);
      _size = size;
    }
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _drawing.paint(canvas, progress: 1, pressure: 0);
    canvas.restore();
  }

  RoughDrawing _prepare(Size size) {
    final half = (decoration.borderStyle?.width ?? 0) / 2;
    final rect = (Offset.zero & size).deflate(
      math.min(half, size.shortestSide / 2),
    );

    final drawConfig =
        decoration.drawConfig ?? DrawConfig.build(seed: decoration.seed);
    drawConfig.randomizer.reset();
    final filler = decoration.filler ?? NoFiller();
    final generator = Generator(drawConfig, filler);

    final borderPaint = _buildPaint(
      decoration.borderStyle ?? const RoughDrawingStyle(),
      rect,
    );
    final fillPaint = decoration.fillStyle == null
        ? borderPaint
        : _buildPaint(decoration.fillStyle!, rect);

    final Drawable drawable;
    switch (decoration.shape) {
      case RoughBoxShape.rectangle:
        drawable = generator.rectangle(
          rect.left,
          rect.top,
          rect.width,
          rect.height,
        );
      case RoughBoxShape.roundedRectangle:
        final br = decoration.borderRadius ?? BorderRadius.zero;
        drawable = generator.roundedRectangle(
          rect.left,
          rect.top,
          rect.width,
          rect.height,
          br.topLeft.x,
          br.topRight.x,
          br.bottomRight.x,
          br.bottomLeft.x,
        );
      case RoughBoxShape.circle:
        drawable = generator.circle(
          rect.center.dx,
          rect.center.dy,
          rect.shortestSide,
        );
      case RoughBoxShape.ellipse:
        drawable = generator.ellipse(
          rect.center.dx,
          rect.center.dy,
          rect.width,
          rect.height,
        );
    }
    return RoughDrawing(drawable, borderPaint, fillPaint);
  }

  Paint _buildPaint(RoughDrawingStyle style, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = style.width ?? 0.1
      ..color = style.color ?? const Color(0x00000000)
      ..shader = style.gradient?.createShader(rect);
    if (style.blendMode != null) {
      paint.blendMode = style.blendMode!;
    }
    return paint;
  }
}
