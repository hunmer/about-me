import 'dart:async';

import 'package:flutter/material.dart';

import 'shazam_pill.dart';
import 'voice_memo_card.dart';
import 'wave_data.dart';

/// Demo: 复刻 ui_1_1.html —— Shazam 灵动岛胶囊 & 深色语音备忘录卡片
///
/// 纯 Material 实现，无第三方依赖；SVG 标志与声波动画均用
/// CustomPainter / AnimationController 还原。
class AudioUiReplicaDemoPage extends StatefulWidget {
  const AudioUiReplicaDemoPage({super.key});

  @override
  State<AudioUiReplicaDemoPage> createState() => _AudioUiReplicaDemoPageState();
}

class _PlayerState {
  int progress;
  bool isPlaying = false;
  bool showPause;
  bool bookmarked = false;
  Timer? timer;

  _PlayerState({this.progress = 0, this.showPause = false});
}

class _AudioUiReplicaDemoPageState extends State<AudioUiReplicaDemoPage> {
  static const waveHeights = audioUiWaveHeights;

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
                child: ShazamPill(
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
                    VoiceMemoCard(
                      title: 'Nick Smith',
                      subtitle: 'Unit ABCD-1234 charging issue',
                      progress: _players[0].progress,
                      showPause: _players[0].showPause,
                      bookmarked: _players[0].bookmarked,
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
                    VoiceMemoCard(
                      title: 'Nick Smith',
                      subtitle: 'Unit ABCD-1234 charging issue',
                      progress: _players[1].progress,
                      showPause: _players[1].showPause,
                      bookmarked: _players[1].bookmarked,
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
