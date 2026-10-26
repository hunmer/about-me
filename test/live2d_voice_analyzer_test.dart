import 'dart:math' as math;
import 'dart:typed_data';

import 'package:glint_audio_pure/glint_audio_pure.dart';
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

  test('MP3 可以解码为 PCM 并进入 DTW 分析', () {
    final source = Float64List.fromList(
      List<double>.generate(
        2304,
        (i) => math.sin(i * 2 * math.pi * 440 / 32000) * 0.3,
      ),
    );
    final mp3 = mp3EncodeMono(source, sampleRate: 32000, bitrate: 32);
    final frame = Live2DVoiceAnalyzer().processMp3(mp3);

    expect(frame.mouthOpenY, inInclusiveRange(0, 1));
    expect(
      frame.vowels.values.fold<double>(0, (sum, value) => sum + value),
      closeTo(1, 1e-9),
    );
  });
}
