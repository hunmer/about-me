import 'dart:math' as math;

/// 一帧语音分析结果。元音置信度总和约为 1，口型开合值始终在 0~1。
class Live2DVoiceFrame {
  const Live2DVoiceFrame({
    required this.silence,
    required this.a,
    required this.i,
    required this.u,
    required this.e,
    required this.o,
    required this.mouthOpenY,
  });

  final double silence;
  final double a;
  final double i;
  final double u;
  final double e;
  final double o;
  final double mouthOpenY;

  Map<String, double> get vowels => {
    'VoiceSilence': silence,
    'VoiceA': a,
    'VoiceI': i,
    'VoiceU': u,
    'VoiceE': e,
    'VoiceO': o,
  };
}

/// pymouth 的 VowelAnalyser 的 Dart 移植：MFCC + DTW + 温度 softmax。
///
/// 输入应为 [-1, 1] 范围的单声道 PCM。分析器不负责播放音频，因此可复用于
/// TTS PCM 回调、录音流或测试数据。
class Live2DVoiceAnalyzer {
  Live2DVoiceAnalyzer({this.temperature = 10.0})
    : assert(temperature > 0, 'temperature must be positive');

  final double temperature;
  double _mouth = 0;

  static const _fftReferences = [128, 512, 1024, 2048, 4096];
  static const _templates = <String, List<List<double>>>{
    'VoiceA': [
      [157.28203, -18.084631],
      [184.55794, -70.21922],
      [180.11708, -69.37925],
      [186.3136, -68.28505],
      [184.01038, -62.837513],
      [181.70918, -56.22454],
      [183.93184, -55.787033],
      [177.58957, -55.56417],
      [210.36815, -42.245583],
    ],
    'VoiceI': [
      [154.23402, -66.638794],
      [109.41006, -76.42681],
      [104.646484, -79.092224],
      [100.69435, -73.16504],
      [106.442406, -68.50664],
      [104.717026, -67.13239],
      [98.70581, -67.052155],
      [90.54036, -64.939255],
      [96.68744, -4.7852263],
    ],
    'VoiceU': [
      [177.38, -21.598547],
      [163.56247, -60.48896],
      [162.29306, -65.40919],
      [147.10324, -77.276535],
      [145.81586, -81.49585],
      [141.00285, -80.76966],
      [137.3823, -83.69654],
      [125.162674, -86.36088],
      [182.829, -57.803486],
    ],
    'VoiceE': [
      [45.139225, -3.552611],
      [82.19922, -65.22143],
      [154.64558, -90.886116],
      [153.86205, -97.447235],
      [158.62253, -77.25729],
      [155.23709, -56.107735],
      [149.8651, -64.127594],
      [145.0244, -55.381966],
      [175.49411, -33.858017],
    ],
    'VoiceO': [
      [224.24329, -10.556553],
      [193.64792, -22.315527],
      [186.96034, -20.628428],
      [184.96133, -16.40874],
      [186.04208, -22.023905],
      [185.25256, -11.928689],
      [185.24428, -5.041305],
      [181.70624, -3.2469425],
      [131.43114, 3.3550904],
    ],
    'VoiceSilence': [
      [52.750603, -4.9177713],
      [84.026146, 21.443743],
      [77.42841, 2.3937027],
      [85.50844, 21.711079],
      [80.75325, 7.308112],
      [82.622925, 16.251738],
      [69.67996, 10.19037],
      [80.5309, 6.884417],
      [71.37026, 22.482405],
    ],
  };

  /// 分析一块 PCM。过短或静音输入仍返回完整的置信度结构。
  Live2DVoiceFrame processPcm(
    List<double> samples,
    int sampleRate, {
    int channels = 1,
  }) {
    if (samples.isEmpty || sampleRate <= 0) return _silence();
    if (channels > 1) {
      final mono = <double>[];
      for (var i = 0; i + channels <= samples.length; i += channels) {
        var sum = 0.0;
        for (var channel = 0; channel < channels; channel++) {
          sum += samples[i + channel];
        }
        mono.add(sum / channels);
      }
      samples = mono;
    }
    final rms = math.sqrt(
      samples.fold<double>(0, (s, x) => s + x * x) / samples.length,
    );
    final targetMouth = ((rms - 0.012) / 0.18).clamp(0.0, 1.0).toDouble();
    _mouth = _mouth * 0.55 + targetMouth * 0.45;
    if (rms < 0.012) return _silence(mouth: _mouth);
    final nFft = _getNfft(samples.length, sampleRate);
    final mfcc = _mfcc(samples, sampleRate, nFft);
    if (mfcc.length < 5) return _silence(mouth: _mouth);

    final names = [
      'VoiceSilence',
      'VoiceA',
      'VoiceI',
      'VoiceU',
      'VoiceE',
      'VoiceO',
    ];
    final distances = names
        .map((name) => _dtw(_templates[name]!, mfcc))
        .toList();
    final maxValue = distances.map((x) => -x / temperature).reduce(math.max);
    final weights = distances
        .map((x) => math.exp(-x / temperature - maxValue))
        .toList();
    final total = weights.fold<double>(0, (s, x) => s + x);
    final p = weights.map((x) => x / total).toList();
    return Live2DVoiceFrame(
      silence: p[0],
      a: p[1],
      i: p[2],
      u: p[3],
      e: p[4],
      o: p[5],
      mouthOpenY: _mouth,
    );
  }

  /// 解析 little-endian PCM16 WAV；其他格式由调用方先解码为 PCM。
  Live2DVoiceFrame processPcm16(List<int> bytes, int sampleRate) {
    var offset = 0;
    var rate = sampleRate;
    var channels = 1;
    if (bytes.length >= 44 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF') {
      offset = 44;
      rate =
          bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);
      channels = bytes[22] | (bytes[23] << 8);
    }
    final samples = <double>[];
    for (var i = offset; i + 1 < bytes.length; i += 2) {
      var value = bytes[i] | (bytes[i + 1] << 8);
      if (value >= 0x8000) value -= 0x10000;
      samples.add(value / 32768.0);
    }
    return processPcm(samples, rate, channels: channels);
  }

  Live2DVoiceFrame _silence({double mouth = 0}) => Live2DVoiceFrame(
    silence: 1,
    a: 0,
    i: 0,
    u: 0,
    e: 0,
    o: 0,
    mouthOpenY: mouth,
  );

  int _getNfft(int size, int sampleRate) {
    final desired = sampleRate * 0.023;
    if (desired > size) return size;
    return _fftReferences.reduce(
      (a, b) => (a - desired).abs() < (b - desired).abs() ? a : b,
    );
  }

  List<List<double>> _mfcc(List<double> input, int sampleRate, int nFft) {
    final frameCount = (input.length / (nFft ~/ 2)).floor().clamp(1, 1000);
    final rows = <List<double>>[];
    for (var frame = 0; frame < frameCount; frame++) {
      final start = frame * (nFft ~/ 2);
      final values = List<double>.filled(nFft, 0);
      for (var i = 0; i < nFft && start + i < input.length; i++) {
        values[i] =
            input[start + i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / nFft));
      }
      final spectrum = List<double>.filled(nFft ~/ 2 + 1, 0);
      for (var k = 0; k <= nFft ~/ 2; k++) {
        var re = 0.0;
        var im = 0.0;
        for (var n = 0; n < nFft; n++) {
          final angle = 2 * math.pi * k * n / nFft;
          re += values[n] * math.cos(angle);
          im -= values[n] * math.sin(angle);
        }
        spectrum[k] = re * re + im * im;
      }
      final mel = List<double>.filled(128, 0);
      for (var m = 0; m < 128; m++) {
        final left = _melBin(m, 128, sampleRate, nFft);
        final center = _melBin(m + 1, 128, sampleRate, nFft);
        final right = _melBin(m + 2, 128, sampleRate, nFft);
        for (var k = left; k <= right && k < spectrum.length; k++) {
          final weight = k < center
              ? (k - left) / math.max(1, center - left)
              : (right - k) / math.max(1, right - center);
          mel[m] += spectrum[k] * math.max(0, weight);
        }
      }
      final logMel = mel
          .map((x) => 10 * math.log(math.max(x, 1e-10)) / math.ln10)
          .toList();
      rows.add([_dct(logMel, 1), _dct(logMel, 2)]);
    }
    return rows;
  }

  int _melBin(int index, int count, int sampleRate, int nFft) {
    final mel = 1127 * math.log(1 + (sampleRate / 2) / 700);
    final value = mel * index / (count + 1);
    final hz = 700 * (math.exp(value / 1127) - 1);
    return (hz / sampleRate * nFft).floor().clamp(0, nFft ~/ 2);
  }

  double _dct(List<double> values, int k) {
    var result = 0.0;
    for (var n = 0; n < values.length; n++) {
      result += values[n] * math.cos(math.pi * k * n / (values.length - 1));
    }
    return result;
  }

  double _dtw(List<List<double>> reference, List<List<double>> input) {
    final costs = List.generate(
      reference.length + 1,
      (_) => List<double>.filled(input.length + 1, double.infinity),
    );
    costs[0][0] = 0;
    for (var i = 1; i <= reference.length; i++) {
      for (var j = 1; j <= input.length; j++) {
        final dx = reference[i - 1][0] - input[j - 1][0];
        final dy = reference[i - 1][1] - input[j - 1][1];
        final distance = math.sqrt(dx * dx + dy * dy);
        costs[i][j] =
            distance +
            math.min(
              costs[i - 1][j],
              math.min(costs[i][j - 1], costs[i - 1][j - 1]),
            );
      }
    }
    return costs[reference.length][input.length] /
        (reference.length + input.length);
  }
}
