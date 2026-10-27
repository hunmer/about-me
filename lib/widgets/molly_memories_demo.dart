import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Molly 2024 - iOS Memories UI 动效复刻
/// 点击手机屏幕在「散落拼贴态」与「九宫格态」之间做弹簧过渡
class MollyMemoriesDemo extends StatefulWidget {
  const MollyMemoriesDemo({super.key});

  @override
  State<MollyMemoriesDemo> createState() => _MollyMemoriesDemoState();
}

class _CardLayout {
  const _CardLayout({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.rot,
    required this.z,
    required this.radius,
  });

  final double x;
  final double y;
  final double w;
  final double h;
  final double rot;
  final int z;
  final double radius;
}

class _PhotoData {
  const _PhotoData({
    required this.id,
    required this.collage,
    required this.grid,
    required this.scene,
  });

  final String id;
  final _CardLayout collage;
  final _CardLayout grid;
  final _MollyScene scene;
}

class _MollyMemoriesDemoState extends State<MollyMemoriesDemo> {
  static const Duration _duration = Duration(milliseconds: 720);
  static const Cubic _spring = Cubic(0.22, 1.08, 0.36, 1);
  static const Cubic _fade = Cubic(0.25, 0.8, 0.25, 1);

  static const double _shellW = 380;
  static const double _shellH = 790;
  static const double _shellPadding = 11;

  bool _isGrid = false;
  bool _liked = false;
  String? _toast;
  Timer? _toastTimer;

  static const List<_PhotoData> _photos = [
    _PhotoData(
      id: 'misty-hill',
      collage: _CardLayout(x: 26, y: 150, w: 112, h: 158, rot: -4.2, z: 12, radius: 22),
      grid: _CardLayout(x: 25, y: 204, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.misty,
    ),
    _PhotoData(
      id: 'sunlit-door',
      collage: _CardLayout(x: 114, y: 232, w: 105, h: 145, rot: 2.8, z: 11, radius: 22),
      grid: _CardLayout(x: 130, y: 204, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.doorway,
    ),
    _PhotoData(
      id: 'snow-pines',
      collage: _CardLayout(x: 196, y: 174, w: 116, h: 164, rot: 4.8, z: 13, radius: 22),
      grid: _CardLayout(x: 235, y: 204, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.snowforest,
    ),
    _PhotoData(
      id: 'snow-portrait',
      collage: _CardLayout(x: 27, y: 334, w: 112, h: 154, rot: -4.5, z: 14, radius: 22),
      grid: _CardLayout(x: 25, y: 309, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.snowdog,
    ),
    _PhotoData(
      id: 'curled-sleep',
      collage: _CardLayout(x: 204, y: 356, w: 114, h: 150, rot: 5.5, z: 15, radius: 22),
      grid: _CardLayout(x: 235, y: 309, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.curled,
    ),
    _PhotoData(
      id: 'camper-bed',
      collage: _CardLayout(x: 34, y: 498, w: 116, h: 154, rot: -5.8, z: 16, radius: 22),
      grid: _CardLayout(x: 25, y: 414, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.camper,
    ),
    _PhotoData(
      id: 'sunset-lake',
      collage: _CardLayout(x: 132, y: 454, w: 112, h: 158, rot: -2.6, z: 18, radius: 22),
      grid: _CardLayout(x: 130, y: 414, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.sunset,
    ),
    _PhotoData(
      id: 'car-carrier',
      collage: _CardLayout(x: 196, y: 538, w: 114, h: 152, rot: 4.5, z: 17, radius: 22),
      grid: _CardLayout(x: 235, y: 414, w: 98, h: 98, rot: 0, z: 10, radius: 16),
      scene: _MollyScene.carseat,
    ),
  ];

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _toggle() => setState(() => _isGrid = !_isGrid);

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _onAction(String action) {
    switch (action) {
      case 'share':
        _showToast('已准备分享「Molly 2024」回忆');
      case 'heart':
        setState(() => _liked = !_liked);
        _showToast(_liked ? '已添加到「个人收藏」' : '已取消收藏');
      case 'info':
        _showToast('Molly · 2024年度精选 (共 8 张实况照片)');
      case 'delete':
        _showToast('演示模式：保留美好回忆');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: _buildPhoneShell(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneShell() {
    return SizedBox(
      width: _shellW,
      height: _shellH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1C),
              borderRadius: BorderRadius.circular(56),
              boxShadow: const [
                BoxShadow(color: Color(0xFF404044), spreadRadius: 2),
                BoxShadow(color: Color(0xFF18181B), spreadRadius: 4),
                BoxShadow(
                  color: Color(0x610F172A),
                  blurRadius: 70,
                  offset: Offset(0, 30),
                  spreadRadius: -15,
                ),
                BoxShadow(
                  color: Color(0x330F172A),
                  blurRadius: 25,
                  offset: Offset(0, 10),
                  spreadRadius: -5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(_shellPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(45),
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  color: Colors.white,
                  child: _buildScreen(),
                ),
              ),
            ),
          ),
          _hwButton(left: -6, top: 145, height: 28),
          _hwButton(left: -6, top: 195, height: 52),
          _hwButton(left: -6, top: 260, height: 52),
          _hwButton(right: -6, top: 215, height: 76),
        ],
      ),
    );
  }

  Widget _hwButton({
    double? left,
    double? right,
    required double top,
    required double height,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Container(
        width: 3,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3F3F46), Color(0xFF18181B), Color(0xFF3F3F46)],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen() {
    final sorted = [..._photos]
      ..sort((a, b) => (_isGrid ? a.grid.z : a.collage.z)
          .compareTo(_isGrid ? b.grid.z : b.collage.z));

    return Stack(
      children: [
        ..._buildBlobs(),
        for (final p in sorted) _buildPhotoCard(p),
        _buildMatchedTexts(),
        _buildActionBar(),
        _buildStatusBar(),
        _buildHomeIndicator(),
        _buildToast(),
      ],
    );
  }

  List<Widget> _buildBlobs() {
    return [
      _blob(
        key: const ValueKey('glow'),
        width: _isGrid ? 112 : 230,
        height: _isGrid ? 112 : 115,
        left: _isGrid ? 123 : 64,
        top: _isGrid ? 302 : 66,
        opacity: _isGrid ? 1 : 0.92,
        blur: 12,
        colors: const [
          Color(0xE08498B2),
          Color(0x8C9AAEC2),
          Color(0x00B4C6D4),
        ],
        stops: const [0, 0.55, 1],
      ),
      _blob(
        key: const ValueKey('green'),
        width: 270,
        height: 320,
        left: 10,
        top: 180,
        opacity: _isGrid ? 0 : 0.95,
        blur: 18,
        colors: const [Color(0x9E87B298), Color(0x40A7D1B8), Color(0x00000000)],
        stops: const [0, 0.7, 1],
      ),
      _blob(
        key: const ValueKey('warm'),
        width: 250,
        height: 280,
        left: 80,
        top: 340,
        opacity: _isGrid ? 0 : 0.9,
        blur: 18,
        colors: const [Color(0x8CC4A48A), Color(0x33D6BEA8), Color(0x00000000)],
        stops: const [0, 0.7, 1],
      ),
      _blob(
        key: const ValueKey('blue'),
        width: 260,
        height: 310,
        left: 65,
        top: 440,
        opacity: _isGrid ? 0 : 0.92,
        blur: 18,
        colors: const [Color(0x8C7492B9), Color(0x339CB6D6), Color(0x00000000)],
        stops: const [0, 0.7, 1],
      ),
    ];
  }

  Widget _blob({
    required Key key,
    required double width,
    required double height,
    required double left,
    required double top,
    required double opacity,
    required double blur,
    required List<Color> colors,
    required List<double> stops,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: _duration,
      curve: _spring,
      left: left,
      top: top,
      width: width,
      height: height,
      child: AnimatedOpacity(
        duration: _duration,
        curve: _fade,
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: colors, stops: stops),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(_PhotoData data) {
    final t = _isGrid ? data.grid : data.collage;
    return AnimatedPositioned(
      key: ValueKey(data.id),
      duration: _duration,
      curve: _spring,
      left: t.x,
      top: t.y,
      width: t.w,
      height: t.h,
      child: AnimatedRotation(
        turns: t.rot / 360,
        duration: _duration,
        curve: _spring,
        child: AnimatedContainer(
          duration: _duration,
          curve: _spring,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 0.5,
            ),
            boxShadow: _isGrid
                ? const [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x570F172A),
                      blurRadius: 34,
                      offset: Offset(0, 18),
                      spreadRadius: -8,
                    ),
                    BoxShadow(
                      color: Color(0x2E0F172A),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                      spreadRadius: -3,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(t.radius),
            child: CustomPaint(
              painter: _MollyPhotoPainter(data.scene),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedTexts() {
    const titleStyle = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.15,
      height: 1,
      color: Colors.white,
      shadows: [Shadow(color: Color(0x615F738C), blurRadius: 16, offset: Offset(0, 2))],
    );
    const yearStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.26,
      height: 1,
      color: Color(0xEBFFFFFF),
      shadows: [Shadow(color: Color(0x735F738C), blurRadius: 8, offset: Offset(0, 1))],
    );

    return Stack(
      children: [
        AnimatedPositioned(
          duration: _duration,
          curve: _spring,
          left: 0,
          right: 0,
          top: _isGrid ? 326 : 104,
          height: 46,
          child: IgnorePointer(
            child: AnimatedScale(
              scale: _isGrid ? 0.58 : 1,
              duration: _duration,
              curve: _spring,
              child: const Center(child: Text('Molly', style: titleStyle)),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: _duration,
          curve: _spring,
          left: 0,
          right: 0,
          top: _isGrid ? 372 : 89,
          height: 13,
          child: IgnorePointer(
            child: AnimatedScale(
              scale: _isGrid ? 0.86 : 1,
              duration: _duration,
              curve: _spring,
              child: const Center(child: Text('2024', style: yearStyle)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return AnimatedPositioned(
      duration: _duration,
      curve: _spring,
      left: 0,
      right: 0,
      top: 528,
      height: 36,
      child: AnimatedOpacity(
        duration: _duration,
        curve: _fade,
        opacity: _isGrid ? 1 : 0,
        child: AnimatedSlide(
          duration: _duration,
          curve: _spring,
          offset: _isGrid ? Offset.zero : const Offset(0, 0.4),
          child: IgnorePointer(
            ignoring: !_isGrid,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionBtn(
                  icon: Icons.ios_share,
                  tooltip: '分享',
                  onTap: () => _onAction('share'),
                ),
                const SizedBox(width: 28),
                _actionBtn(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  tooltip: '收藏',
                  color: _liked ? const Color(0xFFF43F5E) : null,
                  onTap: () => _onAction('heart'),
                ),
                const SizedBox(width: 28),
                _actionBtn(
                  icon: Icons.info_outline,
                  tooltip: '信息',
                  onTap: () => _onAction('info'),
                ),
                const SizedBox(width: 28),
                _actionBtn(
                  icon: Icons.delete_outline,
                  tooltip: '删除',
                  onTap: () => _onAction('delete'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 19, color: color ?? const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    const dark = Color(0xFF0F172A);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 48,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '9:41',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dark,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 112,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF121324),
                        border: Border.all(color: const Color(0xFF1F243D)),
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _signalBars(),
                    const SizedBox(width: 6),
                    const Icon(Icons.wifi, size: 15, color: dark),
                    const SizedBox(width: 6),
                    _battery(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalBars() {
    const heights = [4.5, 6.5, 9.0, 11.5];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
          Container(
            width: 3,
            height: h,
            margin: const EdgeInsets.only(right: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }

  Widget _battery() {
    return Row(
      children: [
        Container(
          width: 22,
          height: 11,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3.5),
            border: Border.all(color: const Color(0x660F172A)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 1.5,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0x660F172A),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeIndicator() {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 134,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToast() {
    final show = _toast != null;
    return Positioned(
      bottom: 34,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          curve: const Cubic(0.22, 1, 0.36, 1),
          opacity: show ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: const Cubic(0.22, 1, 0.36, 1),
            offset: show ? Offset.zero : const Offset(0, 0.5),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: const Color(0xC70F172A),
                    child: Text(
                      _toast ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MollyScene { misty, doorway, snowforest, snowdog, curled, camper, sunset, carseat }

/// 用 CustomPainter 复刻原 HTML Canvas 绘制的 8 张 Molly 照片场景
class _MollyPhotoPainter extends CustomPainter {
  _MollyPhotoPainter(this.scene);

  final _MollyScene scene;

  static const double _w = 320;
  static const double _h = 440;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);
    switch (scene) {
      case _MollyScene.misty:
        _misty(canvas);
      case _MollyScene.doorway:
        _doorway(canvas);
      case _MollyScene.snowforest:
        _snowforest(canvas);
      case _MollyScene.snowdog:
        _snowdog(canvas);
      case _MollyScene.curled:
        _curled(canvas);
      case _MollyScene.camper:
        _camper(canvas);
      case _MollyScene.sunset:
        _sunset(canvas);
      case _MollyScene.carseat:
        _carseat(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant _MollyPhotoPainter oldDelegate) => false;

  Paint _fill(Color color) => Paint()..color = color;

  Paint _linear(List<Color> colors, List<double> stops, Offset from, Offset to) =>
      Paint()..shader = ui.Gradient.linear(from, to, colors, stops);

  Paint _radial(List<Color> colors, List<double> stops, Offset center, double radius) =>
      Paint()..shader = ui.Gradient.radial(center, radius, colors, stops);

  void _rect(Canvas c, Paint p, double x, double y, double w, double h) =>
      c.drawRect(Rect.fromLTWH(x, y, w, h), p);

  void _oval(Canvas c, Color color, double cx, double cy, double rx, double ry,
      [double rot = 0]) {
    final paint = _fill(color);
    if (rot == 0) {
      c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), paint);
    } else {
      c.save();
      c.translate(cx, cy);
      c.rotate(rot);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
      c.restore();
    }
  }

  void _circle(Canvas c, Color color, double cx, double cy, double r) =>
      c.drawCircle(Offset(cx, cy), r, _fill(color));

  /// 毛茸茸的黑白棕小狗 Molly
  void _drawDog(Canvas c, double cx, double cy, double scale, String pose) {
    c.save();
    c.translate(cx, cy);
    c.scale(scale);

    if (pose == 'closeup') {
      _oval(c, const Color(0xFF18181B), 0, 55, 58, 68, -0.1);
      _oval(c, const Color(0xFFF8FAFC), 8, 45, 32, 44, 0.1);
      _oval(c, const Color(0xFF141417), 0, -18, 44, 40);
      _oval(c, const Color(0xFF141417), -38, -12, 16, 30, 0.35);
      _oval(c, const Color(0xFF141417), 38, -12, 16, 30, -0.35);
      _oval(c, const Color(0xFFF1F5F9), 2, -6, 15, 26);
      const tan = Color(0xFFC27849);
      _circle(c, tan, -14, -28, 6);
      _circle(c, tan, 16, -28, 6);
      _circle(c, tan, -18, -4, 9);
      _circle(c, tan, 20, -4, 9);
      const eye = Color(0xFF09090B);
      _circle(c, eye, -14, -18, 4.5);
      _circle(c, eye, 16, -18, 4.5);
      _circle(c, Colors.white, -15.5, -19.5, 1.5);
      _circle(c, Colors.white, 14.5, -19.5, 1.5);
      _oval(c, eye, 2, 2, 8, 6);
      _oval(c, const Color(0xFFF472B6), 3, 14, 5, 7, 0.1);
    } else if (pose == 'curled') {
      _oval(c, const Color(0xFF18181B), 0, 0, 86, 66, -0.2);
      _oval(c, const Color(0xFFF8FAFC), -28, 12, 34, 24, 0.5);
      _oval(c, const Color(0xFF141417), -36, -14, 38, 32, -0.3);
      _oval(c, const Color(0xFFB4693E), -48, -4, 14, 10, 0.2);
      _oval(c, const Color(0xFFF1F5F9), -62, 6, 16, 11, -0.3);
    } else {
      const body = Color(0xFF141417);
      _oval(c, body, 0, 0, 26, 15, -0.1);
      _circle(c, body, 20, -14, 12);
      _oval(c, const Color(0xFFF8FAFC), 16, -2, 8, 11, 0.2);
      _circle(c, const Color(0xFFF8FAFC), 29, -13, 4.5);
      final stroke = Paint()
        ..color = body
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(-16, 8)
        ..lineTo(-18, 26)
        ..moveTo(-6, 10)
        ..lineTo(-5, 25)
        ..moveTo(12, 10)
        ..lineTo(14, 27)
        ..moveTo(20, 8)
        ..lineTo(24, 25)
        ..moveTo(-22, -4)
        ..quadraticBezierTo(-38, -18, -32, -28);
      c.drawPath(path, stroke);
    }
    c.restore();
  }

  void _misty(Canvas c) {
    _rect(
      c,
      _linear(
        const [Color(0xFFDCDFE2), Color(0xFFB8C2BE), Color(0xFF4A5A4E), Color(0xFF1E2920)],
        const [0, 0.42, 0.68, 1],
        Offset.zero,
        const Offset(0, _h),
      ),
      0,
      0,
      _w,
      _h,
    );
    final hill1 = Path()
      ..moveTo(0, 220)
      ..quadraticBezierTo(140, 255, _w, 310)
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
    c.drawPath(hill1, _fill(const Color(0xBF2A3A2C)));
    final hill2 = Path()
      ..moveTo(0, 290)
      ..quadraticBezierTo(180, 280, _w, 240)
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
    c.drawPath(hill2, _fill(const Color(0xFF202D21)));
    _rect(
      c,
      _linear(
        const [Color(0xEBEBEEF0), Color(0x00EBEEF0)],
        const [0, 1],
        Offset.zero,
        const Offset(0, 260),
      ),
      0,
      0,
      _w,
      260,
    );
    _drawDog(c, 205, 338, 1.35, 'standing');
  }

  void _doorway(Canvas c) {
    _rect(c, _fill(const Color(0xFF8B6F56)), 0, 0, _w, _h);
    _rect(c, _fill(const Color(0xFF4A3D33)), 0, 0, 105, 260);
    _rect(
      c,
      _linear(
        const [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
        const [0, 0.7, 1],
        const Offset(110, 20),
        const Offset(220, 260),
      ),
      108,
      18,
      110,
      240,
    );
    _rect(c, _fill(const Color(0xFFC2A88E)), 218, 0, 102, 265);
    _rect(
      c,
      _linear(
        const [Color(0xFF785A3C), Color(0xFF5C4028), Color(0xFF3B2718)],
        const [0, 0.5, 1],
        const Offset(0, 255),
        const Offset(0, _h),
      ),
      0,
      255,
      _w,
      _h - 255,
    );
    final light = Path()
      ..moveTo(108, 255)
      ..lineTo(218, 255)
      ..lineTo(270, _h)
      ..lineTo(65, _h)
      ..close();
    c.drawPath(light, _fill(const Color(0x73FFF8EB)));
    _drawDog(c, 188, 300, 1.35, 'standing');
  }

  void _snowforest(Canvas c) {
    _rect(
      c,
      _linear(
        const [Color(0xFF6A93CB), Color(0xFFB8D0EB)],
        const [0, 1],
        Offset.zero,
        const Offset(0, 240),
      ),
      0,
      0,
      _w,
      240,
    );
    _rect(
      c,
      _linear(
        const [Color(0xFFEEF4FB), Color(0xFFDCE7F5), Color(0xFFB0C4DE)],
        const [0, 0.5, 1],
        const Offset(0, 220),
        const Offset(0, _h),
      ),
      0,
      220,
      _w,
      _h - 220,
    );
    const trees = [
      (35.0, 20.0, 65.0, 220.0),
      (92.0, 45.0, 50.0, 195.0),
      (185.0, 60.0, 45.0, 175.0),
      (245.0, 10.0, 70.0, 235.0),
      (290.0, 30.0, 60.0, 220.0),
    ];
    for (final (tx, ty, tw, th) in trees) {
      _rect(c, _fill(const Color(0xFF27201C)), tx - 4, ty + th - 35, 8, 40);
      final paint = _fill(const Color(0xFF19261E));
      for (var i = 0; i < 5; i++) {
        final cy = ty + i * (th * 0.16);
        final cw = tw * (0.45 + i * 0.15);
        final tri = Path()
          ..moveTo(tx, cy)
          ..lineTo(tx - cw, cy + 48)
          ..lineTo(tx + cw, cy + 48)
          ..close();
        c.drawPath(tri, paint);
      }
    }
    _oval(c, const Color(0x597391B9), 80, 270, 95, 18, -0.1);
    _oval(c, const Color(0x597391B9), 250, 290, 85, 22, 0.15);
    _drawDog(c, 152, 296, 1.05, 'standing');
  }

  void _snowdog(Canvas c) {
    _rect(
      c,
      _radial(
        const [Color(0xFFF4F7FB), Color(0xFFDFE7F2), Color(0xFFBCC8D8)],
        const [0, 0.65, 1],
        const Offset(_w * 0.5, _h * 0.5),
        280,
      ),
      0,
      0,
      _w,
      _h,
    );
    _circle(c, const Color(0xFF334155), 30, 35, 65);
    _oval(c, const Color(0x5994A3B8), 230, 360, 22, 12, 0.3);
    _oval(c, const Color(0x5994A3B8), 85, 390, 28, 15, -0.2);
    _drawDog(c, 148, 225, 1.48, 'closeup');
  }

  void _curled(Canvas c) {
    _rect(
      c,
      _radial(
        const [Color(0xFF9EB398), Color(0xFF7C9078), Color(0xFF586956)],
        const [0, 0.7, 1],
        const Offset(_w * 0.5, _h * 0.5),
        260,
      ),
      0,
      0,
      _w,
      _h,
    );
    for (var i = 0; i < 65; i++) {
      final color = i.isEven ? const Color(0x59486044) : const Color(0x47D2DCCD);
      _oval(c, color, (i * 53) % _w, (i * 79) % _h, 14, 6, (i % 5) * 0.6);
    }
    _drawDog(c, 165, 225, 1.52, 'curled');
  }

  void _camper(Canvas c) {
    _rect(
      c,
      _linear(
        const [Color(0xFF7C4A24), Color(0xFFB87338), Color(0xFF6E3F1D)],
        const [0, 0.5, 1],
        Offset.zero,
        const Offset(_w, 240),
      ),
      0,
      0,
      _w,
      260,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(78, 108, 165, 86), const Radius.circular(10)),
      _fill(const Color(0xFFC7E2E8)),
    );
    _rect(c, _fill(const Color(0xFF3B593F)), 78, 152, 165, 42);
    final sidePaint = _fill(const Color(0xFFDCBFA6));
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(10, 118, 48, 82), const Radius.circular(6)),
      sidePaint,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(262, 118, 48, 82), const Radius.circular(6)),
      sidePaint,
    );
    final bed = Path()
      ..moveTo(0, 225)
      ..quadraticBezierTo(160, 205, _w, 230)
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
    c.drawPath(
      bed,
      _linear(
        const [Color(0xFFF1ECE6), Color(0xFFDDD5CC), Color(0xFF9C8C7E)],
        const [0, 0.6, 1],
        const Offset(0, 210),
        const Offset(0, _h),
      ),
    );
    _oval(c, const Color(0xFFD96B38), 52, 265, 42, 18, -0.2);
    _drawDog(c, 185, 258, 0.95, 'standing');
  }

  void _sunset(Canvas c) {
    _rect(
      c,
      _linear(
        const [Color(0xFF3E629C), Color(0xFF6A89B8), Color(0xFFD69E72), Color(0xFFE89858)],
        const [0, 0.58, 0.84, 1],
        Offset.zero,
        const Offset(0, 245),
      ),
      0,
      0,
      _w,
      245,
    );
    final trees = Path()
      ..moveTo(0, 242)
      ..lineTo(120, 232)
      ..lineTo(240, 238)
      ..lineTo(_w, 228)
      ..lineTo(_w, 250)
      ..lineTo(0, 250)
      ..close();
    c.drawPath(trees, _fill(const Color(0xFF181C24)));
    _rect(
      c,
      _linear(
        const [Color(0xFF5A6D82), Color(0xFF273545)],
        const [0, 1],
        const Offset(0, 245),
        const Offset(0, 320),
      ),
      0,
      245,
      _w,
      75,
    );
    final grass = Path()
      ..moveTo(0, 315)
      ..quadraticBezierTo(180, 290, _w, 305)
      ..lineTo(_w, _h)
      ..lineTo(0, _h)
      ..close();
    c.drawPath(
      grass,
      _linear(
        const [Color(0xFF1E2C22), Color(0xFF0F1712)],
        const [0, 1],
        const Offset(0, 305),
        const Offset(0, _h),
      ),
    );
    _drawDog(c, 162, 338, 0.85, 'standing');
  }

  void _carseat(Canvas c) {
    _rect(c, _fill(const Color(0xFFCBD5E1)), 0, 0, _w, _h);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 15, _w - 48, 220), const Radius.circular(28)),
      _linear(
        const [Color(0xFF334155), Color(0xFF1E293B)],
        const [0, 1],
        Offset.zero,
        const Offset(0, 240),
      ),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 215, _w - 36, 175), const Radius.circular(24)),
      _fill(const Color(0xFF94A3B8)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 265, _w - 56, 135), const Radius.circular(18)),
      _fill(const Color(0xFFF1F5F9)),
    );
    _drawDog(c, 165, 225, 1.38, 'closeup');
  }
}
