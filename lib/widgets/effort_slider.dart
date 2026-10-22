import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Effort 推理强度滑块 - 复刻 effort_slider_ui.html
///
/// 深色卡片 + 脑图标滑块，共 6 档（Low/Medium/High/Extra/Max/Galaxy）。
/// 拖到 Galaxy 档触发白色闪光、星尘像素矩阵、放射状星芒与冲击波特效。
class EffortSlider extends StatefulWidget {
  /// 初始档位（0-5，默认 1 = Medium）
  final int initialIndex;

  /// 档位变化回调
  final ValueChanged<int>? onChanged;

  const EffortSlider({
    super.key,
    this.initialIndex = 1,
    this.onChanged,
  });

  @override
  State<EffortSlider> createState() => _EffortSliderState();
}

class _LevelDef {
  final String name;
  final bool isGalaxy;
  const _LevelDef(this.name, {this.isGalaxy = false});
}

const List<_LevelDef> _kLevels = [
  _LevelDef('Low'),
  _LevelDef('Medium'),
  _LevelDef('High'),
  _LevelDef('Extra'),
  _LevelDef('Max'),
  _LevelDef('Galaxy', isGalaxy: true),
];

class _MatrixCell {
  final double x;
  final double y;
  final Color color;
  final bool active;
  final double baseAlpha;
  final double twinkleSpeed;
  final double twinklePhase;

  const _MatrixCell({
    required this.x,
    required this.y,
    required this.color,
    required this.active,
    required this.baseAlpha,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });
}

class _StarburstRay {
  final double angle;
  final int dotsInRay;
  final double speed;
  final double phase;

  const _StarburstRay({
    required this.angle,
    required this.dotsInRay,
    required this.speed,
    required this.phase,
  });
}

class _BurstParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double decay;

  _BurstParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.decay,
  });
}

class _ShockwaveRing {
  double radius;
  double maxRadius;
  double alpha;

  _ShockwaveRing({
    required this.radius,
    required this.maxRadius,
    required this.alpha,
  });
}

class _LevelWordAnim {
  final int index;
  final AnimationController controller;
  late final Animation<double> curved;
  bool exiting = false;

  _LevelWordAnim({required this.index, required this.controller}) {
    curved = CurvedAnimation(
      parent: controller,
      curve: _kLevels[index].isGalaxy
          ? const Cubic(0.34, 1.56, 0.64, 1)
          : const Cubic(0.22, 1.0, 0.36, 1),
      reverseCurve: const Cubic(0.22, 1.0, 0.36, 1),
    );
  }
}

class _EffortSliderState extends State<EffortSlider>
    with TickerProviderStateMixin {
  static const double _paddingX = 18;
  static const double _trackHeight = 30;

  late final Ticker _ticker;
  double _timeSec = 0;

  late double _currentProgress;
  late double _targetProgress;
  bool _isDragging = false;
  late int _displayedLevelIndex;
  late int _currentIndex;

  // Galaxy 过渡 & 闪光状态
  double _galaxyBlend = 0;
  double _flashIntensity = 0;
  bool _wasInGalaxy = false;
  bool _bump = false;
  Timer? _galaxyDelayTimer;
  Timer? _cardBumpTimer;

  // 脑图标弹簧缩放
  double _thumbScale = 1;
  double _thumbScaleVel = 0;

  final List<_ShockwaveRing> _shockwaveRings = [];
  final List<_BurstParticle> _burstParticles = [];
  final List<_StarburstRay> _starburstRays = [];
  List<_MatrixCell> _matrixCells = [];
  double _matrixBuiltForWidth = -1;

  final List<_LevelWordAnim> _levelWords = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex.clamp(0, 5);
    _currentIndex = initial;
    _displayedLevelIndex = initial;
    _currentProgress = initial / 5;
    _targetProgress = initial / 5;

    const numRays = 22;
    for (int i = 0; i < numRays; i++) {
      final angle = -math.pi * 0.68 + (i / (numRays - 1)) * (math.pi * 1.36);
      final maxDist = 22 + (i % 3) * 9 + math.sin(i * 1.7) * 6;
      _starburstRays.add(_StarburstRay(
        angle: angle,
        dotsInRay: (maxDist / 3.2).floor(),
        speed: 0.6 + (i % 4) * 0.2,
        phase: (i * 0.43) % 1,
      ));
    }

    final initialController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _kLevels[initial].isGalaxy ? 480 : 280),
    )..value = 1.0;
    _levelWords.add(
      _LevelWordAnim(index: initial, controller: initialController),
    );

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _galaxyDelayTimer?.cancel();
    _cardBumpTimer?.cancel();
    for (final word in _levelWords) {
      word.controller.dispose();
    }
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _timeSec = elapsed.inMicroseconds / 1e6;

      // 平滑插值滑块位置
      final lerpFactor = _isDragging ? 0.28 : 0.16;
      _currentProgress += (_targetProgress - _currentProgress) * lerpFactor;
      if ((_targetProgress - _currentProgress).abs() < 0.0005) {
        _currentProgress = _targetProgress;
      }

      // 接近 Galaxy 档时渐入宇宙视觉
      final targetGalaxyBlend = _currentProgress > 0.82
          ? math.min(1.0, (_currentProgress - 0.82) / 0.16)
          : 0.0;
      _galaxyBlend += (targetGalaxyBlend - _galaxyBlend) * 0.14;

      // 白色闪光衰减
      if (_flashIntensity > 0.005) {
        _flashIntensity *= 0.91;
      } else {
        _flashIntensity = 0;
      }

      // 脑图标弹簧缩放
      final targetScale =
          1 + _galaxyBlend * 0.26 + _flashIntensity * 0.18;
      const springStiffness = 0.18;
      const springDamping = 0.76;
      _thumbScaleVel = (_thumbScaleVel +
              (targetScale - _thumbScale) * springStiffness) *
          springDamping;
      _thumbScale += _thumbScaleVel;

      // 爆发粒子
      for (int i = _burstParticles.length - 1; i >= 0; i--) {
        final p = _burstParticles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.alpha -= p.decay;
        if (p.alpha <= 0) _burstParticles.removeAt(i);
      }

      // 冲击波圆环
      for (int i = _shockwaveRings.length - 1; i >= 0; i--) {
        final ring = _shockwaveRings[i];
        ring.radius += (ring.maxRadius - ring.radius) * 0.14;
        ring.alpha *= 0.88;
        if (ring.alpha <= 0.02) _shockwaveRings.removeAt(i);
      }
    });
  }

  double _progressFromLocalX(double localX, double width) {
    final usableWidth = width - _paddingX * 2;
    final relX = localX - _paddingX;
    return (relX / usableWidth).clamp(0.0, 1.0);
  }

  void _handlePointer(double localX, double width) {
    final prog = _progressFromLocalX(localX, width);
    setState(() {
      _targetProgress = prog;
      _updateLevelFromProgress(prog);
    });
  }

  void _snapToNearest() {
    setState(() {
      _isDragging = false;
      final snappedIndex = (_targetProgress * 5).round();
      _targetProgress = snappedIndex / 5;
      _updateLevelFromProgress(_targetProgress);
    });
  }

  void _jumpTo(int index) {
    setState(() {
      _targetProgress = index / 5;
      _updateLevelFromProgress(_targetProgress);
    });
  }

  void _updateLevelFromProgress(double prog) {
    final clampedIndex = (prog * 5).round().clamp(0, 5);

    if (clampedIndex == 5 && !_wasInGalaxy) {
      _wasInGalaxy = true;
      _triggerGalaxyBurst();

      // 闪光瞬间先短暂显示 "Max"，再 morph 为 "Galaxy"
      if (_displayedLevelIndex < 4) {
        _morphHeaderText(4);
      }
      _galaxyDelayTimer?.cancel();
      _galaxyDelayTimer = Timer(const Duration(milliseconds: 160), () {
        if (mounted && (_targetProgress * 5).round() == 5) {
          setState(() => _morphHeaderText(5));
        }
      });
    } else if (clampedIndex < 5) {
      _wasInGalaxy = false;
      _galaxyDelayTimer?.cancel();
      _morphHeaderText(clampedIndex);
    }

    if (clampedIndex != _currentIndex) {
      _currentIndex = clampedIndex;
      widget.onChanged?.call(clampedIndex);
    }
  }

  void _triggerGalaxyBurst() {
    _flashIntensity = 1.0;
    _thumbScaleVel = 0.085;

    _bump = true;
    _cardBumpTimer?.cancel();
    _cardBumpTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _bump = false);
    });

    _shockwaveRings
        .add(_ShockwaveRing(radius: 10, maxRadius: 46, alpha: 0.9));

    _burstParticles.clear();
    final rand = math.Random();
    for (int i = 0; i < 28; i++) {
      final angle = rand.nextDouble() * math.pi * 2;
      final speed = 0.4 + rand.nextDouble() * 1.8;
      _burstParticles.add(_BurstParticle(
        x: 0,
        y: 0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 1.2 + rand.nextDouble() * 1.8,
        alpha: 0.9 + rand.nextDouble() * 0.1,
        decay: 0.018 + rand.nextDouble() * 0.022,
      ));
    }
  }

  void _morphHeaderText(int newIndex) {
    if (newIndex == _displayedLevelIndex) return;
    _displayedLevelIndex = newIndex;

    for (final word in List.of(_levelWords)) {
      if (!word.exiting) {
        word.exiting = true;
        word.controller.reverse().whenComplete(() {
          if (!mounted) return;
          setState(() {
            _levelWords.remove(word);
            word.controller.dispose();
          });
        });
      }
    }

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _kLevels[newIndex].isGalaxy ? 480 : 280),
    );
    _levelWords.add(_LevelWordAnim(index: newIndex, controller: controller));
    controller.forward();
  }

  void _buildMatrix(double width) {
    if ((width - _matrixBuiltForWidth).abs() < 0.5) return;
    _matrixBuiltForWidth = width;

    const cellStep = 5.0;
    const matrixRows = 6;
    final cols = (width / cellStep).ceil();

    const palette = [
      [94, 234, 212], // 青光
      [96, 165, 250], // 电蓝
      [129, 140, 248], // 靛蓝
      [167, 139, 250], // 紫罗兰
      [232, 121, 249], // 品红紫
      [244, 114, 182], // 玫瑰粉
      [224, 242, 254], // 冰白蓝
    ];

    final rand = math.Random();
    _matrixCells = [];
    for (int c = 0; c < cols; c++) {
      final colNorm = c / math.max(1, cols - 1);
      for (int r = 0; r < matrixRows; r++) {
        final color = palette[rand.nextInt(palette.length)];
        final densityThreshold = 0.18 + math.pow(colNorm, 1.15) * 0.78;
        _matrixCells.add(_MatrixCell(
          x: c * cellStep + 1,
          y: r * cellStep + 0.8,
          color: Color.fromARGB(255, color[0], color[1], color[2]),
          active: rand.nextDouble() < densityThreshold,
          baseAlpha: (0.15 + math.pow(colNorm, 1.35) * 0.85) *
              (0.4 + rand.nextDouble() * 0.6),
          twinkleSpeed: 1.4 + rand.nextDouble() * 3.8,
          twinklePhase: rand.nextDouble() * math.pi * 2,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.min(368.0, screenWidth * 0.92);

    return AnimatedScale(
      scale: _bump ? 1.06 : (_wasInGalaxy ? 1.035 : 1.0),
      duration: const Duration(milliseconds: 450),
      curve: const Cubic(0.34, 1.56, 0.64, 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        width: cardWidth,
        padding: const EdgeInsets.fromLTRB(26, 23, 26, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _wasInGalaxy
                ? const Color(0xFF9B82FF).withOpacity(0.28)
                : Colors.white.withOpacity(0.09),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_wasInGalaxy ? 0.78 : 0.65),
              blurRadius: _wasInGalaxy ? 75 : 60,
              offset: Offset(0, _wasInGalaxy ? 28 : 24),
            ),
            if (_wasInGalaxy)
              BoxShadow(
                color: const Color(0xFF7D5FFF).withOpacity(0.16),
                blurRadius: 38,
              ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            _buildMatrix(width);
            final usableWidth = width - _paddingX * 2;
            final thumbX = _paddingX + _currentProgress * usableWidth;
            final dot1X = _paddingX + usableWidth / 5;
            final trackScaleT = (_galaxyBlend / 0.15).clamp(0.0, 1.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildPolarLabels(),
                const SizedBox(height: 12),
                _buildSliderArea(width, thumbX, trackScaleT),
                const SizedBox(height: 10),
                _buildFooter(dot1X),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Effort',
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7C7C82),
                  letterSpacing: -0.28,
                  height: 1,
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 110,
                height: 24,
                child: Stack(
                  children: [
                    for (final word in _levelWords)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: _buildLevelWord(word),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Tooltip(
            message:
                'Adjust how much reasoning effort the model spends before responding.',
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF28282C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            textStyle: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFC8C8D0),
              height: 1.4,
            ),
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF727278),
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                '?',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF727278),
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelWord(_LevelWordAnim word) {
    final level = _kLevels[word.index];
    return AnimatedBuilder(
      animation: word.curved,
      builder: (context, child) {
        final t = word.curved.value;
        final double opacity;
        final double blur;
        final double scale;
        final double ty;
        if (level.isGalaxy) {
          // galaxyWordZoom 关键帧：0.85 -> 1.16(55%) -> 1.07
          opacity = t < 0.55 ? (t / 0.55) : 1.0;
          blur = t < 0.55 ? 5 * (1 - t / 0.55) : 0.0;
          scale = t < 0.55
              ? 0.85 + (1.16 - 0.85) * (t / 0.55)
              : 1.16 + (1.07 - 1.16) * ((t - 0.55) / 0.45);
          ty = 2 * (1 - t);
        } else {
          opacity = t;
          blur = 5 * (1 - t);
          scale = 0.96 + 0.04 * t;
          ty = 1 * (1 - t);
        }

        Widget text;
        if (level.isGalaxy) {
          text = ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Color(0xFF6E8EFB), Color(0xFF8B78FF), Color(0xFFA57BFF)],
              stops: [0, 0.55, 1],
            ).createShader(rect),
            child: Text(
              level.name,
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.28,
                height: 24 / 18.5,
                shadows: [
                  Shadow(
                    color: const Color(0xFF7882FF).withOpacity(0.25),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          );
        } else {
          text = Text(
            level.name,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF98989F),
              letterSpacing: -0.28,
              height: 24 / 18.5,
            ),
          );
        }

        Widget result = Transform.translate(
          offset: Offset(0, ty),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerLeft,
            child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: text),
          ),
        );
        if (blur > 0.01) {
          result = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: result,
          );
        }
        return result;
      },
    );
  }

  Widget _buildPolarLabels() {
    const style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF75757A),
      letterSpacing: -0.14,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _jumpTo(math.max(0, _currentIndex - 1)),
          child: const Text('Faster', style: style),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _jumpTo(math.min(5, _currentIndex + 1)),
          child: const Text('Smarter', style: style),
        ),
      ],
    );
  }

  Widget _buildSliderArea(double width, double thumbX, double trackScaleT) {
    return SizedBox(
      height: _trackHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) {
          _isDragging = true;
          _handlePointer(d.localPosition.dx, width);
        },
        onPanUpdate: (d) => _handlePointer(d.localPosition.dx, width),
        onPanEnd: (_) => _snapToNearest(),
        onPanCancel: _snapToNearest,
        onTapDown: (d) {
          _isDragging = true;
          _handlePointer(d.localPosition.dx, width);
        },
        onTapUp: (_) => _snapToNearest(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 轨道（含粉色填充、星尘像素矩阵、刻度点）
            Positioned.fill(
              child: Transform.scale(
                scaleY: 1 + 0.08 * trackScaleT,
                child: CustomPaint(
                  painter: _EffortTrackPainter(
                    progress: _currentProgress,
                    thumbX: thumbX,
                    galaxyBlend: _galaxyBlend,
                    flashIntensity: _flashIntensity,
                    timeSec: _timeSec,
                    matrixCells: _matrixCells,
                    paddingX: _paddingX,
                  ),
                ),
              ),
            ),
            // 外部特效层（星芒、闪光粒子、冲击波）
            Positioned(
              left: -40,
              top: -45,
              width: width + 80,
              height: 120,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _EffortFxPainter(
                    centerX: thumbX + 40,
                    centerY: 15 + 45,
                    galaxyBlend: _galaxyBlend,
                    flashIntensity: _flashIntensity,
                    timeSec: _timeSec,
                    rays: _starburstRays,
                    burstParticles: _burstParticles,
                    shockwaveRings: _shockwaveRings,
                  ),
                ),
              ),
            ),
            // 脑图标滑块头
            Positioned(
              left: thumbX - 17,
              top: (_trackHeight - 34) / 2,
              child: IgnorePointer(child: _buildBrainThumb()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainThumb() {
    final flashOp = ((_flashIntensity - 0.35) / 0.3).clamp(0.0, 1.0);
    final galaxyOp = ((_galaxyBlend - 0.5) / 0.2).clamp(0.0, 1.0);
    final pinkOp = (1.0 - flashOp - galaxyOp).clamp(0.0, 1.0);

    Widget glow(double size, List<Color> colors, List<double> stops,
        double opacity) {
      return Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors, stops: stops),
          ),
        ),
      );
    }

    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Transform.scale(
            scale: _thumbScale,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                glow(
                  38,
                  [
                    const Color(0xFFFF4DA6).withOpacity(0.55),
                    const Color(0xFFFF4DA6).withOpacity(0),
                  ],
                  const [0, 0.72],
                  pinkOp,
                ),
                glow(
                  46,
                  [
                    const Color(0xFF8A6CFF).withOpacity(0.65),
                    const Color(0xFF6246F5).withOpacity(0.22),
                    const Color(0xFF6246F5).withOpacity(0),
                  ],
                  const [0, 0.48, 0.75],
                  galaxyOp * (1 - flashOp),
                ),
                glow(
                  58,
                  [
                    Colors.white.withOpacity(0.95),
                    const Color(0xFFC3A5FF).withOpacity(0.75),
                    const Color(0xFF8C64FF).withOpacity(0),
                  ],
                  const [0, 0.42, 0.76],
                  flashOp,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: _thumbScale,
            child: SizedBox(
              width: 28,
              height: 26,
              child: Stack(
                children: [
                  Opacity(
                    opacity: pinkOp,
                    child: SvgPicture.string(
                      _brainSvg(_kPinkBrainGrad),
                      width: 28,
                      height: 26,
                    ),
                  ),
                  Opacity(
                    opacity: galaxyOp * (1 - flashOp),
                    child: SvgPicture.string(
                      _brainSvg(_kGalaxyBrainGrad),
                      width: 28,
                      height: 26,
                    ),
                  ),
                  Opacity(
                    opacity: flashOp,
                    child: SvgPicture.string(
                      _brainSvg(_kFlashBrainGrad),
                      width: 28,
                      height: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double dot1X) {
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Positioned(
            left: dot1X,
            top: 0,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _jumpTo(1),
                child: const Text(
                  'Recommended',
                  style: TextStyle(
                    fontSize: 13.8,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF75757A),
                    letterSpacing: -0.14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨道绘制：背景、粉色渐变填充、星尘像素矩阵、6 个刻度点
class _EffortTrackPainter extends CustomPainter {
  final double progress;
  final double thumbX;
  final double galaxyBlend;
  final double flashIntensity;
  final double timeSec;
  final List<_MatrixCell> matrixCells;
  final double paddingX;

  _EffortTrackPainter({
    required this.progress,
    required this.thumbX,
    required this.galaxyBlend,
    required this.flashIntensity,
    required this.timeSec,
    required this.matrixCells,
    required this.paddingX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );

    // Galaxy 外发光
    if (galaxyBlend > 0.02) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF8A6CFF).withOpacity(0.25 * galaxyBlend)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.save();
    canvas.clipRRect(rrect);

    // 背景
    final bg = Color.lerp(
      const Color(0xFF323135),
      const Color(0xFF191820),
      galaxyBlend,
    )!;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    // 粉色渐变填充
    final fillOpacity = math.max(0.0, 1 - galaxyBlend * 0.92);
    if (fillOpacity > 0.01 && thumbX > 0) {
      final fillRect = Rect.fromLTWH(0, 0, thumbX, size.height);
      canvas.saveLayer(fillRect, Paint()..color = Colors.white.withOpacity(fillOpacity));
      canvas.drawRect(
        fillRect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF583454).withOpacity(0.28),
              const Color(0xFFA2448A).withOpacity(0.68),
              const Color(0xFFEE54A6).withOpacity(0.95),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(fillRect),
      );
      // 右缘内侧高光
      canvas.drawRect(
        Rect.fromLTWH(thumbX - 3, 0, 3, size.height),
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFF6EBE).withOpacity(0),
              const Color(0xFFFF6EBE).withOpacity(0.35),
            ],
          ).createShader(Rect.fromLTWH(thumbX - 3, 0, 3, size.height)),
      );
      canvas.restore();
    }

    // 星尘像素矩阵
    if (galaxyBlend > 0.01) {
      for (final cell in matrixCells) {
        if (!cell.active) continue;
        if (cell.x > thumbX + 6) continue;

        final distToThumb = math.max(0.0, thumbX - cell.x);
        final proximityBoost = math.max(0.0, 1 - distToThumb / 55);

        final twinkle =
            0.5 + 0.5 * math.sin(timeSec * cell.twinkleSpeed + cell.twinklePhase);
        double alpha =
            cell.baseAlpha * (0.35 + 0.65 * twinkle) * galaxyBlend;
        alpha = math.min(1.0, alpha + proximityBoost * 0.45 * galaxyBlend);
        if (alpha < 0.04) continue;

        final whiteMix =
            math.min(1.0, proximityBoost * 0.45 + flashIntensity * 0.5);
        final color = Color.lerp(cell.color, Colors.white, whiteMix)!;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cell.x, cell.y, 3.5, 3.5),
            const Radius.circular(0.8),
          ),
          Paint()..color = color.withOpacity(alpha),
        );
      }
    }

    // 6 个刻度点
    for (int i = 0; i < 6; i++) {
      final dotProg = i / 5;
      final dist = (progress - dotProg).abs();

      final double opacity;
      if (dist < 0.055) {
        opacity = 0;
      } else if (galaxyBlend > 0.5) {
        opacity = 0.55;
      } else if (dotProg < progress) {
        opacity = 0.85;
      } else {
        opacity = 0.45;
      }
      if (opacity <= 0.01) continue;

      final passed = dotProg < progress - 0.04 && galaxyBlend <= 0.5;
      final galaxyTick = galaxyBlend > 0.5;

      final Color color;
      if (galaxyTick) {
        color = const Color(0xFFD7C8FF).withOpacity(0.82 * opacity);
      } else if (passed) {
        color = const Color(0xFFFFE1F5).withOpacity(0.85 * opacity);
      } else {
        color = Colors.white.withOpacity(0.42 * opacity);
      }

      final x = paddingX + dotProg * (size.width - paddingX * 2);
      final h = passed ? 14.0 * 1.12 : 14.0;
      final dotRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 1, (size.height - h) / 2, 2, h),
        const Radius.circular(1),
      );

      if (passed || galaxyTick) {
        canvas.drawRRect(
          dotRect,
          Paint()
            ..color = (passed
                    ? const Color(0xFFFF78C3)
                    : const Color(0xFF9678FF))
                .withOpacity(0.55 * opacity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
      canvas.drawRRect(dotRect, Paint()..color = color);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EffortTrackPainter oldDelegate) => true;
}

/// 外部特效绘制：放射状星芒、闪光粒子、冲击波圆环
class _EffortFxPainter extends CustomPainter {
  final double centerX;
  final double centerY;
  final double galaxyBlend;
  final double flashIntensity;
  final double timeSec;
  final List<_StarburstRay> rays;
  final List<_BurstParticle> burstParticles;
  final List<_ShockwaveRing> shockwaveRings;

  _EffortFxPainter({
    required this.centerX,
    required this.centerY,
    required this.galaxyBlend,
    required this.flashIntensity,
    required this.timeSec,
    required this.rays,
    required this.burstParticles,
    required this.shockwaveRings,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (galaxyBlend <= 0.05 &&
        flashIntensity <= 0.01 &&
        burstParticles.isEmpty &&
        shockwaveRings.isEmpty) {
      return;
    }

    final center = Offset(centerX, centerY);

    // 放射状点状星芒
    if (galaxyBlend > 0.05) {
      for (final ray in rays) {
        final cosA = math.cos(ray.angle);
        final sinA = math.sin(ray.angle);

        for (int d = 0; d < ray.dotsInRay; d++) {
          final animOffset = (timeSec * ray.speed + ray.phase) % 1;
          final stepIndex = d + animOffset;
          final radius = 15.5 + stepIndex * 3.1;
          final fadeOut = math.max(0.0, 1 - stepIndex / ray.dotsInRay);
          final dotAlpha = fadeOut * 0.72 * galaxyBlend;
          if (dotAlpha <= 0.03) continue;

          canvas.drawCircle(
            Offset(center.dx + cosA * radius, center.dy + sinA * radius),
            1.05,
            Paint()
              ..color = (d < 2
                      ? const Color(0xFFD7C3FF)
                      : const Color(0xFF9B7DFF))
                  .withOpacity(dotAlpha),
          );
        }
      }
    }

    // 闪光爆发粒子
    for (final p in burstParticles) {
      canvas.drawCircle(
        center + Offset(p.x, p.y),
        p.size,
        Paint()
          ..color =
              const Color(0xFFEBDCFF).withOpacity(p.alpha.clamp(0.0, 1.0)),
      );
    }

    // 冲击波圆环
    for (final ring in shockwaveRings) {
      canvas.drawCircle(
        center,
        ring.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * ring.alpha
          ..color = const Color(0xFFD2BEFF).withOpacity(ring.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_EffortFxPainter oldDelegate) => true;
}


// 脑图标 SVG（渐变定义可替换，实现粉色/星河/闪光三种形态交叉淡化）
const String _kPinkBrainGrad =
    '<linearGradient id="brainGrad" x1="18" y1="3" x2="18" y2="29" gradientUnits="userSpaceOnUse">'
    '<stop offset="0%" stop-color="#FF85C8"/>'
    '<stop offset="50%" stop-color="#FF54A8"/>'
    '<stop offset="100%" stop-color="#E6398E"/>'
    '</linearGradient>';

const String _kGalaxyBrainGrad =
    '<linearGradient id="brainGrad" x1="6" y1="3" x2="30" y2="29" gradientUnits="userSpaceOnUse">'
    '<stop offset="0%" stop-color="#B99BFF"/>'
    '<stop offset="50%" stop-color="#8C6BFF"/>'
    '<stop offset="100%" stop-color="#6950FF"/>'
    '</linearGradient>';

const String _kFlashBrainGrad =
    '<linearGradient id="brainGrad" x1="18" y1="3" x2="18" y2="29" gradientUnits="userSpaceOnUse">'
    '<stop offset="0%" stop-color="#FFFFFF"/>'
    '<stop offset="60%" stop-color="#DFCFFF"/>'
    '<stop offset="100%" stop-color="#A888FF"/>'
    '</linearGradient>';

String _brainSvg(String gradientDef) => '''
<svg viewBox="0 0 36 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>$gradientDef</defs>
  <path d="M17.2 4.2C14.2 3.6 10.6 5.2 9.4 8.3C6.8 9.2 5.2 11.9 5.5 14.9C5.7 16.5 6.4 17.9 7.5 18.9C6.9 21.6 8.3 24.6 11.1 25.9C13.5 27.1 16.8 26.5 18 24.9C19.2 26.5 22.5 27.1 24.9 25.9C27.7 24.6 29.1 21.6 28.5 18.9C29.6 17.9 30.3 16.5 30.5 14.9C30.8 11.9 29.2 9.2 26.6 8.3C25.4 5.2 21.8 3.6 18.8 4.2Z"
        fill="#1D1524" stroke="#1D1524" stroke-width="4.2" stroke-linejoin="round" />
  <path d="M16.7 6.8C16.7 5.7 15.8 4.8 14.6 4.8C12.7 4.8 11.1 6.1 10.8 7.9C10.7 8.4 10.3 8.8 9.8 8.9C7.9 9.4 6.6 11.1 6.6 13.1C6.6 14.4 7.2 15.6 8.1 16.4C8.5 16.7 8.6 17.3 8.4 17.8C7.9 18.7 7.8 19.8 8.1 20.9C8.7 23.0 10.7 24.5 13.0 24.5C13.6 24.5 14.2 24.4 14.7 24.1C15.9 23.7 16.7 22.5 16.7 21.2V6.8Z"
        fill="url(#brainGrad)" />
  <path d="M19.3 6.8C19.3 5.7 20.2 4.8 21.4 4.8C23.3 4.8 24.9 6.1 25.2 7.9C25.3 8.4 25.7 8.8 26.2 8.9C28.1 9.4 29.4 11.1 29.4 13.1C29.4 14.4 28.8 15.6 27.9 16.4C27.5 16.7 27.4 17.3 27.6 17.8C28.1 18.7 28.2 19.8 27.9 20.9C27.3 23.0 25.3 24.5 23.0 24.5C22.4 24.5 21.8 24.4 21.3 24.1C20.1 23.7 19.3 22.5 19.3 21.2V6.8Z"
        fill="url(#brainGrad)" />
  <g stroke="#1D1524" stroke-width="1.65" stroke-linecap="round" fill="none">
    <path d="M10.4 9.2C12.2 9.4 13.4 10.6 13.4 12.2" />
    <path d="M8.3 16.2C10.3 15.8 12.1 16.6 12.9 18.1" />
    <path d="M13.8 14.2C15.0 14.2 15.9 14.2 16.8 14.2" />
    <path d="M11.6 21.2C12.7 20.3 14.1 20.4 15.0 21.3" />
    <path d="M25.6 9.2C23.8 9.4 22.6 10.6 22.6 12.2" />
    <path d="M27.7 16.2C25.7 15.8 23.9 16.6 23.1 18.1" />
    <path d="M22.2 14.2C21.0 14.2 20.1 14.2 19.2 14.2" />
    <path d="M24.4 21.2C23.3 20.3 21.9 20.4 21.0 21.3" />
  </g>
</svg>
''';
