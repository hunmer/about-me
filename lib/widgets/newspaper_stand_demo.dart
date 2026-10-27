import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 报刊亭交互 UI Demo（复刻自 newspaper_stand_interactive_ui.html）
///
/// - 默认「堆叠模式」：5 份折叠报纸错落堆叠
/// - 点击任意报纸 / 右下切换胶囊进入「轮播模式」
/// - 轮播模式下支持左右拖拽、点击两侧报纸居中、点击中央报纸返回堆叠
class NewspaperStandDemo extends StatefulWidget {
  const NewspaperStandDemo({super.key});

  @override
  State<NewspaperStandDemo> createState() => _NewspaperStandDemoState();
}

class _NewspaperStandDemoState extends State<NewspaperStandDemo> {
  static const _springCurve = Cubic(0.22, 1, 0.36, 1);
  static const _animDuration = Duration(milliseconds: 650);

  bool _isStack = true;
  int _activeIndex = 1;
  int _navTab = 0;
  double _dragDelta = 0;
  bool _dragging = false;

  /// 堆叠模式下每张报纸的位移/旋转/缩放
  static const _stackTransforms = [
    (x: -6.0, y: -175.0, rot: -2.2, scale: 0.95, z: 1),
    (x: 6.0, y: -75.0, rot: 1.6, scale: 0.97, z: 2),
    (x: -4.0, y: 25.0, rot: -2.4, scale: 0.98, z: 3),
    (x: 4.0, y: 125.0, rot: 1.8, scale: 0.99, z: 4),
    (x: -5.0, y: 220.0, rot: -3.2, scale: 1.00, z: 5),
  ];

  void _setViewMode(bool stack, [int? targetIndex]) {
    setState(() {
      if (targetIndex != null) {
        _activeIndex = targetIndex.clamp(0, 4);
      }
      _isStack = stack;
    });
  }

  void _onCardTap(int index) {
    if (_isStack) {
      _setViewMode(false, index);
    } else if (index != _activeIndex) {
      setState(() => _activeIndex = index);
    } else {
      _setViewMode(true);
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isStack) return;
    setState(() {
      _dragging = true;
      _dragDelta = 0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    setState(() => _dragDelta += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final velocity = details.primaryVelocity ?? 0;
    var next = _activeIndex;
    final swipedLeft = _dragDelta < -48 || velocity < -280;
    final swipedRight = _dragDelta > 48 || velocity > 280;
    if (swipedLeft && !swipedRight && _activeIndex < 4) {
      next = _activeIndex + 1;
    } else if (swipedRight && !swipedLeft && _activeIndex > 0) {
      next = _activeIndex - 1;
    }
    setState(() {
      _dragging = false;
      _dragDelta = 0;
      _activeIndex = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('报刊亭交互 UI'),
        backgroundColor: const Color(0xFFF3F4F6),
      ),
      body: Center(
        child: Container(
          width: math.min(390, size.width),
          height: math.min(720, size.height * 0.86),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 60,
                offset: Offset(0, 24),
              ),
              BoxShadow(color: Color(0x0D0F172A), blurRadius: 16, offset: Offset(0, 4)),
            ],
            border: Border.all(color: const Color(0x0A000000)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              children: [
                // 报纸舞台
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: _onHorizontalDragStart,
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    child: _buildStage(),
                  ),
                ),
                // 底部白色渐隐遮罩
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 118,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 450),
                      opacity: _isStack ? 1 : 0.35,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.48, 0.8, 1],
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0xB8FFFFFF),
                              Color(0xF5FFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 轮播分页短条
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 135,
                  child: IgnorePointer(
                    ignoring: _isStack,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 400),
                      opacity: _isStack ? 0 : 1,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 450),
                        curve: _springCurve,
                        offset: Offset(0, _isStack ? 0.4 : 0),
                        child: _buildPaginationDashes(),
                      ),
                    ),
                  ),
                ),
                // 底部浮动控制条
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildNavPill(), _buildViewToggle()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 报纸舞台 ----------------

  Widget _buildStage() {
    // 按 z 序排序（小的先绘制）
    final order = List<int>.generate(5, (i) => i)..sort((a, b) {
      final za = _isStack ? _stackTransforms[a].z : (a == _activeIndex ? 10 : ((a - _activeIndex).abs() == 1 ? 5 : 1));
      final zb = _isStack ? _stackTransforms[b].z : (b == _activeIndex ? 10 : ((b - _activeIndex).abs() == 1 ? 5 : 1));
      return za.compareTo(zb);
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final i in order)
              // 必须带 key：切换 activeIndex 时 z 序会重排，
              // 无 key 会导致卡片按位置复用、从别的卡片的旧 transform 开始插值而跳变
              Positioned(
                key: ValueKey(i),
                left: cx - 143,
                top: cy - 94,
                child: _buildPositionedCard(i),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPositionedCard(int i) {
    double x, y, rot, scale, opacity;
    if (_isStack) {
      final c = _stackTransforms[i];
      x = c.x;
      y = c.y;
      rot = c.rot;
      scale = c.scale;
      opacity = 1;
    } else {
      final offset = i - _activeIndex;
      final shift = _dragDelta * 0.85;
      if (offset == 0) {
        x = shift;
        y = -15;
        rot = 1.6 + _dragDelta * 0.015;
        scale = 1.06;
        opacity = 1;
      } else if (offset == -1) {
        x = -295 + shift;
        y = 20;
        rot = -4.5;
        scale = 0.94;
        opacity = 1;
      } else if (offset == 1) {
        x = 295 + shift;
        y = 25;
        rot = -3.5;
        scale = 0.94;
        opacity = 1;
      } else {
        x = offset < 0 ? -600 : 600;
        y = 40;
        rot = offset < 0 ? -8 : 8;
        scale = 0.85;
        opacity = 0;
      }
    }
    final radians = rot * math.pi / 180;
    final matrix = Matrix4.identity()
      ..translate(x, y)
      ..rotateZ(radians)
      ..scale(scale);
    final duration = _dragging ? Duration.zero : _animDuration;
    return AnimatedOpacity(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 450),
      opacity: opacity,
      child: AnimatedContainer(
        duration: duration,
        curve: _springCurve,
        transform: matrix,
        transformAlignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _onCardTap(i),
          child: _NewspaperCard(index: i),
        ),
      ),
    );
  }

  // ---------------- 分页短条 ----------------

  Widget _buildPaginationDashes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          GestureDetector(
            onTap: () => setState(() => _activeIndex = i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: _springCurve,
                width: i == _activeIndex ? 22 : 18,
                height: 3,
                decoration: BoxDecoration(
                  color: i == _activeIndex
                      ? const Color(0xFF7A7A7A)
                      : const Color(0xFFE2E2E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- 左侧黑色导航胶囊 ----------------

  Widget _buildNavPill() {
    const icons = [
      Icons.newspaper_outlined,
      Icons.bookmark_border,
      Icons.search,
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
          BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: SizedBox(
        height: 38,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: _springCurve,
              left: _navTab * 48.0,
              top: 0,
              child: Container(
                width: 44,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < icons.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _navTab = i),
                    child: Container(
                      width: 44,
                      height: 38,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      color: Colors.transparent,
                      child: Icon(
                        icons[i],
                        size: 17,
                        color: i == _navTab
                            ? Colors.white
                            : const Color(0xFF71717A),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 右侧视图切换胶囊 ----------------

  Widget _buildViewToggle() {
    return GestureDetector(
      onTap: () => _setViewMode(!_isStack),
      child: Container(
        width: 92,
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F3),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: _springCurve,
              left: _isStack ? 42 : 0,
              top: 0,
              child: Container(
                width: 42,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _viewModeIcon(Icons.view_carousel_outlined, active: !_isStack),
                _viewModeIcon(Icons.view_agenda_outlined, active: _isStack),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewModeIcon(IconData icon, {required bool active}) {
    return SizedBox(
      width: 42,
      height: 38,
      child: Icon(
        icon,
        size: 19,
        color: active ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
      ),
    );
  }
}

// =============================================================
// 单张折叠报纸卡片（含层叠纸边、纹理、折痕光影）
// =============================================================

class _NewspaperCard extends StatelessWidget {
  const _NewspaperCard({required this.index});

  final int index;

  static const _pageBuilders = [
    _DailyMailPage.new,
    _WallStreetJournalPage.new,
    _DailyTelegraphPage.new,
    _WashingtonPostPage.new,
    _NewsdayPage.new,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 286,
      height: 188,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 后方层叠纸边
          Positioned(
            left: -2.5,
            right: -2.5,
            top: 2,
            bottom: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDCDAD4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(3),
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFC8C6C0), offset: Offset(-1.5, 1)),
                  BoxShadow(color: Color(0xFFCFCDC7), offset: Offset(1.5, 1)),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // 主纸面
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAE8E3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 纸张纹理
                  const Opacity(
                    opacity: 0.18,
                    child: _NetImage(
                      'https://images.unsplash.com/photo-1586075010923-2dd4570fb338?auto=format&fit=crop&w=600&q=80',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 报纸内容
                  Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 0),
                    child: _pageBuilders[index](),
                  ),
                  // 中央竖向折痕
                  Center(
                    child: Container(
                      width: 16,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          stops: [0, 0.42, 0.55, 1],
                          colors: [
                            Color(0x00000000),
                            Color(0x06000000),
                            Color(0x38FFFFFF),
                            Color(0x00000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 顶部卷边高光 + 两侧弧度光影
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.035, 0.07, 0.15, 0.88, 1],
                        colors: [
                          Color(0xA6FFFFFF),
                          Color(0x40FFFFFF),
                          Color(0x08000000),
                          Color(0x00000000),
                          Color(0x05000000),
                          Color(0x24000000),
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        stops: [0, 0.025, 0.08, 0.92, 0.975, 1],
                        colors: [
                          Color(0x1C000000),
                          Color(0x2EFFFFFF),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x24FFFFFF),
                          Color(0x21000000),
                        ],
                      ),
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
}

// =============================================================
// 公共小部件
// =============================================================

class _NetImage extends StatelessWidget {
  const _NetImage(this.url, {this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Container(color: const Color(0xFFD4D4D4)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: const Color(0xFFDCDAD4));
      },
    );
  }
}

/// 微缩正文字体
TextStyle _micro({Color color = const Color(0xFF3A3A38), bool bold = false}) {
  return TextStyle(
    fontSize: 4.3,
    height: 1.22,
    color: color,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
  );
}

/// 衬线标题字体
TextStyle _serif(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = const Color(0xFF141413),
  double height = 1.1,
  double letterSpacing = -0.2,
  bool italic = false,
}) {
  return TextStyle(
    fontSize: size,
    height: height,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    fontFamilyFallback: const ['serif'],
  );
}

/// 哥特报名字体（无黑体字库时用衬线粗体近似）
TextStyle _gothic(double size) {
  return TextStyle(
    fontSize: size,
    height: 1,
    fontWeight: FontWeight.w900,
    color: const Color(0xFF141413),
    letterSpacing: -0.5,
    fontFamilyFallback: const ['serif'],
  );
}

Widget _photoBox(String url, {String? caption}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFD4D4D4),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFFA3A3A3)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _NetImage(url),
          if (caption != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xA6000000),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 4.2,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// =============================================================
// 五份报纸头版
// =============================================================

/// 0. Daily Mail
class _DailyMailPage extends StatelessWidget {
  const _DailyMailPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部信息行
        Container(
          padding: const EdgeInsets.only(bottom: 2),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x99757575))),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TUESDAY, JUNE 4, 2024',
                style: TextStyle(fontSize: 4.5, color: Color(0xFF525252)),
              ),
              Text(
                '£1.10',
                style: TextStyle(fontSize: 4.5, color: Color(0xFF525252)),
              ),
            ],
          ),
        ),
        // 报头
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Daily', style: _gothic(27)),
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x80E5E5E5),
                  border: Border.all(color: const Color(0x66737373)),
                ),
                child: const Text('👑', style: TextStyle(fontSize: 6)),
              ),
              const SizedBox(width: 6),
              Text('Mail', style: _gothic(27)),
            ],
          ),
        ),
        // 主新闻区
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF262626)),
                bottom: BorderSide(color: Color(0xFF262626)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 8,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I believe death is not the end... That’s the only explanation for these ghostly snaps I’ve seen',
                          style: _serif(
                            10.8,
                            weight: FontWeight.w800,
                            color: const Color(0xFF111111),
                            height: 1.06,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'By MICHAEL J. FINN — SEE PAGE 30',
                            style: TextStyle(
                              fontSize: 5.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                              height: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          color: const Color(0xFFC81E1E),
                          child: const Text(
                            'EXCLUSIVE: HOW TO STOP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Center(
                            child: Text(
                              'RISHI’S',
                              style: _serif(
                                23,
                                weight: FontWeight.w900,
                                color: const Color(0xFF181818),
                                height: 0.88,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: _photoBox(
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=320&q=80',
                    caption: 'Lilibet turns 3 at Montecito home',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 1. The Wall Street Journal
class _WallStreetJournalPage extends StatelessWidget {
  const _WallStreetJournalPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 报头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF404040))),
          ),
          child: Column(
            children: [
              Text(
                'THE WALL STREET JOURNAL.',
                style: _serif(18.5, height: 1, letterSpacing: -0.37),
              ),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.only(top: 1.5),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xB3A3A3A3))),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TUESDAY, JUNE 4, 2024 · VOL. CCLXXXIII NO. 130',
                      style: TextStyle(fontSize: 4.2, color: Color(0xFF525252)),
                    ),
                    Text(
                      '**** \$5.00',
                      style: TextStyle(fontSize: 4.2, color: Color(0xFF525252)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 多栏头版
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左栏 What’s News
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.only(right: 3),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xB3A3A3A3)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 2),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFA3A3A3)),
                            ),
                          ),
                          child: Text(
                            'What’s News',
                            style: _serif(6.5, height: 1.05),
                          ),
                        ),
                        Text(
                          '♦ Business & Finance Markets edged higher as tech shares led gains across global exchanges.\n'
                          '♦ World-Wide Officials prepared new border enforcement measures effective this week.\n'
                          '♦ Manufacturing activity eased in May amid higher borrowing costs.',
                          style: _micro(),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // 中央主栏
                Expanded(
                  flex: 8,
                  child: Container(
                    padding: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xB3A3A3A3)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            'Biden Seeks to Tighten Border',
                            style: _serif(10.8, height: 1.08),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Plan would shut down asylum processing when crossings surge',
                                        style: _micro(
                                          color: const Color(0xFF262626),
                                          bold: true,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'WASHINGTON—President Biden is preparing to sign an executive order Tuesday that would temporarily shut down asylum requests once daily crossings pass a set threshold.\n'
                                        'Administration officials said the directive marks the most restrictive border step in years.',
                                        style: _micro(),
                                        textAlign: TextAlign.justify,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 8,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 58,
                                      width: double.infinity,
                                      child: _photoBox(
                                        'https://images.unsplash.com/photo-1541872703-74c5e44368f9?auto=format&fit=crop&w=450&q=80',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Border Patrol agents monitored crossings near the southern port of entry on Monday afternoon.',
                                            style: _micro(),
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            'Lawmakers from both parties weighed the political and legal fallout ahead of November.',
                                            style: _micro(),
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // 右栏
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'Voters Back Successor To Mexico’s Leader',
                          style: _serif(6.3, height: 1.08),
                        ),
                      ),
                      Text(
                        'MEXICO CITY—Claudia Sheinbaum won a landslide victory to become Mexico’s first female president.\n'
                        'Investors watched closely for signals on constitutional and energy reforms.',
                        style: _micro(),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 2. The Daily Telegraph
class _DailyTelegraphPage extends StatelessWidget {
  const _DailyTelegraphPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部预告条
        Container(
          padding: const EdgeInsets.only(bottom: 2),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFA3A3A3))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2ECE4),
                    border: Border(
                      left: BorderSide(color: Color(0xFFB91C1C), width: 2),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Palmer gets seat with Brexiteer Farage...',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                          height: 1.2,
                        ),
                      ),
                      Text(
                        'Election Special · Full coverage Inside',
                        style: TextStyle(
                          fontSize: 4.5,
                          color: Color(0xFF525252),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 36,
                height: 20,
                child: _photoBox(
                  'https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=160&q=80',
                ),
              ),
            ],
          ),
        ),
        // 报头
        Container(
          padding: const EdgeInsets.symmetric(vertical: 1),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF404040))),
          ),
          child: Center(
            child: Text('The Daily Telegraph', style: _gothic(22)),
          ),
        ),
        // 主标题与图片
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'I’m back to lead the revolt',
                    style: _serif(14.5, height: 1.05),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.only(right: 4),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0x99A3A3A3)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '♦ Return shakes up Westminster race',
                                style: TextStyle(
                                  fontSize: 5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(height: 2.5),
                              Text(
                                'Nigel Farage announced yesterday he will stand in Clacton and take over as leader of Reform UK in a dramatic u-turn.\n'
                                'Conservative strategists warned the move could reshape dozens of marginal seats.',
                                style: _micro(),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 8,
                        child: _photoBox(
                          'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=450&q=80',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 3. The Washington Post
class _WashingtonPostPage extends StatelessWidget {
  const _WashingtonPostPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 报头
        Container(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF404040))),
          ),
          child: Column(
            children: [
              Text('The Washington Post', style: _gothic(22)),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  'Democracy Dies in Darkness',
                  style: TextStyle(
                    fontSize: 5,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF525252),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 内容区
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 9,
                  child: Container(
                    padding: const EdgeInsets.only(right: 6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xB3A3A3A3)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 1),
                          child: Text(
                            'HUNTER BIDEN’S TRIAL OPENS IN DEL.',
                            style: TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFF404040),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: SizedBox(
                            height: 86,
                            width: double.infinity,
                            child: _photoBox(
                              'https://images.unsplash.com/photo-1575517111478-7f6afd0973db?auto=format&fit=crop&w=500&q=80',
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Jury selection concluded Monday in Wilmington federal court as first family watched.',
                                style: _micro(),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Prosecutors outlined federal firearm charges while defense attorneys urged caution.',
                                style: _micro(),
                                textAlign: TextAlign.justify,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'Biden to limit cap on asylum',
                          style: _serif(8, height: 1.08),
                        ),
                      ),
                      Text(
                        'The White House finalized sweeping executive actions aimed at curbing southern border crossings.\n'
                        'Measure takes effect immediately once daily average exceeds 2,500.',
                        style: _micro(),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 4. Newsday
class _NewsdayPage extends StatelessWidget {
  const _NewsdayPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部蓝红推广条
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Expanded(
                child: ColoredBox(
                  color: Color(0xFF1D4ED8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'L.I. HIGH SCHOOL SPORTS · P. 42',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: ColoredBox(
                  color: Color(0xFFB91C1C),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'TRANSIT FARE UPDATES · P. 8',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 报头
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF1E3A8A), width: 2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 24,
                height: 16,
                child: _photoBox(
                  'https://images.unsplash.com/photo-1508433957232-3107f5fd5995?auto=format&fit=crop&w=120&q=80',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Newsday',
                style: _serif(25, weight: FontWeight.w900, height: 1,
                    letterSpacing: -0.75),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 1),
                child: Text(
                  'LONG ISLAND',
                  style: TextStyle(
                    fontSize: 4.8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF737373),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 底部主图与标题
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SUMMER SHORE ALERT ON L.I.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: Color(0xFF111111),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Officials unveil expanded drone & lifeguard patrols across Long Island beaches ahead of peak season.',
                          style: _micro(),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: _photoBox(
                  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=450&q=80',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
