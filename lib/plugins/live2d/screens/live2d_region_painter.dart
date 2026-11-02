// 区域编辑器的独立绘制/输入部件（自 live2d_region_editor.dart 拆出，
// 满足单文件不超过 1000 行的仓库约定；私有类型经 part of 共享）。
part of 'live2d_region_editor.dart';

/// 0-1 边界数值输入：失焦时解析并钳制，回写控件文本
class _BoundField extends StatefulWidget {
  const _BoundField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  State<_BoundField> createState() => _BoundFieldState();
}

class _BoundFieldState extends State<_BoundField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_sync);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_sync);
    _focusNode.dispose();
    super.dispose();
  }

  void _sync() {
    if (_focusNode.hasFocus) return;
    final value = double.tryParse(widget.controller.text);
    if (value == null) return;
    final clamped = value.clamp(0.0, 1.0);
    widget.controller.text = clamped.toStringAsFixed(3);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      style: TextStyle(fontSize: 13, color: theme.text),
      decoration: InputDecoration(labelText: widget.label, isDense: true),
    );
  }
}

/// 归一化区域叠加层：绘制自定义矩形（半透明黑填充 + 高对比描边）与绘制草稿。
/// 黑色填充保证在任何模型底色（含绘制模式黑色蒙层之上）都清晰可辨。
class _RegionPainter extends CustomPainter {
  _RegionPainter({
    required this.regions,
    required this.selectedId,
    required this.draftRect,
  });

  final List<Live2DTapRegion> regions;
  final String? selectedId;
  final Rect? draftRect;

  /// 选中区域描边（琥珀，与黑色填充形成高对比）
  static const _selectedColor = Color(0xFFFFC107);

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      if (region.source != 'custom' || !region.hasBounds) continue;
      final width = (region.right! - region.left!).clamp(0.0, 1.0);
      final height = (region.bottom! - region.top!).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(
        region.left! * size.width,
        region.top! * size.height,
        width * size.width,
        height * size.height,
      );
      final selected = region.id == selectedId;
      // 半透明黑色填充：真实覆盖在模型画面上方的可绘制矩形区域
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: selected ? 0.45 : 0.30);
      canvas.drawRect(rect, paint);
      // 高对比描边：选中琥珀、其余白色，均压在黑色填充之上可见
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.4
        ..color = selected
            ? _selectedColor
            : Colors.white.withValues(alpha: 0.85);
      canvas.drawRect(rect, border);
      if (rect.width > 35 && rect.height > 18) {
        _drawLabel(canvas, region.name, rect);
      }
    }
    final draft = draftRect;
    if (draft != null) {
      final rect = Rect.fromLTWH(
        draft.left * size.width,
        draft.top * size.height,
        draft.width * size.width,
        draft.height * size.height,
      );
      // 草稿：淡琥珀填充 + 琥珀虚线描边，拖拽过程即时可见
      canvas.drawRect(
        rect,
        Paint()..color = _selectedColor.withValues(alpha: 0.10),
      );
      _drawDashedRect(canvas, rect);
    }
  }

  void _drawLabel(Canvas canvas, String label, Rect rect) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 8);
    final offset = Offset(
      rect.left + (rect.width - painter.width) / 2,
      rect.top + 4,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx - 3,
        offset.dy - 2,
        painter.width + 6,
        painter.height + 4,
      ),
      Paint()..color = Colors.black54,
    );
    painter.paint(canvas, offset);
  }

  void _drawDashedRect(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _selectedColor.withValues(alpha: 0.9);
    const dash = 6.0;
    void drawDashedLine(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) return;
      final direction = (to - from) / total;
      var start = 0.0;
      while (start < total) {
        final end = (start + dash).clamp(0.0, total);
        canvas.drawLine(
          from + direction * start,
          from + direction * end,
          paint,
        );
        start = end + dash;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.draftRect != draftRect;
}
