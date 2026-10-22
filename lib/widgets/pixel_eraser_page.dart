import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 一次涂抹笔画：图片像素坐标点序列 + 半径（图片像素，随图片分辨率缩放）
class _EraseStroke {
  _EraseStroke({required this.radius});

  final double radius;
  final List<Offset> points = [];
}

/// 像素橡皮擦全屏页：涂抹把图片本体擦成透明像素。
/// 预览用棋盘格底 + dstOut 实时挖洞；应用时按原图分辨率离屏合成导出 PNG。
/// 无擦除直接返回（pop null），有擦除 pop 新字节。
class PixelEraserPage extends StatefulWidget {
  const PixelEraserPage({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<PixelEraserPage> createState() => _PixelEraserPageState();
}

class _PixelEraserPageState extends State<PixelEraserPage> {
  ui.Image? _image;
  final List<_EraseStroke> _strokes = [];
  final List<_EraseStroke> _redoStack = [];

  /// 笔刷直径（屏幕像素），换算到图片坐标除以显示缩放
  double _brushSize = 40;

  /// 图片 contain 显示区与缩放（build 时 LayoutBuilder 内计算）
  Rect _dstRect = Rect.zero;
  double _scale = 1;

  /// 用户视图变换（双指缩放/平移）：视口坐标 = 图片显示坐标 × zoom + pan
  double _viewZoom = 1;
  Offset _viewPan = Offset.zero;

  // 手势会话状态（一次按下到全部抬起）
  bool _gestureZooming = false;
  double _zoomStart = 1;
  double _scaleBase = 1;
  Offset _panStart = Offset.zero;
  Offset _focalStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    decodeImage().then((image) {
      if (mounted) setState(() => _image = image);
    });
  }

  /// 解码图片字节（ui.Image），失败返回 null 由加载态兜底
  Future<ui.Image?> decodeImage() async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(widget.imageBytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    return descriptor.instantiateCodec().then((codec) async {
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return frame.image;
    });
  }

  /// 视口坐标 → 图片像素坐标（先逆视图变换，再逆 contain 适配）
  Offset _toImage(Offset view) {
    final unzoomed = (view - _viewPan) / _viewZoom;
    return Offset(
      (unzoomed.dx - _dstRect.left) / _scale,
      (unzoomed.dy - _dstRect.top) / _scale,
    );
  }

  /// 当前一笔的有效显示缩放（contain × 用户缩放），笔刷半径换算用
  double get _effectiveScale => _scale * _viewZoom;

  void _beginStroke(Offset view) {
    final stroke = _EraseStroke(radius: (_brushSize / 2) / _effectiveScale);
    stroke.points.add(_toImage(view));
    _redoStack.clear();
    setState(() => _strokes.add(stroke));
  }

  void _extendStroke(Offset view) {
    if (_strokes.isEmpty) return;
    _strokes.last.points.add(_toImage(view));
    setState(() {});
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStack.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _strokes.add(_redoStack.removeLast()));
  }

  void _resetView() {
    setState(() {
      _viewZoom = 1;
      _viewPan = Offset.zero;
    });
  }

  // ── 手势：单指涂抹，双指缩放/平移 ─────────────────────

  /// 进入缩放模式（起始即双指，或涂抹中途按下第二指）
  void _enterZoomMode(double currentScale, Offset focal) {
    _gestureZooming = true;
    _zoomStart = _viewZoom;
    _panStart = _viewPan;
    _scaleBase = currentScale;
    _focalStart = focal;
  }

  void _onScaleStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      _enterZoomMode(1, d.localFocalPoint);
    } else {
      _beginStroke(d.localFocalPoint);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_gestureZooming && d.pointerCount >= 2) {
      // 涂抹中途切双指：以当前累计 scale 为基准，避免跳变
      _enterZoomMode(d.scale, d.localFocalPoint);
    }
    if (_gestureZooming) {
      setState(() {
        // 手势开始（或切入缩放）时焦点对应的视口坐标保持不动
        final v0 = (_focalStart - _panStart) / _zoomStart;
        final newZoom = (_zoomStart * d.scale / _scaleBase).clamp(1.0, 12.0);
        _viewZoom = newZoom;
        // 放大后仍以焦点为中心平移；缩回 1 时自动复位居中
        _viewPan = newZoom <= 1.001 ? Offset.zero : d.localFocalPoint - v0 * newZoom;
      });
    } else {
      _extendStroke(d.localFocalPoint);
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureZooming = false;
  }

  /// 离屏合成：原图分辨率画布上 dstOut 挖洞，导出 PNG 字节
  Future<Uint8List?> _apply() async {
    final image = _image;
    if (image == null || _strokes.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final full = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.saveLayer(full, Paint());
    canvas.drawImageRect(image, full, full, Paint());
    _paintStrokes(canvas, strokes: _strokes);
    canvas.restore();
    final composed = await recorder
        .endRecording()
        .toImage(image.width, image.height);
    final data = await composed.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// 把擦除笔画以 dstOut 画到画布上（图片坐标系）；
  /// 预览时调用方先 translate/scale 到显示区，导出时恒等变换
  static void _paintStrokes(Canvas canvas, {required List<_EraseStroke> strokes}) {
    if (strokes.isEmpty) return;
    final erase = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..blendMode = BlendMode.dstOut
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.points.length == 1) {
        canvas.drawCircle(
          s.points.first,
          s.radius,
          erase..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        erase
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.radius * 2,
      );
    }
  }

  Future<void> _onApply() async {
    if (_strokes.isEmpty) return;
    final bytes = await _apply();
    if (!mounted || bytes == null) return;
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'app_pixelEraser'.tr,
          style: const TextStyle(fontSize: 17, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'app_undo'.tr,
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'app_redo'.tr,
            icon: const Icon(Icons.redo),
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          IconButton(
            tooltip: 'app_pixelEraserReset'.tr,
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _resetView,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _strokes.isEmpty ? null : _onApply,
              child: Text('app_apply'.tr),
            ),
          ),
        ],
      ),
      body: image == null
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white70,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final scale = math.min(
                  size.width / image.width,
                  size.height / image.height,
                );
                _scale = scale;
                _dstRect = Rect.fromCenter(
                  center: size.center(Offset.zero),
                  width: image.width * scale,
                  height: image.height * scale,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: CustomPaint(
                    size: size,
                    painter: _ErasePreviewPainter(
                      image: image,
                      dstRect: _dstRect,
                      strokes: _strokes,
                      paintStrokes: _paintStrokes,
                      viewZoom: _viewZoom,
                      viewPan: _viewPan,
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'app_pixelEraserHint'.tr,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: Colors.white24,
                trackHeight: 2.5,
              ),
              child: Slider(
                min: 8,
                max: 120,
                value: _brushSize,
                onChanged: (v) => setState(() => _brushSize = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 擦除预览：棋盘格透明底 + 图片（dstOut 挖洞实时反映笔画）
class _ErasePreviewPainter extends CustomPainter {
  const _ErasePreviewPainter({
    required this.image,
    required this.dstRect,
    required this.strokes,
    required this.paintStrokes,
    this.viewZoom = 1,
    this.viewPan = Offset.zero,
  });

  final ui.Image image;
  final Rect dstRect;
  final List<_EraseStroke> strokes;

  /// 用户视图变换（双指缩放/平移），棋盘格与图片整体套用
  final double viewZoom;
  final Offset viewPan;

  /// 复用页面的笔画绘制（图片坐标系）
  final void Function(Canvas canvas, {required List<_EraseStroke> strokes})
  paintStrokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewPan.dx, viewPan.dy);
    canvas.scale(viewZoom);

    // 棋盘格（透明区域指示）
    const cell = 10.0;
    canvas.drawRect(dstRect, Paint()..color = const Color(0xFFE8E8E8));
    final dark = Paint()..color = const Color(0xFFBDBDBD);
    for (var y = 0.0; y < dstRect.height; y += cell) {
      for (var x = 0.0; x < dstRect.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(dstRect.left + x, dstRect.top + y, cell, cell),
            dark,
          );
        }
      }
    }

    // 图片 + 擦除（先变换到显示坐标系再按显示缩放重画笔画）
    canvas.saveLayer(dstRect, Paint());
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dstRect,
      Paint(),
    );
    canvas.save();
    canvas.translate(dstRect.left, dstRect.top);
    canvas.scale(dstRect.width / image.width);
    paintStrokes(canvas, strokes: strokes);
    canvas.restore();
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ErasePreviewPainter old) =>
      old.strokes != strokes ||
      old.dstRect != dstRect ||
      old.image != image ||
      old.viewZoom != viewZoom ||
      old.viewPan != viewPan;
}
