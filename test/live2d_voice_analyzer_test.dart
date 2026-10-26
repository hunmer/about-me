import 'dart:math' as math;

import 'package:aboutme/plugins/live2d/live2d_voice_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('静音和音量映射保持在有效范围', () {
    final analyzer = Live2DVoiceAnalyzer();
    final silence = analyzer.processPcm(List<double>.filled(4096, 0), 32000);
    expect(silence.silence, 1);
    expect(silence.mouthOpenY, 0);

    final loud = analyzer.processPcm(
      List<double>.generate(4096, (i) => math.sin(i / 4) * 0.4),
      32000,
    );
    expect(loud.mouthOpenY, inInclusiveRange(0, 1));
    expect(
      loud.vowels.values.fold<double>(0, (sum, value) => sum + value),
      closeTo(1, 1e-9),
    );
  });
}
