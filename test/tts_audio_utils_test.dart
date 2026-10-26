import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/tts/services/tts_audio_utils.dart';

void main() {
  test('raw PCM16 is wrapped as playable WAV', () {
    final wav = pcm16ToWav(<int>[0, 0, 0xff, 0x7f]);

    expect(wav, isA<Uint8List>());
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 48);
    expect(wav[24] | (wav[25] << 8), 32000);
    expect(wav[40] | (wav[41] << 8), 4);
  });

  test('WAV input is not wrapped twice', () {
    final input = Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46]);
    expect(pcm16ToWav(input), input);
  });
}
