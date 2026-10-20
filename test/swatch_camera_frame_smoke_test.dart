import 'package:aboutme/widgets/swatch_camera_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final ratio in SwatchFrameRatio.values) {
    testWidgets('golden ${ratio.name}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFE6E3DC),
          body: Center(
            child: SizedBox(
              width: 390,
              height: 780,
              child: RepaintBoundary(
                key: const ValueKey('shot'),
                child: SwatchCameraFrame(ratio: ratio, autoPlay: false),
              ),
            ),
          ),
        ),
      ));
      // 手动触发并推进到 FLASH 阶段（背面取景器完整可见）
      await tester.tap(find.byType(SwatchCameraFrame));
      await tester.pump();
      for (var i = 0; i < 13; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await expectLater(
        find.byKey(const ValueKey('shot')),
        matchesGoldenFile('goldens/swatch_back_${ratio.name}.png'),
      );
      // 继续推进确认无异常
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.tap(find.byType(SwatchCameraFrame));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    });
  }
}
