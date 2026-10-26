import 'dart:typed_data';

/// Converts raw signed PCM16 little-endian bytes to a WAV file that audio
/// players can identify without additional format metadata.
Uint8List pcm16ToWav(
  List<int> pcmBytes, {
  int sampleRate = 32000,
  int channels = 1,
}) {
  if (pcmBytes.length >= 4 &&
      pcmBytes[0] == 0x52 &&
      pcmBytes[1] == 0x49 &&
      pcmBytes[2] == 0x46 &&
      pcmBytes[3] == 0x46) {
    return Uint8List.fromList(pcmBytes);
  }
  final dataLength = pcmBytes.length;
  final byteRate = sampleRate * channels * 2;
  final blockAlign = channels * 2;
  final output = ByteData(44 + dataLength);
  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      output.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  output.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  output.setUint32(16, 16, Endian.little);
  output.setUint16(20, 1, Endian.little);
  output.setUint16(22, channels, Endian.little);
  output.setUint32(24, sampleRate, Endian.little);
  output.setUint32(28, byteRate, Endian.little);
  output.setUint16(32, blockAlign, Endian.little);
  output.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  output.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < dataLength; i++) {
    output.setUint8(44 + i, pcmBytes[i] & 0xff);
  }
  return output.buffer.asUint8List();
}

bool isPcmAudioFormat(String? format) {
  final normalized = format
      ?.toLowerCase()
      .replaceFirst('audio/', '')
      .replaceFirst('.', '');
  return normalized == 'pcm' ||
      normalized == 's16le' ||
      normalized == 'pcm_s16le' ||
      normalized == 'raw';
}
