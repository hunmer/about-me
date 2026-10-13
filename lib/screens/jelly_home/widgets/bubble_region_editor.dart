import 'package:flutter/material.dart';

import 'jelly_speech_bubble.dart';
import 'jelly_configurable_image.dart';

import 'package:get/get.dart';
Future<BubbleTextRegions?> showBubbleRegionEditor({
  required BuildContext context,
  required String asset,
  required BubbleTextRegions initial,
}) {
  return showDialog<BubbleTextRegions>(
    context: context,
    builder: (_) => _BubbleRegionEditor(asset: asset, initial: initial),
  );
}

class _BubbleRegionEditor extends StatefulWidget {
  const _BubbleRegionEditor({required this.asset, required this.initial});
  final String asset;
  final BubbleTextRegions initial;

  @override
  State<_BubbleRegionEditor> createState() => _BubbleRegionEditorState();
}

class _BubbleRegionEditorState extends State<_BubbleRegionEditor> {
  late Rect _name = widget.initial.modelName;
  late Rect _message = widget.initial.message;
  String _mode = 'name';
  Offset? _start;

  void _begin(DragStartDetails details) => _start = details.localPosition;

  void _update(DragUpdateDetails details, Size size) {
    final start = _start;
    if (start == null) return;
    final current = details.localPosition;
    final rect = Rect.fromPoints(start, current);
    final normalized = Rect.fromLTRB(
      (rect.left / size.width).clamp(0.0, 1.0),
      (rect.top / size.height).clamp(0.0, 1.0),
      (rect.right / size.width).clamp(0.0, 1.0),
      (rect.bottom / size.height).clamp(0.0, 1.0),
    );
    setState(() {
      if (_mode == 'name') {
        _name = normalized;
      } else {
        _message = normalized;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('screens_markBubbleRegion'.tr),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('screens_markBubbleRegionDesc'.tr),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onPanStart: _begin,
                  onPanUpdate: (details) =>
                      _update(details, constraints.biggest),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      JellyConfigurableImage(
                        path: widget.asset,
                        fit: BoxFit.fill,
                      ),
                      _regionBox(_name, constraints.biggest, Colors.red, '名称'),
                      _regionBox(
                        _message,
                        constraints.biggest,
                        Colors.blue,
                        '正文',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'name', label: Text('模型名称区域')),
                ButtonSegment(value: 'message', label: Text('正文区域')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('app_cancel'.tr),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, BubbleTextRegions(_name, _message)),
          child: Text('app_save'.tr),
        ),
      ],
    );
  }

  Widget _regionBox(Rect rect, Size size, Color color, String label) {
    return Positioned.fromRect(
      rect: Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      ),
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            color: color.withValues(alpha: 0.12),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ColoredBox(
              color: color,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
