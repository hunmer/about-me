import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scrapbook_item_models.dart';

/// 素材变换框：边缘节点等比缩放，顶部手柄绕中心旋转。
class ScrapTransformFrame extends StatefulWidget {
  /// 为手柄预留实际布局空间，确保节点可以命中。
  static const padding = 36.0;

  final ScrapItemData item;
  final bool enabled;
  final Widget child;
  final VoidCallback onStart;
  final VoidCallback onUpdate;
  final VoidCallback onEnd;

  const ScrapTransformFrame({
    super.key,
    required this.item,
    required this.enabled,
    required this.child,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  State<ScrapTransformFrame> createState() => _ScrapTransformFrameState();
}

class _ScrapTransformFrameState extends State<ScrapTransformFrame> {
  final _contentKey = GlobalKey();
  Offset? _globalCenter;
  Offset _canvasCenter = Offset.zero;
  Size _initialSize = Size.zero;
  double _initialScale = 1;
  double _initialRotation = 0;
  double _initialDistance = 1;
  double _previousAngle = 0;
  double _angleDelta = 0;

  void _start(DragStartDetails details) {
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final item = widget.item;
    _initialSize = box.size;
    _globalCenter = box.localToGlobal(box.size.center(Offset.zero));
    _canvasCenter = Offset(
      item.x + box.size.width / 2,
      item.y + box.size.height / 2,
    );
    _initialScale = item.scale;
    _initialRotation = item.rotation;
    final vector = details.globalPosition - _globalCenter!;
    _initialDistance = math.max(vector.distance, 1);
    _previousAngle = math.atan2(vector.dy, vector.dx);
    _angleDelta = 0;
    widget.onStart();
  }

  void _resize(DragUpdateDetails details) {
    final center = _globalCenter;
    if (center == null) return;
    final item = widget.item;
    final distance = (details.globalPosition - center).distance;
    final nextScale = (_initialScale * distance / _initialDistance).clamp(
      0.2,
      4.0,
    );
    final ratio = nextScale / _initialScale;
    item.scale = nextScale;
    // 保持中心固定，已旋转的素材也不会在缩放时偏移。
    item.x = _canvasCenter.dx - _initialSize.width * ratio / 2;
    item.y = _canvasCenter.dy - _initialSize.height * ratio / 2;
    widget.onUpdate();
  }

  void _rotate(DragUpdateDetails details) {
    final center = _globalCenter;
    if (center == null) return;
    final vector = details.globalPosition - center;
    final angle = math.atan2(vector.dy, vector.dx);
    // 跨过 ±180° 时仍连续旋转。
    final delta = angle - _previousAngle;
    _angleDelta += math.atan2(math.sin(delta), math.cos(delta));
    _previousAngle = angle;
    widget.item.rotation =
        ((_initialRotation + _angleDelta * 180 / math.pi + 180) % 360) - 180;
    widget.onUpdate();
  }

  void _end() {
    if (_globalCenter == null) return;
    _globalCenter = null;
    widget.onEnd();
  }

  Widget _handle({
    required String label,
    required bool rotate,
    required String name,
  }) {
    return MouseRegion(
      cursor: rotate
          ? SystemMouseCursors.grab
          : SystemMouseCursors.resizeUpLeftDownRight,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          key: ValueKey('scrap_handle_$name'),
          behavior: HitTestBehavior.opaque,
          onPanStart: _start,
          onPanUpdate: rotate ? _rotate : _resize,
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Container(
                width: rotate ? 22 : 12,
                height: rotate ? 22 : 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFF001AFF),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(rotate ? 11 : 3),
                ),
                child: rotate
                    ? const Icon(
                        Icons.rotate_right,
                        size: 16,
                        color: Color(0xFF001AFF),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (!widget.enabled) return content;
    const padding = ScrapTransformFrame.padding;
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.all(padding), child: content),
        const Positioned(
          top: 22,
          left: 0,
          right: 0,
          height: 14,
          child: IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 1.5,
                height: 14,
                child: ColoredBox(color: Color(0xFF001AFF)),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _handle(label: '拖动旋转', rotate: true, name: 'rotate'),
          ),
        ),
        for (final alignment in [
          Alignment.topLeft,
          Alignment.topCenter,
          Alignment.topRight,
          Alignment.centerLeft,
          Alignment.centerRight,
          Alignment.bottomLeft,
          Alignment.bottomCenter,
          Alignment.bottomRight,
        ])
          Positioned.fill(
            left: padding - 14,
            right: padding - 14,
            top: padding - 14,
            bottom: padding - 14,
            child: Align(
              alignment: alignment,
              child: _handle(
                label: '拖动等比调整大小',
                rotate: false,
                name: '${alignment.x}_${alignment.y}',
              ),
            ),
          ),
      ],
    );
  }
}
