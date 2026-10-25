import 'package:flutter/material.dart';

/// Shazam 听歌识曲灵动岛胶囊（原 _ShazamPill，拆分为独立组件后转为公开）
class ShazamPill extends StatefulWidget {
  final bool animated;
  final String title;
  final String? subtitle;
  final VoidCallback onLogoTap;
  final VoidCallback onClose;

  const ShazamPill({
    super.key,
    required this.animated,
    required this.title,
    required this.subtitle,
    required this.onLogoTap,
    required this.onClose,
  });

  @override
  State<ShazamPill> createState() => _ShazamPillState();
}

class _ShazamPillState extends State<ShazamPill> with TickerProviderStateMixin {
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
  void didUpdateWidget(covariant ShazamPill oldWidget) {
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
