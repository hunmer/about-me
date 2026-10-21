import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Siri 流光语音助手卡片 Demo
///
/// 复刻自 siri_voice_assistant_orb_ui.html：
/// 黑色悬浮卡片 + 中央 Siri 流光录音球（多层流光丝带 + 地平线透镜弧光）
/// 支持三种动画模式：流光倾听 / 高频语音 / 静谧极光（另附模拟麦克风模式）
enum SiriOrbMode { siriListen, speaking, horizon, micSim }

class SiriVoiceAssistantOrbDemo extends StatelessWidget {
  const SiriVoiceAssistantOrbDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: SiriVoiceAssistantCard(),
        ),
      ),
    );
  }
}

class SiriVoiceAssistantCard extends StatefulWidget {
  const SiriVoiceAssistantCard({super.key});

  @override
  State<SiriVoiceAssistantCard> createState() => _SiriVoiceAssistantCardState();
}

class _SiriVoiceAssistantCardState extends State<SiriVoiceAssistantCard>
    with SingleTickerProviderStateMixin {
  static const _defaultPrompt =
      'Sorry, something went wrong. Please try again in a moment.';

  late final Ticker _ticker;
  final _orbState = _OrbRenderState();
  final _keyboardController = TextEditingController();
  final _keyboardFocus = FocusNode();

  SiriOrbMode _mode = SiriOrbMode.siriListen;
  String _promptText = _defaultPrompt;
  bool _expanded = false;
  bool _muted = false;
  bool _keyboardOpen = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _tick())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _keyboardController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _tick() {
    final s = _orbState;
    switch (_mode) {
      case SiriOrbMode.siriListen:
        s.targetEnergy = 0.42 +
            0.22 * math.sin(s.time * 2.1) +
            0.15 * math.cos(s.time * 3.7) +
            0.1 * math.sin(s.time * 6.3);
        s.targetRibbonMix = 0.92;
        break;
      case SiriOrbMode.speaking:
        final active = 0.68 +
            0.28 * math.sin(s.time * 5.2) * math.cos(s.time * 3.1) +
            0.18 * math.sin(s.time * 9.4);
        s.targetEnergy = math.max(0.3, active);
        s.targetRibbonMix = 1.0;
        break;
      case SiriOrbMode.horizon:
        s.targetEnergy = 0.18 + 0.06 * math.sin(s.time * 1.6);
        s.targetRibbonMix = 0.16;
        break;
      case SiriOrbMode.micSim:
        // 模拟麦克风拾音：快慢叠加的伪随机能量
        final n = math.sin(s.time * 7.3) *
                math.sin(s.time * 2.9 + 1.3) *
                math.cos(s.time * 11.7) +
            0.35 * math.sin(s.time * 4.1);
        s.targetEnergy = (0.45 + n.abs() * 0.7).clamp(0.18, 1.15);
        s.targetRibbonMix = 0.95;
        break;
    }
    s.energy += (s.targetEnergy - s.energy) * 0.12;
    s.ribbonMix += (s.targetRibbonMix - s.ribbonMix) * 0.08;
    s.pulseBoost *= 0.91;
    s.time += 0.016 + s.energy * 0.014;
  }

  void _setMode(SiriOrbMode mode, [String? prompt]) {
    setState(() {
      _mode = mode;
      _orbState.pulseBoost = 0.65;
      if (prompt != null) _promptText = prompt;
    });
  }

  void _onOrbTap() {
    _orbState.pulseBoost = 1.0;
    if (_mode == SiriOrbMode.siriListen) {
      _setMode(SiriOrbMode.speaking,
          'I’m listening closely. Go ahead whenever you’re ready.');
    } else {
      _setMode(SiriOrbMode.siriListen, _defaultPrompt);
    }
  }

  void _onClose() {
    setState(() {
      _expanded = false;
      _keyboardOpen = false;
      _promptText = _defaultPrompt;
      _mode = SiriOrbMode.siriListen;
      _orbState.pulseBoost = 0.65;
    });
  }

  void _onKeyboardSubmit(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    _keyboardController.clear();
    _setMode(SiriOrbMode.speaking, v);
    _orbState.pulseBoost = 1.1;
    setState(() => _keyboardOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width - 32;
    final width = math.min(_expanded ? 580.0 : 500.0, maxW);
    final height = _expanded ? 430.0 : 360.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: const Cubic(0.22, 1, 0.36, 1),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF020202),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.42),
                blurRadius: 72,
                offset: const Offset(0, 34),
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 36,
                offset: const Offset(0, 16),
                spreadRadius: -6,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: Stack(
              children: [
                // 提示文案
                Positioned(
                  top: 86,
                  left: 38,
                  right: 42,
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _promptText,
                        key: ValueKey(_promptText),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21.5,
                          fontWeight: FontWeight.w400,
                          height: 1.36,
                          letterSpacing: -0.26,
                        ),
                      ),
                    ),
                  ),
                ),
                // 四角按钮
                Positioned(
                  top: 22,
                  left: 22,
                  child: _CornerButton(
                    onTap: _onClose,
                    tooltip: 'Reset / Close',
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
                Positioned(
                  top: 22,
                  right: 22,
                  child: _CornerButton(
                    onTap: () => setState(() => _expanded = !_expanded),
                    tooltip: 'Expand / Collapse',
                    child: Icon(
                      _expanded ? Icons.close_fullscreen : Icons.open_in_full,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  left: 22,
                  child: _CornerButton(
                    onTap: () => setState(() => _muted = !_muted),
                    tooltip: 'Toggle Audio Feedback',
                    child: Icon(
                      _muted ? Icons.volume_off : Icons.volume_up,
                      color: _muted
                          ? Colors.white.withOpacity(0.65)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 22,
                  right: 22,
                  child: _CornerButton(
                    onTap: () {
                      setState(() => _keyboardOpen = !_keyboardOpen);
                      if (_keyboardOpen) {
                        Future.delayed(const Duration(milliseconds: 120),
                            _keyboardFocus.requestFocus);
                      }
                    },
                    tooltip: 'Type to Assistant',
                    child: const Icon(Icons.keyboard,
                        color: Colors.white, size: 22),
                  ),
                ),
                // 中央录音球
                Positioned(
                  bottom: 21,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _onOrbTap,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: const Size(162, 162),
                          painter: _SiriOrbPainter(_orbState),
                        ),
                      ),
                    ),
                  ),
                ),
                // 键盘输入抽屉
                Positioned(
                  bottom: 22,
                  left: 78,
                  right: 78,
                  child: IgnorePointer(
                    ignoring: !_keyboardOpen,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      opacity: _keyboardOpen ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 280),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        offset:
                            _keyboardOpen ? Offset.zero : const Offset(0, 0.25),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 280),
                          curve: const Cubic(0.22, 1, 0.36, 1),
                          scale: _keyboardOpen ? 1 : 0.96,
                          child: Container(
                            height: 44,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xEB212123),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _keyboardController,
                              focusNode: _keyboardFocus,
                              onSubmitted: _onKeyboardSubmit,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              cursorColor: Colors.white70,
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: 'Ask anything or type a message...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.42),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 46),
        // 底部模式切换控制条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xE0F4F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                label: 'Siri 流光倾听',
                active: _mode == SiriOrbMode.siriListen,
                showDot: true,
                onTap: () => _setMode(SiriOrbMode.siriListen, _defaultPrompt),
              ),
              _DockButton(
                label: '高频语音流光',
                active: _mode == SiriOrbMode.speaking,
                onTap: () => _setMode(SiriOrbMode.speaking,
                    'I’m listening closely. Go ahead whenever you’re ready.'),
              ),
              _DockButton(
                label: '原图静谧极光',
                active: _mode == SiriOrbMode.horizon,
                onTap: () => _setMode(SiriOrbMode.horizon, _defaultPrompt),
              ),
              _DockButton(
                label: '🎙️ 模拟麦克风',
                active: _mode == SiriOrbMode.micSim,
                onTap: () => _setMode(
                    SiriOrbMode.micSim, 'Listening to simulated mic energy...'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool showDot;
  final VoidCallback onTap;

  const _DockButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111827) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF38BDF8),
                  boxShadow: [
                    BoxShadow(color: Color(0xFF38BDF8), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  const _CornerButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_CornerButton> createState() => _CornerButtonState();
}

class _CornerButtonState extends State<_CornerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: const Cubic(0.34, 1.56, 0.64, 1),
          scale: _pressed ? 0.94 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pressed ? const Color(0xFF1A1A1B) : const Color(0xFF212122),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 流光球渲染状态（由外部 Ticker 驱动，Painter 只读）
class _OrbRenderState {
  double time = 0;
  double energy = 0.52;
  double targetEnergy = 0.52;
  double ribbonMix = 1.0;
  double targetRibbonMix = 1.0;
  double pulseBoost = 0;
}

class _RibbonSpec {
  final Color colorTop;
  final Color colorBottom;
  final double freq;
  final double speed;
  final double phase;
  final double ampFactor;
  final double yOffset;
  final int invert;

  const _RibbonSpec({
    required this.colorTop,
    required this.colorBottom,
    required this.freq,
    required this.speed,
    required this.phase,
    required this.ampFactor,
    required this.yOffset,
    required this.invert,
  });
}

const _ribbons = [
  _RibbonSpec(
    colorTop: Color(0xD956DAFF),
    colorBottom: Color(0x0D1E6EFF),
    freq: 1.9,
    speed: 2.3,
    phase: 0.0,
    ampFactor: 16,
    yOffset: -2,
    invert: -1,
  ),
  _RibbonSpec(
    colorTop: Color(0xD9FFA85C),
    colorBottom: Color(0x0DEB5823),
    freq: 1.55,
    speed: -1.85,
    phase: 1.7,
    ampFactor: 15,
    yOffset: 4,
    invert: 1,
  ),
  _RibbonSpec(
    colorTop: Color(0xB8D873FF),
    colorBottom: Color(0x0A7D32F0),
    freq: 2.35,
    speed: 2.7,
    phase: 3.4,
    ampFactor: 18,
    yOffset: 0,
    invert: 1,
  ),
  _RibbonSpec(
    colorTop: Color(0xAD60A5FA),
    colorBottom: Color(0x082563EB),
    freq: 1.3,
    speed: -1.45,
    phase: 4.8,
    ampFactor: 13,
    yOffset: -3,
    invert: -1,
  ),
];

class _SiriOrbPainter extends CustomPainter {
  final _OrbRenderState s;

  /// 画布边长 162，球体半径 67，四周留 14px 给环境辉光
  static const _glowPadding = 14.0;

  _SiriOrbPainter(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2 - _glowPadding;
    final center = Offset(cx, cy);
    final t = s.time;
    final energy = s.energy;
    final mix = s.ribbonMix;
    final pulse = s.pulseBoost;
    final sphereRect = Rect.fromCircle(center: center, radius: r);

    _drawAmbientGlow(canvas, center, r, energy, pulse);

    // 裁剪到球体内绘制流光内容
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));

    // 1. 深邃暗色基底
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.05,
          colors: const [
            Color(0xFF191A1E),
            Color(0xFF0C0D10),
            Color(0xFF040405),
          ],
          stops: const [0, 0.58, 1],
        ).createShader(sphereRect),
    );

    // 2. Siri 旋转流光边缘极光
    _drawEdgeAurora(canvas, center, r, t, energy, mix);

    // 3. 多层流光丝带波浪
    for (final ribbon in _ribbons) {
      _drawRibbon(canvas, center, r, ribbon, t, energy, mix);
    }

    // 4. 中心地平线透镜弧光
    _drawHorizonFlare(canvas, center, r, t, energy, pulse);

    // 5. 边缘暗角收敛
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x00000000),
            Color(0x61040406),
            Color(0xB8020203),
          ],
          stops: [0.64, 0.85, 1.0],
        ).createShader(sphereRect),
    );

    canvas.restore();

    // 球体玻璃描边与表面高光
    _drawGlassOverlay(canvas, center, r, sphereRect);
  }

  void _drawAmbientGlow(
      Canvas canvas, Offset center, double r, double energy, double pulse) {
    final scale = 0.96 + energy * 0.14 + pulse * 0.18;
    final opacity = (0.4 + energy * 0.55).clamp(0.0, 1.0);
    final radius = (r + _glowPadding) * scale;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF78D7FF).withOpacity(0.18 * opacity),
            const Color(0xFFFFA55F).withOpacity(0.12 * opacity),
            const Color(0xFFC084FC).withOpacity(0.08 * opacity),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 0.65, 0.78],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawEdgeAurora(Canvas canvas, Offset center, double r, double t,
      double energy, double mix) {
    if (mix <= 0.02) return;
    final alpha = mix * (0.45 + energy * 0.55);
    final spots = [
      (a: t * 1.15, color: const Color(0xFF5CE1FF), o: 0.24),
      (a: -t * 0.9 + 2.1, color: const Color(0xFFFFA25F), o: 0.20),
      (a: t * 0.75 + 4.2, color: const Color(0xFFC678FF), o: 0.20),
    ];
    final orbitR = r * 0.62;
    for (final spot in spots) {
      final gx = center.dx + math.cos(spot.a) * orbitR;
      final gy = center.dy + math.sin(spot.a) * orbitR * 0.65;
      final glowCenter = Offset(gx, gy);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              spot.color.withOpacity(spot.o * alpha),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: glowCenter, radius: r * 0.65)),
      );
    }
  }

  void _drawRibbon(Canvas canvas, Offset center, double r, _RibbonSpec ribbon,
      double t, double energy, double mix) {
    if (mix <= 0.01) return;
    final alpha = (mix * (0.48 + energy * 0.48)).clamp(0.0, 1.0);
    final baseLineY = center.dy + 6 + ribbon.yOffset;
    final spanX = r * 1.04;
    final startX = center.dx - spanX;
    final endX = center.dx + spanX;
    const steps = 48;

    final path = Path()..moveTo(startX, baseLineY);

    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final nx = u * 2 - 1;
      final x = startX + u * (endX - startX);
      final envelope = math.pow(math.max(0.0, 1 - nx * nx), 1.45).toDouble();
      final wave1 =
          math.sin(nx * math.pi * ribbon.freq + t * ribbon.speed + ribbon.phase);
      final wave2 = math.cos(nx * math.pi * ribbon.freq * 1.6 -
          t * ribbon.speed * 0.7 +
          ribbon.phase);
      final combined = wave1 * 0.68 + wave2 * 0.32;
      final amp = (ribbon.ampFactor * (0.35 + energy * 1.15) +
              s.pulseBoost * 14) *
          envelope;
      path.lineTo(x, baseLineY + combined * amp);
    }

    for (var i = steps; i >= 0; i--) {
      final u = i / steps;
      final nx = u * 2 - 1;
      final x = startX + u * (endX - startX);
      final envelope = math.pow(math.max(0.0, 1 - nx * nx), 1.6).toDouble();
      final counter =
          math.sin(nx * math.pi * 1.1 - t * 0.9 + ribbon.phase) * 3.5 * envelope;
      path.lineTo(x, baseLineY + counter + ribbon.invert * 8 * envelope);
    }
    path.close();

    Color fade(Color c) => c.withOpacity((c.opacity * alpha).clamp(0.0, 1.0));
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fade(ribbon.invert < 0 ? ribbon.colorTop : ribbon.colorBottom),
            fade(ribbon.colorTop),
            fade(ribbon.invert > 0 ? ribbon.colorTop : ribbon.colorBottom),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTRB(
            center.dx, baseLineY - 26, center.dx + 1, baseLineY + 26)),
    );
  }

  void _drawHorizonFlare(Canvas canvas, Offset center, double r, double t,
      double energy, double pulse) {
    final horizonY = center.dy + 7;
    final breath = math.sin(t * 2.2) * 0.08 + energy * 0.25 + pulse * 0.3;
    final sphereRect = Rect.fromCircle(center: center, radius: r);

    Paint plusPaint(Shader shader) =>
        Paint()..blendMode = BlendMode.plus..shader = shader;

    // 1. 球内烟雾状体积漫射
    canvas.drawCircle(
      center,
      r,
      plusPaint(RadialGradient(
        center: Alignment(0, (horizonY - 2 - center.dy) / r),
        radius: 0.9,
        colors: [
          Color.fromRGBO(255, 250, 245, (0.28 + breath * 0.22).clamp(0.0, 1.0)),
          Color.fromRGBO(185, 200, 220, (0.14 + breath * 0.1).clamp(0.0, 1.0)),
          const Color(0x0D5A5F69),
          Colors.transparent,
        ],
        stops: const [0, 0.32, 0.68, 1],
      ).createShader(sphereRect)),
    );

    // 2. 下半部暖橙/琥珀金光晕（纵向压扁）
    canvas.save();
    canvas.translate(center.dx, horizonY + 5);
    canvas.scale(1.0, 0.34 + breath * 0.08);
    canvas.drawCircle(
      Offset.zero,
      r * 0.68,
      plusPaint(RadialGradient(
        colors: [
          Color.fromRGBO(255, 185, 120, (0.72 + breath * 0.2).clamp(0.0, 1.0)),
          Color.fromRGBO(235, 135, 75, (0.32 + breath * 0.12).clamp(0.0, 1.0)),
          const Color(0x0FA05028),
          Colors.transparent,
        ],
        stops: const [0, 0.42, 0.78, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.68))),
    );
    canvas.restore();

    // 3. 上半部冷调冰蓝光晕
    canvas.save();
    canvas.translate(center.dx, horizonY - 3);
    canvas.scale(1.05, 0.26 + breath * 0.07);
    canvas.drawCircle(
      Offset.zero,
      r * 0.72,
      plusPaint(RadialGradient(
        colors: [
          Color.fromRGBO(145, 215, 255, (0.78 + breath * 0.2).clamp(0.0, 1.0)),
          Color.fromRGBO(95, 175, 250, (0.34 + breath * 0.12).clamp(0.0, 1.0)),
          const Color(0x0D326EC8),
          Colors.transparent,
        ],
        stops: const [0, 0.45, 0.82, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.72))),
    );
    canvas.restore();

    // 4. 水平流光丝线
    final curveDip = 5.5 + math.sin(t * 2.8) * (1.8 + energy * 3.2);
    final streakPath = Path()
      ..moveTo(center.dx - r * 0.95, horizonY - 2)
      ..quadraticBezierTo(
          center.dx, horizonY + curveDip, center.dx + r * 0.95, horizonY - 2)
      ..quadraticBezierTo(center.dx, horizonY + curveDip - 4.5,
          center.dx - r * 0.95, horizonY - 2)
      ..close();
    canvas.drawPath(
      streakPath,
      plusPaint(LinearGradient(
        colors: [
          const Color(0x05B4D2F5),
          Color.fromRGBO(195, 225, 255, (0.32 + breath * 0.2).clamp(0.0, 1.0)),
          const Color(0xF2FFFFFF),
          Color.fromRGBO(195, 225, 255, (0.32 + breath * 0.2).clamp(0.0, 1.0)),
          const Color(0x05B4D2F5),
        ],
        stops: const [0, 0.22, 0.5, 0.78, 1],
      ).createShader(Rect.fromLTRB(
          center.dx - r * 0.96, horizonY, center.dx + r * 0.96, horizonY + 1))),
    );

    // 5. 核心高亮纯白弯月
    final coreHalfW = r * (0.54 + breath * 0.14);
    final waveShiftX = math.sin(t * 1.9) * 4 * s.ribbonMix;
    final corePath = Path()
      ..moveTo(center.dx - coreHalfW + waveShiftX * 0.3, horizonY - 1)
      ..quadraticBezierTo(
        center.dx + waveShiftX,
        horizonY + 8.5 + breath * 5,
        center.dx + coreHalfW + waveShiftX * 0.3,
        horizonY - 1,
      )
      ..quadraticBezierTo(
        center.dx + waveShiftX,
        horizonY + 1.2 - breath * 2.2,
        center.dx - coreHalfW + waveShiftX * 0.3,
        horizonY - 1,
      )
      ..close();
    canvas.drawPath(
      corePath,
      plusPaint(RadialGradient(
        colors: const [
          Color(0xFFFFFFFF),
          Color(0xD9F5FAFF),
          Color(0x47FFD7B9),
          Color(0x00FFFFFF),
        ],
        stops: const [0, 0.48, 0.82, 1],
      ).createShader(Rect.fromCircle(
          center: Offset(center.dx + waveShiftX * 0.5, horizonY + 3),
          radius: coreHalfW))),
    );
  }

  void _drawGlassOverlay(
      Canvas canvas, Offset center, double r, Rect sphereRect) {
    // 顶部高光反射
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.92),
          radius: 0.9,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.03),
            Colors.transparent,
          ],
          stops: const [0, 0.26, 0.55],
        ).createShader(sphereRect),
    );
    // 底部暖色反光
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.95),
          radius: 0.85,
          colors: [
            const Color(0xFFFFD2AF).withOpacity(0.09),
            Colors.transparent,
          ],
          stops: const [0, 0.5],
        ).createShader(sphereRect),
    );
    // 玻璃边缘描边
    canvas.drawCircle(
      center,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.09),
    );
  }

  @override
  bool shouldRepaint(covariant _SiriOrbPainter oldDelegate) => true;
}
