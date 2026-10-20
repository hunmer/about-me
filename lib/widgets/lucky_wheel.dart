import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// 时计幸运转盘（极简 SVG 幸运大转盘的 Flutter 移植版）
///
/// 特性：
/// - 8 扇区表盘（金 / 曜石 / 象牙三种主题渐变）
/// - 72 刻度表圈、缓慢旋转的虚线装饰环
/// - 中央表冠点击启动，easeOutQuint 6.8s 悬念减速
/// - 擒纵指针弹簧物理 + 程序合成棘轮滴答 / 中奖和弦音效（无需音频资源）
/// - 中奖后金粉粒子庆祝 + 结果卡片
class LuckyWheel extends StatefulWidget {
  const LuckyWheel({super.key});

  @override
  State<LuckyWheel> createState() => _LuckyWheelState();
}

enum _SectorTheme { gold, obsidian, ivory }

class _Prize {
  const _Prize({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final String id;
  final String title;
  final String subtitle;
  final _SectorTheme theme;
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double alpha;
  double decay;
  double rotation;
  double vRot;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.alpha,
    required this.decay,
    required this.rotation,
    required this.vRot,
  });
}

class _LuckyWheelState extends State<LuckyWheel>
    with SingleTickerProviderStateMixin {
  static const double _center = 300;
  static const double _sectorAngle = 45;
  static const double _spinDurationMs = 6800;

  static const _prizes = [
    _Prize(
        id: 'grand',
        title: '鎏金陀飞轮礼盒',
        subtitle: 'GRAND ARCHIVE',
        theme: _SectorTheme.gold),
    _Prize(
        id: 'points_100',
        title: '100 灵感积分',
        subtitle: '100 CREDITS',
        theme: _SectorTheme.ivory),
    _Prize(
        id: 'fragrance',
        title: '雪松琥珀香氛',
        subtitle: 'ATELIER SCENT',
        theme: _SectorTheme.obsidian),
    _Prize(
        id: 'thanks',
        title: '静候佳音',
        subtitle: 'SERENDIPITY',
        theme: _SectorTheme.ivory),
    _Prize(
        id: 'vinyl',
        title: '黑胶典藏唱片',
        subtitle: 'LIMITED VINYL',
        theme: _SectorTheme.obsidian),
    _Prize(
        id: 'voucher',
        title: '八折定制礼券',
        subtitle: 'PRIVILEGE 20%',
        theme: _SectorTheme.ivory),
    _Prize(
        id: 'membership',
        title: '年度黑卡会籍',
        subtitle: 'NOIR MEMBER',
        theme: _SectorTheme.obsidian),
    _Prize(
        id: 'points_500',
        title: '500 灵感积分',
        subtitle: '500 CREDITS',
        theme: _SectorTheme.ivory),
  ];

  late final Ticker _ticker;
  final _stopwatch = Stopwatch();
  final _random = math.Random();

  // 状态
  bool _isSpinning = false;
  int _chances = 3;
  double _currentRotation = 0;
  double _pointerAngle = 0;
  double _pointerVelocity = 0;
  int? _highlightIndex;
  _Prize? _result;
  bool _soundEnabled = true;

  // 转动动画
  double _spinStartRotation = 0;
  double _spinTotalDelta = 0;
  Duration _spinStartTime = Duration.zero;
  int _lastPegIndex = 0;
  int _pendingWinner = 0;
  bool _spinCompleted = false;
  Duration _lastTickSoundTime = Duration.zero;

  // 粒子
  final List<_Particle> _particles = [];

  // 音效（SoLoud 低延迟引擎 + 程序合成 WAV）
  static const int _tickLevels = 8;
  final List<AudioSource> _tickSources = [];
  AudioSource? _chimeSource;
  bool _audioReady = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _stopwatch.start();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _initAudio() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init();
      }
      for (var level = 0; level < _tickLevels; level++) {
        _tickSources.add(await soloud.loadMem(
          'lucky_wheel_tick_$level.wav',
          _synthTick(level / (_tickLevels - 1)),
        ));
      }
      _chimeSource =
          await soloud.loadMem('lucky_wheel_chime.wav', _synthChime());
      _audioReady = true;
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) {
      for (final s in _tickSources) {
        soloud.disposeSource(s);
      }
      final chime = _chimeSource;
      if (chime != null) soloud.disposeSource(chime);
    }
    _stopwatch.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------- 动画主循环

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_isSpinning) {
      _updateSpin(elapsed);
    }
    _updateParticles();
    setState(() {});
  }

  static double _easeOutQuint(double t) => 1 - math.pow(1 - t, 5).toDouble();

  void _updateSpin(Duration elapsed) {
    final progress =
        ((elapsed - _spinStartTime).inMilliseconds / _spinDurationMs)
            .clamp(0.0, 1.0);
    final eased = _easeOutQuint(progress);
    final currentAngle = _spinStartRotation + _spinTotalDelta * eased;
    final angularVelocity = currentAngle - _currentRotation; // 每帧角度
    _currentRotation = currentAngle;

    // 边界销钉经过 12 点方向 -> 指针被拨动 + 滴答声
    final pegIndex =
        ((currentAngle + _sectorAngle / 2) / _sectorAngle).floor();
    if (pegIndex > _lastPegIndex) {
      _lastPegIndex = pegIndex;
      final speedNorm =
          math.min(1.0, math.max(0.12, angularVelocity / 14));
      _pointerAngle = -math.min(34.0, 14 + speedNorm * 22);
      _pointerVelocity = 2.5;
      _playTick(speedNorm);
    }

    // 指针弹簧阻尼回摆
    const springStiffness = 0.22;
    const damping = 0.78;
    final springForce = -springStiffness * _pointerAngle;
    _pointerVelocity = (_pointerVelocity + springForce) * damping;
    _pointerAngle += _pointerVelocity;

    if (progress >= 1 && _pointerAngle.abs() <= 0.3 && !_spinCompleted) {
      _spinCompleted = true;
      _pointerAngle = 0;
      _pointerVelocity = 0;
      _completeSpin(_pendingWinner);
    }
  }

  void _updateParticles() {
    if (_particles.isEmpty) return;
    var alive = false;
    for (final p in _particles) {
      if (p.alpha <= 0) continue;
      alive = true;
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.06;
      p.vx *= 0.985;
      p.alpha -= p.decay;
      p.rotation += p.vRot;
    }
    if (!alive) _particles.clear();
  }

  // ---------------------------------------------------------------- 转动逻辑

  void _triggerSpin() {
    if (_isSpinning || _chances <= 0) return;
    setState(() {
      _isSpinning = true;
      _spinCompleted = false;
      _chances -= 1;
      _highlightIndex = null;
      _result = null;
    });

    const numSectors = 8;
    final winningIndex = _random.nextInt(numSectors);

    final desiredMod = (360 - winningIndex * _sectorAngle) % 360;
    final currentMod = ((_currentRotation % 360) + 360) % 360;
    var deltaToDesired = desiredMod - currentMod;
    if (deltaToDesired <= 0) deltaToDesired += 360;

    final naturalJitter = (_random.nextDouble() - 0.5) * 22;
    final extraSpins = (7 + _random.nextInt(2)) * 360;

    _spinStartRotation = _currentRotation;
    _spinTotalDelta = extraSpins + deltaToDesired + naturalJitter;
    _spinStartTime = _stopwatch.elapsed;
    _lastPegIndex =
        ((_spinStartRotation + _sectorAngle / 2) / _sectorAngle).floor();
    _pendingWinner = winningIndex;
  }

  void _completeSpin(int winningIndex) {
    final prize = _prizes[winningIndex];
    setState(() {
      _isSpinning = false;
      _highlightIndex = winningIndex;
      _result = prize;
    });
    _playChime();
    _launchGoldDust();
  }

  void _dismissResult() {
    setState(() {
      _result = null;
      _highlightIndex = null;
    });
  }

  void _launchGoldDust() {
    const colors = [
      Color(0xFFC5A059),
      Color(0xFFDFC593),
      Color(0xFF18181B),
      Color(0xFFA1A1AA),
    ];
    _particles.clear();
    for (var i = 0; i < 42; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 1.5 + _random.nextDouble() * 4.5;
      _particles.add(_Particle(
        x: _center,
        y: _center,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 1.2,
        size: 2 + _random.nextDouble() * 3.5,
        color: colors[_random.nextInt(colors.length)],
        alpha: 1,
        decay: 0.012 + _random.nextDouble() * 0.012,
        rotation: _random.nextDouble() * math.pi,
        vRot: (_random.nextDouble() - 0.5) * 0.1,
      ));
    }
  }

  // ---------------------------------------------------------------- 程序合成音效

  void _playTick(double velocityFactor) {
    if (!_soundEnabled || !_audioReady) return;
    final now = _stopwatch.elapsed;
    // 高速旋转时销钉极密，限制最小间隔避免声音糊成一片
    if ((now - _lastTickSoundTime).inMilliseconds < 20) return;
    _lastTickSoundTime = now;

    final level = (velocityFactor * (_tickLevels - 1))
        .round()
        .clamp(0, _tickLevels - 1);
    if (level < _tickSources.length) {
      try {
        SoLoud.instance.play(_tickSources[level]);
      } catch (_) {}
    }
  }

  void _playChime() {
    if (!_soundEnabled || !_audioReady) return;
    final source = _chimeSource;
    if (source == null) return;
    try {
      SoLoud.instance.play(source);
    } catch (_) {}
  }

  /// 合成 28ms 三角波棘轮滴答（高频 -> 低频指数扫频）
  static Uint8List _synthTick(double velocityFactor) {
    const sampleRate = 22050;
    const duration = 0.03;
    final count = (sampleRate * duration).round();
    final f0 = 950 + math.min(velocityFactor * 450, 600);
    final vol = math.min(0.18, math.max(0.04, velocityFactor * 0.15));
    final samples = Float64List(count);
    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final t = i / sampleRate;
      final frac = (t / 0.028).clamp(0.0, 1.0);
      final freq = f0 * math.pow(140 / f0, frac);
      phase += 2 * math.pi * freq / sampleRate;
      final tri = 2 / math.pi * math.asin(math.sin(phase));
      final env = vol * math.pow(0.001 / vol, frac);
      samples[i] = tri * env;
    }
    return _encodeWav(samples, sampleRate);
  }

  /// 合成中奖和弦（C5 E5 G5 C6 依次延迟 70ms 的正弦泛音衰减）
  static Uint8List _synthChime() {
    const sampleRate = 22050;
    const notes = [523.25, 659.25, 783.99, 1046.50];
    final total = (sampleRate * (3 * 0.07 + 1.45)).round();
    final samples = Float64List(total);
    for (var k = 0; k < notes.length; k++) {
      final start = (k * 0.07 * sampleRate).round();
      final len = (1.45 * sampleRate).round();
      for (var i = 0; i < len && start + i < total; i++) {
        final t = i / sampleRate;
        final env = t < 0.02
            ? (t / 0.02) * 0.08
            : 0.08 * math.pow(0.0001 / 0.08, (t - 0.02) / 1.38);
        samples[start + i] += math.sin(2 * math.pi * notes[k] * t) * env;
      }
    }
    return _encodeWav(samples, sampleRate);
  }

  static Uint8List _encodeWav(Float64List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final bytes = ByteData(44 + dataSize);
    void writeStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bytes.setInt16(44 + i * 2, v, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F6F2),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'EDITION N° 08 · HOROLOGY WHEEL',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3.8,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '时计转盘 · 寻觅吉光',
                      style: TextStyle(
                        fontSize: 24,
                        letterSpacing: 2,
                        color: Color(0xFF18181B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWheelArea(),
                    const SizedBox(height: 16),
                    _buildResultArea(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFC5A059),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ATELIER CHRONO',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
              color: Color(0xFF27272A),
            ),
          ),
          const Spacer(),
          Text(
            '今日礼遇',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: Colors.grey.shade500,
            ),
          ),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade300,
          ),
          Text(
            _chances.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF18181B),
            ),
          ),
          IconButton(
            iconSize: 18,
            color: Colors.grey.shade500,
            tooltip: '切换音效',
            icon: Icon(
                _soundEnabled ? Icons.volume_up_outlined : Icons.volume_off),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 490.0);
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.16),
              radius: 0.85,
              colors: [Color(0x14C5A059), Color(0x00F7F6F2)],
            ),
          ),
          child: CustomPaint(
            painter: _WheelPainter(
              rotation: _currentRotation,
              pointerAngle: _pointerAngle,
              elapsed: _stopwatch.elapsed,
              isSpinning: _isSpinning,
              highlightIndex: _highlightIndex,
              particles: _particles,
              prizes: _prizes,
              chances: _chances,
            ),
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _triggerSpin,
                child: SizedBox(
                  width: size * 108 / 600,
                  height: size * 108 / 600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultArea() {
    return SizedBox(
      height: 80,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          child: _result == null
              ? Text(
                  _isSpinning
                      ? '时计齿轮精密运转中 · 请静候'
                      : (_chances > 0
                          ? '轻触中央表冠 · 开启时计垂青'
                          : '今日礼遇已臻圆满 · 感谢莅临'),
                  key: ValueKey('prompt_$_isSpinning$_chances'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    color: Colors.grey.shade400,
                  ),
                )
              : _buildResultCard(_result!),
        ),
      ),
    );
  }

  Widget _buildResultCard(_Prize prize) {
    return Container(
      key: ValueKey('result_${prize.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF18181B),
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _PrizeIconPainter(prize.id, const Color(0xFFDFC593)),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prize.subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFC5A059),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                prize.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF18181B),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: _dismissResult,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '收入囊中',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF27272A),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFD4D4D8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 表盘绘制

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.rotation,
    required this.pointerAngle,
    required this.elapsed,
    required this.isSpinning,
    required this.highlightIndex,
    required this.particles,
    required this.prizes,
    required this.chances,
  });

  final double rotation;
  final double pointerAngle;
  final Duration elapsed;
  final bool isSpinning;
  final int? highlightIndex;
  final List<_Particle> particles;
  final List<_Prize> prizes;
  final int chances;

  static const double _c = 300;
  static const double _outerR = 246;
  static const double _innerR = 56;

  static const _ink = Color(0xFF18181B);
  static const _gold = Color(0xFFC5A059);
  static const _goldLight = Color(0xFFDFC593);
  static const _cream = Color(0xFFFAF9F5);

  static final _goldGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6CFA0),
      Color(0xFFC5A059),
      Color(0xFF9A7836),
      Color(0xFFDFC593),
    ],
    stops: [0.0, 0.45, 0.75, 1.0],
  );

  static final _champagneGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      const Color(0xFFD4BC8B).withValues(alpha: 0.3),
      const Color(0xFFC5A059).withValues(alpha: 0.8),
    ],
  );

  static final _obsidianGradient = const RadialGradient(
    colors: [Color(0xFF27272A), Color(0xFF141417)],
  );

  static final _ivoryGradient = const RadialGradient(
    center: Alignment.center,
    radius: 0.7,
    colors: [Color(0xFFFFFFFF), Color(0xFFF3EFE6)],
  );

  Offset _polar(double r, double angleDeg) {
    final rad = (angleDeg - 90) * math.pi / 180;
    return Offset(_c + r * math.cos(rad), _c + r * math.sin(rad));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 600;
    canvas.save();
    canvas.scale(scale);

    _drawBezel(canvas);
    _drawRotor(canvas);
    _drawHub(canvas);
    _drawPointer(canvas);
    _drawParticles(canvas);

    canvas.restore();
  }

  Path _dashedCircle(double r, double dash, double gap) {
    final src = Path()
      ..addOval(Rect.fromCircle(center: const Offset(_c, _c), radius: r));
    final out = Path();
    for (final metric in src.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d = end + gap;
      }
    }
    return out;
  }

  void _drawBezel(Canvas canvas) {
    final rect = Rect.fromCircle(center: const Offset(_c, _c), radius: 284);

    // 外圈细环
    canvas.drawCircle(
      const Offset(_c, _c),
      284,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE4E2DD),
    );

    // 缓慢旋转的虚线香槟金环（90s 一圈）
    final orbitAngle = (elapsed.inMilliseconds / 90000) * 2 * math.pi;
    canvas.save();
    canvas.translate(_c, _c);
    canvas.rotate(orbitAngle);
    canvas.translate(-_c, -_c);
    canvas.drawPath(
      _dashedCircle(277, 3, 9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = _champagneGradient.createShader(rect),
    );
    canvas.restore();

    // 主表圈
    canvas.drawCircle(
        const Offset(_c, _c), 266, Paint()..color = const Color(0xFFFAF9F5));
    canvas.drawCircle(
      const Offset(_c, _c),
      266,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _ink,
    );
    canvas.drawCircle(
      const Offset(_c, _c),
      252,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = _gold.withValues(alpha: 0.6),
    );

    // 72 根钟表刻度
    for (var i = 0; i < 72; i++) {
      final angle = i * 5.0;
      final isMajor = i % 9 == 0;
      final p1 = _polar(isMajor ? 254 : 257, angle);
      final p2 = _polar(263, angle);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = isMajor ? 1.4 : 0.75
          ..color = isMajor ? _ink : const Color(0xFFA1A1AA),
      );
    }

    // W/E/S 方位点缀
    final accentPaint = Paint()
      ..strokeWidth = 1
      ..color = _gold.withValues(alpha: 0.65);
    canvas.drawLine(const Offset(10, 300), const Offset(22, 300), accentPaint);
    canvas.drawLine(
        const Offset(578, 300), const Offset(590, 300), accentPaint);
    canvas.drawLine(
        const Offset(300, 578), const Offset(300, 590), accentPaint);
  }

  void _drawRotor(Canvas canvas) {
    canvas.save();
    canvas.translate(_c, _c);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-_c, -_c);

    final fullRect = Rect.fromCircle(center: const Offset(_c, _c), radius: 248);

    // 底盘
    canvas.drawCircle(const Offset(_c, _c), 248, Paint()..color = _ink);

    // 8 扇区
    for (var i = 0; i < prizes.length; i++) {
      _drawSector(canvas, i, fullRect);
    }

    // 转盘装饰环
    canvas.drawCircle(
      const Offset(_c, _c),
      248,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = _goldGradient.createShader(fullRect),
    );
    canvas.drawPath(
      _dashedCircle(142, 2, 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _gold.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      const Offset(_c, _c),
      76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader =
            _goldGradient.createShader(Rect.fromCircle(center: const Offset(_c, _c), radius: 76)),
    );

    // 8 个边界销钉
    for (var i = 0; i < prizes.length; i++) {
      final startAngle = i * 45.0 - 22.5;
      final pos = _polar(244, startAngle);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..shader = _goldGradient
              .createShader(Rect.fromCircle(center: Offset.zero, radius: 4)),
      );
      canvas.drawCircle(Offset.zero, 1.4, Paint()..color = _cream);
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawSector(Canvas canvas, int i, Rect fullRect) {
    final prize = prizes[i];
    const sectorAngle = 45.0;
    final startAngle = i * sectorAngle - sectorAngle / 2;
    final midAngle = i * sectorAngle;

    final startRad = (startAngle - 90) * math.pi / 180;
    final sweepRad = sectorAngle * math.pi / 180;

    final outerRect =
        Rect.fromCircle(center: const Offset(_c, _c), radius: _outerR);
    final innerRect =
        Rect.fromCircle(center: const Offset(_c, _c), radius: _innerR);

    final path = Path()
      ..moveTo(_polar(_outerR, startAngle).dx, _polar(_outerR, startAngle).dy)
      ..arcTo(outerRect, startRad, sweepRad, false)
      ..lineTo(_polar(_innerR, startAngle + sectorAngle).dx,
          _polar(_innerR, startAngle + sectorAngle).dy)
      ..arcTo(innerRect, startRad + sweepRad, -sweepRad, false)
      ..close();

    Color textFill;
    Color subTextFill;
    Color iconColor;
    Shader shader;
    switch (prize.theme) {
      case _SectorTheme.gold:
        shader = _goldGradient.createShader(outerRect);
        textFill = _ink;
        subTextFill = const Color(0xFF27272A);
        iconColor = _ink;
      case _SectorTheme.obsidian:
        shader = _obsidianGradient.createShader(outerRect);
        textFill = const Color(0xFFFAF9F5);
        subTextFill = const Color(0xFFA1A1AA);
        iconColor = _goldLight;
      case _SectorTheme.ivory:
        shader = _ivoryGradient.createShader(outerRect);
        textFill = _ink;
        subTextFill = const Color(0xFF71717A);
        iconColor = _gold;
    }

    canvas.drawPath(path, Paint()..shader = shader);

    // 中奖高亮（呼吸闪烁）
    if (highlightIndex == i && !isSpinning) {
      final phase =
          (elapsed.inMilliseconds % 1600) / 1600; // 0..1
      final opacity = 0.22 * math.sin(phase * math.pi);
      canvas.drawPath(
          path, Paint()..color = Colors.white.withValues(alpha: opacity));
    }

    // 分隔发丝线
    final divIn = _polar(_innerR, startAngle);
    final divOut = _polar(_outerR, startAngle);
    canvas.drawLine(
      divIn,
      divOut,
      Paint()
        ..strokeWidth = 0.9
        ..color = _gold.withValues(alpha: 0.7),
    );

    // 扇区内容（旋转到扇区中线方向）
    canvas.save();
    canvas.translate(_c, _c);
    canvas.rotate(midAngle * math.pi / 180);
    canvas.translate(-_c, -_c);

    _drawText(
      canvas,
      prize.subtitle,
      const Offset(_c, 86),
      fontSize: 7.5,
      color: subTextFill,
      letterSpacing: 1.95,
      weight: FontWeight.w500,
    );
    _drawText(
      canvas,
      prize.title,
      const Offset(_c, 106),
      fontSize: 13.5,
      color: textFill,
      letterSpacing: 1.6,
      weight: FontWeight.w600,
    );

    // 极简矢量图标
    canvas.save();
    canvas.translate(_c, 136);
    canvas.scale(15 / 16); // HTML 图标 viewBox ±16 附近，缩放到合适大小
    _drawPrizeIcon(canvas, prize.id, iconColor);
    canvas.restore();

    // 内环小圆点
    canvas.drawCircle(
      const Offset(_c, 168),
      1.5,
      Paint()..color = iconColor.withValues(alpha: 0.6),
    );

    canvas.restore();
  }

  void _drawHub(Canvas canvas) {
    // 待机呼吸光环
    if (!isSpinning) {
      final phase = (elapsed.inMilliseconds % 3500) / 3500;
      final wave = math.sin(phase * math.pi);
      final r = 64 * (1 + 0.07 * wave);
      final opacity = 0.45 - 0.3 * wave;
      canvas.drawCircle(
        const Offset(_c, _c),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _gold.withValues(alpha: opacity),
      );
    }

    final hubRect = Rect.fromCircle(center: const Offset(_c, _c), radius: 54);

    // 金色外圈（带柔和投影）
    canvas.drawCircle(
      const Offset(_c, _c + 2),
      54,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(const Offset(_c, _c), 54,
        Paint()..shader = _goldGradient.createShader(hubRect));
    canvas.drawCircle(
      const Offset(_c, _c),
      49,
      Paint()
        ..shader = _obsidianGradient
            .createShader(Rect.fromCircle(center: const Offset(_c, _c), radius: 49)),
    );
    canvas.drawCircle(
      const Offset(_c, _c),
      43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = _gold.withValues(alpha: 0.5),
    );

    // 罗盘星芒
    final starPaint = Paint()..color = _gold.withValues(alpha: 0.12);
    canvas.drawPath(
      Path()
        ..moveTo(300, 264)
        ..lineTo(302, 298)
        ..lineTo(300, 336)
        ..lineTo(298, 298)
        ..close(),
      starPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(264, 300)
        ..lineTo(298, 302)
        ..lineTo(336, 300)
        ..lineTo(298, 298)
        ..close(),
      starPaint,
    );

    final spinning = isSpinning;
    final empty = chances <= 0;
    _drawText(
      canvas,
      spinning ? '运 转 中' : (empty ? '已 尽' : '寻 觅'),
      const Offset(_c, 298),
      fontSize: 15,
      color: _cream.withValues(alpha: empty ? 0.75 : 1),
      letterSpacing: 4.2,
    );
    _drawText(
      canvas,
      spinning ? 'IN MOTION' : (empty ? 'COMPLETE' : 'SPIN'),
      const Offset(_c, 316),
      fontSize: 8,
      color: _gold,
      letterSpacing: 2.4,
      weight: FontWeight.w300,
    );
  }

  void _drawPointer(Canvas canvas) {
    // 顶部固定吊架
    final pivot = const Offset(_c, 28);
    canvas.drawCircle(
      const Offset(_c, 30),
      11,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(pivot, 11, Paint()..color = _ink);
    canvas.drawCircle(
      pivot,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = _goldGradient
            .createShader(Rect.fromCircle(center: pivot, radius: 11)),
    );

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(pointerAngle * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);

    // 擒纵卡钳指针
    canvas.drawPath(
      Path()
        ..moveTo(293, 28)
        ..lineTo(307, 28)
        ..lineTo(302.5, 64)
        ..lineTo(300, 78)
        ..lineTo(297.5, 64)
        ..close(),
      Paint()
        ..shader = _goldGradient.createShader(
            Rect.fromPoints(const Offset(293, 28), const Offset(307, 78))),
    );
    canvas.drawPath(
      Path()
        ..moveTo(296.5, 32)
        ..lineTo(303.5, 32)
        ..lineTo(300, 68)
        ..close(),
      Paint()..color = _ink.withValues(alpha: 0.85),
    );
    canvas.drawCircle(pivot, 4, Paint()..color = _cream);
    canvas.drawCircle(pivot, 1.8, Paint()..color = _gold);

    canvas.restore();
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      if (p.alpha <= 0) continue;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      canvas.drawPath(
        Path()
          ..moveTo(0, -p.size)
          ..lineTo(p.size * 0.6, 0)
          ..lineTo(0, p.size)
          ..lineTo(-p.size * 0.6, 0)
          ..close(),
        Paint()..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          letterSpacing: letterSpacing,
          fontWeight: weight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => true;
}

// ------------------------------------------------------------------ 扇区图标

void _drawPrizeIcon(Canvas canvas, String id, Color color) {
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  switch (id) {
    case 'grand':
      canvas.drawPath(
        Path()
          ..moveTo(0, -11)
          ..lineTo(9, 0)
          ..lineTo(0, 11)
          ..lineTo(-9, 0)
          ..close(),
        stroke,
      );
      canvas.drawCircle(Offset.zero, 4, stroke);
      canvas.drawLine(const Offset(0, -15), const Offset(0, -11), stroke);
      canvas.drawLine(const Offset(0, 11), const Offset(0, 15), stroke);
    case 'points_100':
      canvas.drawPath(
        Path()
          ..moveTo(0, -10)
          ..cubicTo(2, -3, 3, -2, 10, 0)
          ..cubicTo(3, 2, 2, 3, 0, 10)
          ..cubicTo(-2, 3, -3, 2, -10, 0)
          ..cubicTo(-3, -2, -2, -3, 0, -10)
          ..close(),
        stroke,
      );
    case 'fragrance':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-6, -4, 12, 13), const Radius.circular(1.5)),
        stroke,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-3, -4)
          ..lineTo(-3, -8)
          ..lineTo(3, -8)
          ..lineTo(3, -4),
        stroke,
      );
      canvas.drawLine(const Offset(-5, -8), const Offset(5, -8), stroke);
      canvas.drawCircle(const Offset(0, 2.5), 2, stroke);
    case 'thanks':
      canvas.drawPath(
        Path()
          ..moveTo(3, -9)
          ..arcToPoint(const Offset(9, 5),
              radius: const Radius.circular(9), largeArc: true, clockwise: false)
          ..arcToPoint(const Offset(3, -9),
              radius: const Radius.circular(7), largeArc: true, clockwise: true)
          ..close(),
        stroke,
      );
    case 'vinyl':
      canvas.drawCircle(Offset.zero, 10, stroke);
      final dashed = Path();
      final circle = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: 6));
      for (final m in circle.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          final end = math.min(d + 3, m.length);
          dashed.addPath(m.extractPath(d, end), Offset.zero);
          d = end + 2;
        }
      }
      canvas.drawPath(dashed, stroke);
      canvas.drawCircle(
          Offset.zero, 2.2, Paint()..color = color);
    case 'voucher':
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, -6, 20, 12), const Radius.circular(1.5)),
        stroke,
      );
      canvas.drawLine(const Offset(-4, -6), const Offset(-4, -4), stroke);
      canvas.drawLine(const Offset(-4, -2), const Offset(-4, 0), stroke);
      canvas.drawLine(const Offset(-4, 2), const Offset(-4, 4), stroke);
      canvas.drawCircle(const Offset(3, 0), 2, stroke);
    case 'membership':
      canvas.drawPath(
        Path()
          ..moveTo(-10, 6)
          ..lineTo(-8, -5)
          ..lineTo(-3, 1)
          ..lineTo(0, -7)
          ..lineTo(3, 1)
          ..lineTo(8, -5)
          ..lineTo(10, 6)
          ..close(),
        stroke,
      );
      canvas.drawLine(const Offset(-10, 9), const Offset(10, 9), stroke);
    case 'points_500':
      canvas.drawCircle(Offset.zero, 9, stroke);
      canvas.drawPath(
        Path()
          ..moveTo(0, -6)
          ..lineTo(4, 0)
          ..lineTo(0, 6)
          ..lineTo(-4, 0)
          ..close(),
        stroke,
      );
  }
}

class _PrizeIconPainter extends CustomPainter {
  _PrizeIconPainter(this.id, this.color);

  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.shortestSide / 34);
    _drawPrizeIcon(canvas, id, color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PrizeIconPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.color != color;
}
