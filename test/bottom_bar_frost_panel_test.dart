import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aboutme/design_system/components/bottom_bar_frost_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('背景从清晰渐入模糊，羽化宽度与模糊参数实际改变像素', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(240, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Future<Uint8List> render({
      required String name,
      double? feather,
      double sigma = 12,
      Color tint = const Color(0x00FFFFFF),
    }) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _Stripes()),
                if (feather != null)
                  Positioned(
                    top: 80,
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: BottomBarFrostPanel(
                      blurSigma: sigma,
                      featherRadius: feather,
                      tintFade: 0.5,
                      tintColor: tint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          if (const bool.fromEnvironment('FROST_PREVIEW')) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('outputs/bottom_bar_frost/$name.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
          }
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
    }

    final original = await render(name: 'original');
    final hard = await render(name: 'hard', feather: 0);
    final soft = await render(name: 'soft', feather: 48);
    final narrow = await render(name: 'narrow', feather: 24);
    final noBlur = await render(name: 'no_blur', feather: 48, sigma: 0);
    final maxSettings = await render(
      name: 'max_settings',
      feather: 48,
      sigma: 30,
      tint: const Color(0x30FFFFFF),
    );

    double rowDifference(Uint8List pixels, int y) {
      var sum = 0.0;
      for (var x = 24; x < 216; x++) {
        final offset = (y * 240 + x) * 4;
        sum += (pixels[offset] - original[offset]).abs();
      }
      return sum / 192;
    }

    debugPrint(
      '[Frost pixels] hardTop=${rowDifference(hard, 80)}, '
      'softTop=${rowDifference(soft, 80)}, '
      'softMiddle=${rowDifference(soft, 104)}, '
      'softBody=${rowDifference(soft, 140)}, '
      'maxTop=${rowDifference(maxSettings, 80)}',
    );
    expect(rowDifference(soft, 79), 0, reason: '不能影响面板外的页面');
    expect(rowDifference(hard, 80), greaterThan(60));
    expect(rowDifference(soft, 80), lessThan(3), reason: '软边起点必须保留原始背景');
    expect(rowDifference(soft, 88), lessThan(rowDifference(soft, 104)));
    expect(rowDifference(soft, 104), lessThan(rowDifference(soft, 140)));
    expect(
      rowDifference(soft, 92),
      lessThan(rowDifference(narrow, 92)),
      reason: '增大羽化必须扩展清晰到模糊的过渡带',
    );
    expect(rowDifference(soft, 140), greaterThan(60), reason: '主体必须真实模糊背景');
    expect(rowDifference(noBlur, 140), 0, reason: '模糊为零时不能留下白底');
    expect(
      rowDifference(maxSettings, 80),
      lessThan(3),
      reason: '参数拉满也不能产生顶部硬边',
    );
  });
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 8, size.height),
        Paint()..color = (x ~/ 8).isEven ? Colors.black : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}
