// GrokCharacter 的 CustomPainter / 视图。将引擎输出的 SVG 用户坐标帧绘制到画布。
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show Offset, Path;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'grok_character.dart';
import 'grok_fx.dart';
import 'grok_geometry.dart';
import 'grok_tables.dart' as t;

/// viewBox 内切圆 path（overlay dots 用）。
final Path _circlePath = Path()
  ..addOval(Rect.fromCircle(center: Offset(GrokGeometry.re, GrokGeometry.re), radius: GrokGeometry.re));

class GrokCharacterPainter extends CustomPainter {
  final GrokFrame frame;
  final Color fg;
  final Color eyeFill;
  final Color badgeColor;

  GrokCharacterPainter({
    required this.frame,
    required this.fg,
    required this.eyeFill,
    required this.badgeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = GrokGeometry.re;
    final half = t.viewHalf / frame.zoom;
    final vbMid = t.viewMid;
    final side = math.min(size.width, size.height);
    if (side <= 0 || !side.isFinite) return;
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / (half * 2), side / (half * 2));
    // pose scale（等价 CSS transform-origin 50% 50%）
    final ps = frame.poseScale;
    if ((ps - 1).abs() > 0.001) {
      canvas.translate(vbMid, vbMid);
      canvas.scale(ps, ps);
      canvas.translate(-vbMid, -vbMid);
    }

    final fx = frame.fx;

    _paintBursts(canvas, fx.backShapes);
    for (final rb in fx.ribbons) {
      if (rb.back != null) canvas.drawPath(rb.back!, _ribbonPaint(rb));
    }

    for (final d in fx.dots) {
      canvas.save();
      canvas.transform(d.matrix.storage);
      canvas.drawPath(
        _circlePath,
        Paint()..color = fg.withValues(alpha: fg.a * d.opacity),
      );
      canvas.restore();
    }

    for (final c in fx.rings) {
      if (c.dashSweep != null) {
        final rect = Rect.fromCircle(center: Offset(c.cx, c.cy), radius: c.r);
        canvas.drawArc(
          rect,
          -math.pi / 2,
          c.dashSweep!,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = c.strokeWidth
            ..color = fg.withValues(alpha: fg.a * c.opacity),
        );
      } else {
        canvas.drawCircle(
          Offset(c.cx, c.cy),
          c.r,
          Paint()
            ..style = c.stroke ? PaintingStyle.stroke : PaintingStyle.fill
            ..strokeWidth = c.strokeWidth
            ..color = fg.withValues(alpha: fg.a * c.opacity),
        );
      }
    }

    for (final c in fx.parts) {
      canvas.drawCircle(
        Offset(c.cx, c.cy),
        c.r,
        Paint()..color = fg.withValues(alpha: fg.a * c.opacity),
      );
    }

    for (final g in fx.glyphs) {
      final Paint paint;
      if (g.asStroke) {
        paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = fg.withValues(alpha: fg.a * g.opacity);
      } else {
        paint = Paint()..color = fg.withValues(alpha: fg.a * g.opacity);
      }
      canvas.save();
      canvas.transform(g.matrix.storage);
      canvas.drawPath(g.path, paint);
      canvas.restore();
    }

    // --- 主体组：body + clip 眼睛 + badge ---
    final groupAlpha = frame.groupOpacity.clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(r + frame.tx, r + frame.ty);
    canvas.rotate(frame.rotDeg * math.pi / 180);
    canvas.scale(frame.sx, frame.sy);
    canvas.translate(-r, -r);

    canvas.drawPath(
      frame.bodyPath,
      Paint()..color = fg.withValues(alpha: fg.a * groupAlpha),
    );

    canvas.save();
    canvas.clipPath(frame.bodyPath);
    final eyePaint = Paint()..color = eyeFill.withValues(alpha: eyeFill.a * groupAlpha);
    for (final eye in frame.eyes.eyes) {
      if (!eye.visible) continue;
      var cx = 0.0, cy = 0.0;
      for (final p in eye.poly) {
        cx += p.dx;
        cy += p.dy;
      }
      cx /= eye.poly.length;
      cy /= eye.poly.length;
      final path = Path()..moveTo(eye.poly.first.dx, eye.poly.first.dy);
      for (final p in eye.poly.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.save();
      canvas.translate(eye.dx, eye.dy);
      if (eye.matrix != null) {
        final m = eye.matrix!;
        canvas.transform(Float64List.fromList([
          m[0], m[1], 0, 0, //
          m[2], m[3], 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1,
        ]));
      } else {
        canvas.scale(eye.sx, eye.sy);
      }
      canvas.translate(-cx, -cy);
      canvas.drawPath(path, eyePaint);
      canvas.restore();
    }
    canvas.restore();

    final badge = frame.eyes.badge;
    if (badge != null && badge.r > 0.2) {
      canvas.drawCircle(
        Offset(badge.cx, badge.cy),
        badge.r,
        Paint()..color = badgeColor.withValues(alpha: badgeColor.a * groupAlpha),
      );
    }
    canvas.restore();

    // --- front 层：条带前半 + 爆裂粒子 ---
    for (final rb in fx.ribbons) {
      if (rb.front != null) canvas.drawPath(rb.front!, _ribbonPaint(rb));
    }
    _paintBursts(canvas, fx.frontShapes);
  }

  Paint _ribbonPaint(FxRibbonDraw rb) {
    final g = rb.gradient;
    if (g == null || g.a == g.b) {
      return Paint()..color = const Color(0x33808080);
    }
    final colors = [
      for (final c in g.stops) c.withValues(alpha: c.a * rb.opacity),
    ];
    return Paint()
      ..shader = ui.Gradient.linear(
        g.a,
        g.b,
        colors,
        [for (int i = 0; i < colors.length; i++) i / (colors.length - 1)],
      );
  }

  void _paintBursts(Canvas canvas, List<FxBurstDraw> shapes) {
    for (final s in shapes) {
      final paint = Paint()..color = s.color.withValues(alpha: s.opacity);
      switch (s.kind) {
        case FxBurstKind.circle:
          canvas.drawCircle(s.center, s.r, paint);
        case FxBurstKind.star:
          canvas.save();
          canvas.translate(s.center.dx, s.center.dy);
          canvas.rotate(s.rotDeg * math.pi / 180);
          canvas.scale(s.r, s.r);
          canvas.drawPath(starPathObj, paint);
          canvas.restore();
        case FxBurstKind.capsule:
          canvas.save();
          canvas.translate(s.center.dx, s.center.dy);
          canvas.rotate(s.rotDeg * math.pi / 180);
          final h = math.max(s.capsuleHeight, 0.5);
          final rect = Rect.fromCenter(center: Offset.zero, width: s.r, height: h);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(h / 2)),
            paint,
          );
          canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(GrokCharacterPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.fg != fg ||
      oldDelegate.eyeFill != eyeFill ||
      oldDelegate.badgeColor != badgeColor;
}

/// 完整角色视图：Ticker 驱动 + 可选指针跟随。
class GrokCharacterView extends StatefulWidget {
  final GrokCharacter character;
  final double? sizePx;
  final bool pointerFollow;

  const GrokCharacterView({
    super.key,
    required this.character,
    this.sizePx,
    this.pointerFollow = false,
  });

  @override
  State<GrokCharacterView> createState() => _GrokCharacterViewState();
}

class _GrokCharacterViewState extends State<GrokCharacterView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final GlobalKey _boxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    widget.character.tick(elapsed.inMicroseconds / 1000);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handlePointer(PointerEvent e, double side) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || side <= 0) return;
    final local = box.globalToLocal(e.position);
    widget.character
        .updatePointer(local - Offset(side / 2, side / 2), Size(side, side));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = widget.sizePx ??
          (constraints.maxWidth.isFinite && constraints.maxHeight.isFinite
              ? math.min(constraints.maxWidth, constraints.maxHeight)
              : constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 128.0);
      final char = widget.character;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) char.updateRenderWidth(side);
      });
      final follow = widget.pointerFollow || char.followPointer;
      return MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        onHover: follow ? (e) => _handlePointer(e, side) : null,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: follow ? (e) => _handlePointer(e, side) : null,
          onPointerDown: follow ? (e) => _handlePointer(e, side) : null,
          child: SizedBox(
            key: _boxKey,
            width: side,
            height: side,
            child: AnimatedBuilder(
              animation: char,
              builder: (context, _) {
                final frame = char.frame;
                if (frame == null) return const SizedBox.shrink();
                return CustomPaint(
                  painter: GrokCharacterPainter(
                    frame: frame,
                    fg: char.foreground,
                    eyeFill: char.eyeFill,
                    badgeColor: char.badgeColor,
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}
