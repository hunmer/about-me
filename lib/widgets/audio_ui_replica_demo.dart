import 'dart:async';

import 'package:flutter/material.dart';

/// Demo: 复刻 ui_1_1.html —— Shazam 灵动岛胶囊 & 深色语音备忘录卡片
///
/// 纯 Material 实现，无第三方依赖；SVG 标志与声波动画均用
/// CustomPainter / AnimationController 还原。
class AudioUiReplicaDemoPage extends StatefulWidget {
  const AudioUiReplicaDemoPage({super.key});

  @override
  State<AudioUiReplicaDemoPage> createState() => _AudioUiReplicaDemoPageState();
}

class _AudioUiReplicaDemoPageState extends State<AudioUiReplicaDemoPage> {
  static const waveHeights = [
    8, 10, 7, 9, 13, 15, 13, 11, 9, 8, //
    8, 9, 11, 13, 15, 19, 17, 23, 25, 19,
    17, 21, 17, 13, 11, 9, 15, 17, 13, 11,
    9, 11, 9, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 9, 7, 9, 13, 15, 17, 15,
    11, 9, 11, 15, 19, 21, 17, 21, 25, 17,
    13, 11, 9, 15, 13, 17, 15, 13, 11, 7,
  ];

  bool _animatedMode = true;

  // ---- Shazam 灵动岛状态 ----
  bool _shazamAnimated = true;
  String _shazamTitle = 'Listening...';
  bool _shazamMatched = false;
  double _pillScale = 1.0;
  double _pillOpacity = 1.0;

  // ---- 语音卡片状态 ----
  final List<_PlayerState> _players = [
    _PlayerState(),
    _PlayerState(progress: 22, showPause: true),
  ];

  @override
  void dispose() {
    for (final p in _players) {
      p.timer?.cancel();
    }
    super.dispose();
  }

  // ==================== Shazam 灵动岛交互 ====================

  void _toggleShazamWave() => setState(() => _shazamAnimated = !_shazamAnimated);

  void _simulateSongMatch() {
    setState(() => _pillScale = 1.03);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _shazamTitle = 'Instant Crush';
        _shazamMatched = true;
        _pillScale = 1.0;
      });
    });
  }

  void _resetShazam() {
    setState(() {
      _pillScale = 1.0;
      _pillOpacity = 1.0;
      _shazamTitle = 'Listening...';
      _shazamMatched = false;
    });
  }

  void _dismissShazam() {
    setState(() {
      _pillScale = 0.82;
      _pillOpacity = 0.35;
    });
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _resetShazam();
    });
  }

  // ==================== 语音卡片交互 ====================

  void _togglePlay(int index) {
    final p = _players[index];
    if (p.isPlaying) {
      _stopPlayback(p);
    } else {
      if (p.progress >= waveHeights.length) p.progress = 0;
      p.isPlaying = true;
      p.showPause = true;
      p.timer = Timer.periodic(const Duration(milliseconds: 120), (t) {
        if (!mounted) return t.cancel();
        setState(() {
          if (p.progress < waveHeights.length) {
            p.progress += 1;
          } else {
            _stopPlayback(p);
          }
        });
      });
    }
    setState(() {});
  }

  void _stopPlayback(_PlayerState p) {
    p.isPlaying = false;
    p.showPause = false;
    p.timer?.cancel();
    p.timer = null;
  }

  void _swapCardsState() {
    _stopPlayback(_players[0]);
    _stopPlayback(_players[1]);
    final tmp = _players[0].progress;
    _players[0].progress = _players[1].progress;
    _players[1].progress = tmp;
    if (_players[0].progress > 0 && _players[1].progress == 0) {
      _players[0].showPause = true;
    }
    setState(() {});
  }

  // ==================== 全局模式 ====================

  void _setMode(bool animated) {
    setState(() {
      _animatedMode = animated;
      if (!animated) {
        _shazamAnimated = false;
        _resetShazam();
        _stopPlayback(_players[0]);
        _stopPlayback(_players[1]);
        _players[0].progress = 0;
        _players[1].progress = 22;
        _players[1].showPause = true;
      } else {
        _shazamAnimated = true;
      }
    });
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF0F4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildShazamSection(),
                  const SizedBox(height: 40),
                  _buildVoiceSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pixel-Perfect UI Replica',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const Text(
              '音频与识曲 UI 组件 1:1 复刻',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '支持原图静态 1:1 对比与实时可交互（点击播放、拖拽声波进度、动态波纹动画）',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xCCE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modeButton('动态交互模式', _animatedMode, () => _setMode(true)),
              const SizedBox(width: 4),
              _modeButton('原图 1:1 静态帧', !_animatedMode, () => _setMode(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionShell({
    required String tag,
    required Color tagColor,
    required String title,
    Widget? headerTrailing,
    required Widget body,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xB3E2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.only(bottom: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: tagColor,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                if (headerTrailing != null) headerTrailing,
              ],
            ),
          ),
          body,
        ],
      ),
    );
  }

  Widget _smallActionButton(String label, Color bg, Color fg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
        ),
      ),
    );
  }

  Widget _buildShazamSection() {
    return _buildSectionShell(
      tag: 'COMPONENT 01',
      tagColor: const Color(0xFF2563EB),
      title: 'Shazam 听歌识曲灵动岛胶囊 (Listening Pill)',
      headerTrailing: Wrap(
        spacing: 8,
        children: [
          _smallActionButton('模拟识曲成功', const Color(0xFFEFF6FF), const Color(0xFF2563EB), _simulateSongMatch),
          _smallActionButton('重置状态', const Color(0xFFF1F5F9), const Color(0xFF475569), _resetShazam),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD7D7D9), Color(0xFFE4E4E6), Color(0xFFD9D9DC)],
          ),
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: _pillScale,
              duration: const Duration(milliseconds: 350),
              curve: const Cubic(0.22, 1, 0.36, 1),
              child: AnimatedOpacity(
                opacity: _pillOpacity,
                duration: const Duration(milliseconds: 350),
                child: _ShazamPill(
                  animated: _shazamAnimated,
                  title: _shazamTitle,
                  subtitle: _shazamMatched ? 'Daft Punk — Instant Crush' : null,
                  onLogoTap: _toggleShazamWave,
                  onClose: _dismissShazam,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '提示：可点击左侧 Shazam 图标切换动效，或点击右侧 × 体验灵动岛收起与展开动画',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return _buildSectionShell(
      tag: 'COMPONENT 02',
      tagColor: const Color(0xFF059669),
      title: '深色语音备忘录卡片 (Paused & Playing States)',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('支持点击声波任意位置跳转进度', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 436),
                child: Column(
                  children: [
                    _VoiceCard(
                      state: _players[0],
                      onTogglePlay: () => _togglePlay(0),
                      onToggleBookmark: () => setState(() => _players[0].bookmarked = !_players[0].bookmarked),
                      onSeek: (p) => setState(() => _players[0].progress = p),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: IconButton(
                            tooltip: '点击互换上下卡片播放状态',
                            icon: const Icon(Icons.swap_vert, size: 30, color: Color(0xFFC8C8CC)),
                            onPressed: _swapCardsState,
                          ),
                        ),
                      ),
                    ),
                    _VoiceCard(
                      state: _players[1],
                      onTogglePlay: () => _togglePlay(1),
                      onToggleBookmark: () => setState(() => _players[1].bookmarked = !_players[1].bookmarked),
                      onSeek: (p) => setState(() => _players[1].progress = p),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '提示：点击任一卡片右侧的播放/暂停按钮可实时推进白色声波进度，点击声波条可自由定位，点击书签可收藏。',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 数据状态
// ============================================================================

class _PlayerState {
  int progress;
  bool isPlaying = false;
  bool showPause;
  bool bookmarked = false;
  Timer? timer;

  _PlayerState({this.progress = 0, this.showPause = false});
}

// ============================================================================
// 组件一：Shazam 灵动岛胶囊
// ============================================================================

class _ShazamPill extends StatefulWidget {
  final bool animated;
  final String title;
  final String? subtitle;
  final VoidCallback onLogoTap;
  final VoidCallback onClose;

  const _ShazamPill({
    required this.animated,
    required this.title,
    required this.subtitle,
    required this.onLogoTap,
    required this.onClose,
  });

  @override
  State<_ShazamPill> createState() => _ShazamPillState();
}

class _ShazamPillState extends State<_ShazamPill> with TickerProviderStateMixin {
  static const _staticHeights = [23.0, 15.0, 15.0, 9.0, 11.0, 6.0];

  // 每根音柱的关键帧 (t, height) 与周期/延迟，对应原 CSS keyframes
  static const _keyframes = [
    [(0.0, 23.0), (0.5, 10.0), (1.0, 23.0)],
    [(0.0, 15.0), (0.35, 24.0), (0.7, 9.0), (1.0, 15.0)],
    [(0.0, 15.0), (0.45, 7.0), (0.8, 21.0), (1.0, 15.0)],
    [(0.0, 9.0), (0.25, 18.0), (0.65, 7.0), (1.0, 9.0)],
    [(0.0, 11.0), (0.55, 19.0), (1.0, 11.0)],
    [(0.0, 6.0), (0.4, 13.0), (1.0, 6.0)],
  ];
  static const _periodsMs = [1050, 950, 1150, 900, 1100, 850];
  static const _delaysMs = [0, 100, 200, 150, 250, 50];
  static const _waveLoopMs = 5000;

  late final AnimationController _waveCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: _waveLoopMs));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    if (widget.animated) {
      _waveCtrl.repeat();
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ShazamPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated == oldWidget.animated) return;
    if (widget.animated) {
      _waveCtrl.repeat();
      _pulseCtrl.repeat(reverse: true);
    } else {
      _waveCtrl.stop();
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  double _barHeight(int index) {
    if (!widget.animated) return _staticHeights[index];
    final elapsed = _waveCtrl.value * _waveLoopMs + _delaysMs[index];
    final t = (elapsed % _periodsMs[index]) / _periodsMs[index];
    final frames = _keyframes[index];
    for (var i = 0; i < frames.length - 1; i++) {
      final (t0, h0) = frames[i];
      final (t1, h1) = frames[i + 1];
      if (t >= t0 && t <= t1) {
        final k = (t - t0) / (t1 - t0);
        // ease-in-out 近似
        final e = k * k * (3 - 2 * k);
        return h0 + (h1 - h0) * e;
      }
    }
    return frames.last.$2;
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 492),
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), blurRadius: 45, offset: Offset(0, 20), spreadRadius: -12),
            BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildLogo(),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.33,
                            height: 1.2,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.subtitle!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildEqualizer(),
                const SizedBox(width: 22),
                _buildCloseButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: widget.onLogoTap,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final s = 1.0 + 0.03 * _pulseCtrl.value;
          return Transform.scale(scale: s, child: child);
        },
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(0.44, -0.52), // ≈ circle at 72% 24%
              radius: 1.1,
              colors: [Color(0xFF47C6FF), Color(0xFF0088FF), Color(0xFF0051D5), Color(0xFF003DA6)],
              stops: [0.0, 0.42, 0.85, 1.0],
            ),
            boxShadow: [BoxShadow(color: Color(0x590088FF), blurRadius: 16)],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 左下与右上的光斑星芒
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.56, 0.52), // ≈ 22% 76%
                      radius: 0.56,
                      colors: [Color(0xE678F0FF), Color(0x5900C3FF), Color(0x0000C3FF)],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.4, -0.64), // ≈ 70% 18%
                      radius: 0.38,
                      colors: [Color(0xF2FFFFFF), Color(0x8069DCFF), Color(0x0069DCFF)],
                      stops: [0.0, 0.37, 1.0],
                    ),
                  ),
                ),
                const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CustomPaint(painter: _ShazamLogoPainter()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEqualizer() {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (context, _) {
        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 4.5),
                Container(
                  width: 4.5,
                  height: _barHeight(i),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF279AFF), Color(0xFF007AFF)],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: const Color(0xFF091B3A),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onClose,
        child: const SizedBox(
          width: 62,
          height: 62,
          child: Icon(Icons.close_rounded, size: 28, color: Color(0xFF1C74F5)),
        ),
      ),
    );
  }
}

/// Shazam 双 U 型互锁标志（旋转 -45°），还原原 SVG path
class _ShazamLogoPainter extends CustomPainter {
  const _ShazamLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.5
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-3.1415926 / 4);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.scale(scale);

    final upper = Path()
      ..moveTo(36, 45)
      ..lineTo(36, 35)
      ..cubicTo(36, 25.6112, 43.6112, 18, 53, 18)
      ..cubicTo(62.3888, 18, 70, 25.6112, 70, 35)
      ..lineTo(70, 53.5);
    final lower = Path()
      ..moveTo(64, 55)
      ..lineTo(64, 65)
      ..cubicTo(64, 74.3888, 56.3888, 82, 47, 82)
      ..cubicTo(37.6112, 82, 30, 74.3888, 30, 65)
      ..lineTo(30, 46.5);

    canvas.drawPath(upper, paint);
    canvas.drawPath(lower, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 组件二：深色语音备忘录卡片
// ============================================================================

class _VoiceCard extends StatelessWidget {
  final _PlayerState state;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleBookmark;
  final ValueChanged<int> onSeek;

  const _VoiceCard({
    required this.state,
    required this.onTogglePlay,
    required this.onToggleBookmark,
    required this.onSeek,
  });

  static const _waveHeights = _AudioUiReplicaDemoPageState.waveHeights;

  void _handleSeek(TapDownDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final ratio = (details.localPosition.dx / box.size.width).clamp(0.0, 1.0);
    onSeek((ratio * _waveHeights.length).round());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2D),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Nick Smith', style: TextStyle(fontSize: 14.5, color: Color(0xFF98989D))),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Unit ABCD-1234 charging issue',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: Color(0xFFF2F2F7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (waveContext) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _handleSeek(d, waveContext),
                    child: SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          for (var i = 0; i < _waveHeights.length; i++) ...[
                            if (i > 0) const SizedBox(width: 2.2),
                            Container(
                              width: 2,
                              height: _waveHeights[i].toDouble(),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: i < state.progress ? Colors.white : const Color(0xFF6E6E73),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onToggleBookmark,
                child: Icon(
                  state.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: onTogglePlay,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Icon(
                    state.showPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
