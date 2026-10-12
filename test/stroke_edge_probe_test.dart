import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/design_system/design_system.dart';

/// 临时验证：手绘描边（墨线，深色）应贴容器边缘，不受出血内缩影响
void main() {
  testWidgets('描边贴边验证：26x26 勾选框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(200, 200));
    final key = GlobalKey();
    final theme = AppThemeData.light();
    await tester.pumpWidget(
      MaterialApp(
        home: AppTheme(
          data: theme,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: 26,
                height: 26,
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: const Color(0xFF885CF6),
                  radius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 墨线色 = theme.ink = 0xFF4C1D95（深紫，亮度≈84）；
    // 填充 0xFF885CF6（亮度≈158）。用低阈值只统计墨线像素。
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final result = await tester.runAsync(() async {
      final ui.Image image = boundary.toImageSync(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = image.width;
      final h = image.height;
      final data = bytes!.buffer.asUint8List();
      int minDist = 1 << 30;
      final cy = h ~/ 2;
      for (var x = 0; x < w; x++) {
        final i = (cy * w + x) * 4;
        final lum = (data[i] + data[i + 1] + data[i + 2]) / 3;
        if (lum < 120) {
          final d = math.min(x, w - 1 - x);
          if (d < minDist) minDist = d;
        }
      }
      return minDist;
    });
    debugPrint('墨线最近像素距边缘(物理px)=$result，逻辑px=${result! / 4}');
    expect(result, lessThanOrEqualTo(6),
        reason: '描边应贴容器边缘（4x 下 <=6 物理像素 ≈ 1.5 逻辑像素）');
  });
}
