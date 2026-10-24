import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:skribble/skribble.dart'
    show DrawConfig, Generator, NoFiller, PointD, RoughDrawing;

/// 手绘墨线树形边渲染器
///
/// 复用 [TreeEdgeRenderer] 的几何路径（L 形 / 贝塞尔连接线），
/// 以 skribble rough 引擎重绘为纸墨手绘线（与全局墨线风格同源：
/// [DrawConfig] 取自 theme.wired，逐边固定 seed 保证重绘不抖变）。
class SketchTreeEdgeRenderer extends TreeEdgeRenderer {
  SketchTreeEdgeRenderer(
    super.configuration, {
    required this.drawConfig,
    required this.color,
    required this.strokeWidth,
  });

  /// 全局墨线配置（来自 theme.wired.drawConfig）
  final DrawConfig drawConfig;

  /// 墨线颜色（theme.ink 派生）
  final Color color;

  /// 墨线宽度
  final double strokeWidth;

  /// 每条边的墨迹缓存：布局稳定时（bounds 不变）复用同一份 RoughDrawing
  final Map<Edge, _CachedInk> _cache = {};

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final source = edge.source;
    final destination = edge.destination;
    if (source == destination) {
      super.renderEdge(canvas, edge, paint);
      return;
    }

    linePath.reset();
    buildEdgePath(
      source,
      destination,
      getNodePosition(source),
      getNodePosition(destination),
      getEffectiveOrientation(source, destination),
    );
    final bounds = linePath.getBounds();
    if (bounds.width < 0.5 && bounds.height < 0.5) {
      return;
    }

    // 缓存键按 2px 网格量化：节点动画逐帧移动时复用相邻墨迹，
    // 手绘墨线本身带数像素抖动，误差不可感知
    final key = _quantize(bounds);
    var cached = _cache[edge];
    if (cached == null ||
        cached.key != key ||
        cached.color != color ||
        cached.strokeWidth != strokeWidth) {
      cached = _buildInk(edge, bounds, key);
      _cache[edge] = cached;
    }
    // 展开动画传入的 paint 带透明度：以透明度重着色后绘制
    final alpha = paint.color.alpha / 255.0;
    if (alpha >= 1) {
      cached.drawing.paint(canvas);
    } else {
      canvas.saveLayer(
        bounds.inflate(strokeWidth * 4 + 24),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      cached.drawing.paint(canvas);
      canvas.restore();
    }
  }

  _CachedInk _buildInk(Edge edge, Rect bounds, Rect key) {
    // 路径采样：长边取折线点交给 rough 引擎拟合手绘曲线
    final points = <PointD>[];
    for (final metric in linePath.computeMetrics()) {
      var distance = 0.0;
      const sample = 32.0;
      while (distance < metric.length) {
        final position = metric.getTangentForOffset(distance)?.position;
        if (position != null) {
          points.add(PointD(position.dx, position.dy));
        }
        distance += sample;
      }
      final end = metric.getTangentForOffset(metric.length)?.position;
      if (end != null) points.add(PointD(end.dx, end.dy));
    }

    final inkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;

    final RoughDrawing drawing;
    final config = _configFor(edge);
    final generator = Generator(config, NoFiller());
    if (points.length < 3) {
      // 短边（采样点不足 3 个）：退化为手绘直线
      drawing = RoughDrawing(
        generator.linearPath(points),
        inkPaint,
        inkPaint,
      );
    } else {
      drawing = RoughDrawing(
        generator.curvePath(points),
        inkPaint,
        inkPaint,
      );
    }
    return _CachedInk(key, color, strokeWidth, drawing);
  }

  static Rect _quantize(Rect bounds) {
    double snap(double value) => (value / 2).roundToDouble() * 2;
    return Rect.fromLTRB(
      snap(bounds.left),
      snap(bounds.top),
      snap(bounds.right),
      snap(bounds.bottom),
    );
  }

  /// 每条边一个稳定 seed（目的节点 key 派生），墨迹各异且重绘不抖变
  DrawConfig _configFor(Edge edge) {
    final raw = edge.destination.key?.value.hashCode ?? edge.hashCode;
    final seed = (raw & 0x7fffffff) + 1;
    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    return config;
  }
}

class _CachedInk {
  const _CachedInk(this.key, this.color, this.strokeWidth, this.drawing);

  /// 量化后的缓存键（2px 网格）
  final Rect key;
  final Color color;
  final double strokeWidth;
  final RoughDrawing drawing;
}
