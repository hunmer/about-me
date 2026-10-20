import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

/// Moments — NEW YORK 互动地图 demo
///
/// 由 moments_new_york_interactive_ui.html 转换而来：
/// - 地图层使用 flutter_map（OSM 瓦片）替代原 HTML 的手绘 SVG 地图
/// - 照片大头针 / 手账详情页 / 贴纸均用 Flutter  widget 重写
class MomentsNycMapDemo extends StatefulWidget {
  const MomentsNycMapDemo({super.key});

  @override
  State<MomentsNycMapDemo> createState() => _MomentsNycMapDemoState();
}

// ---------------------------------------------------------------------------
// 数据模型
// ---------------------------------------------------------------------------

class _MomentCardData {
  const _MomentCardData({
    required this.imageUrl,
    required this.caption,
    this.captionMuted = false,
    this.tag,
    this.tagAlignment = Alignment.bottomLeft,
    this.tagColor,
    this.tagBorderColor,
  });

  final String imageUrl;
  final String caption;
  final bool captionMuted;
  final String? tag;
  final Alignment tagAlignment;
  final Color? tagColor;
  final Color? tagBorderColor;
}

class _MomentData {
  const _MomentData({
    required this.id,
    required this.title,
    required this.showLibertyStickers,
    required this.cards,
  });

  final String id;
  final String title;
  final bool showLibertyStickers;
  final List<_MomentCardData> cards;
}

enum _PinKind { single, heroCluster, sunsetCluster, walkCluster }

class _MapPinData {
  const _MapPinData({
    required this.momentId,
    required this.point,
    required this.kind,
    required this.rotation,
    this.badgeMonth,
    this.badgeDay,
    this.imageUrl,
    this.grayscale = false,
  });

  final String momentId;
  final LatLng point;
  final _PinKind kind;
  final double rotation;
  final String? badgeMonth;
  final int? badgeDay;
  final String? imageUrl;
  final bool grayscale;
}

// ---------------------------------------------------------------------------
// 主 State
// ---------------------------------------------------------------------------

class _MomentsNycMapDemoState extends State<MomentsNycMapDemo>
    with TickerProviderStateMixin {
  static const _paperCream = Color(0xFFF3EFE6);
  static const _accentBlue = Color(0xFF3843F5);
  static const _ink = Color(0xFF18181B);

  final _mapController = MapController();
  final _cardController = PageController(viewportFraction: 0.72, initialPage: 2);

  late final AnimationController _stickerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  String? _openMomentId;
  bool _previewMode = false;
  int _activePage = 2; // 0=装饰边卡, 1..3=卡片 0..2

  String? _toastText;
  Timer? _toastTimer;

  static const _placeOfPowerPoint = LatLng(31.2335, 121.4751); // 人民广场

  static const _captionsCycle = [
    'Midtown Manhattan',
    'Central Park South ✨',
    'NYC Golden Hour',
  ];
  int _captionCycleIndex = 0;

  static final _moments = <String, _MomentData>{
    'place-of-power': const _MomentData(
      id: 'place-of-power',
      title: 'PLACE OF POWER',
      showLibertyStickers: true,
      cards: [
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1534430480872-3498386e7856?auto=format&fit=crop&w=700&q=80',
          caption: 'description',
          captionMuted: true,
          tag: 'Interesting story',
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1568515387631-8b650bbcdb90?auto=format&fit=crop&w=700&q=80',
          caption: 'Midtown Manhattan',
          tag: 'Cool\nStatue',
          tagAlignment: Alignment.topRight,
          tagBorderColor: Color(0xFF4ADE80),
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&w=700&q=80',
          caption: 'Empire State view',
          tag: '5th Avenue',
          tagAlignment: Alignment.bottomRight,
          tagColor: _accentBlue,
        ),
      ],
    ),
    'sunset': const _MomentData(
      id: 'sunset',
      title: 'SUNSET',
      showLibertyStickers: false,
      cards: [
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=crop&w=700&q=80',
          caption: 'Golden hour streets',
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=700&q=80',
          caption: 'Manhattanhenge glow',
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1500916434205-0c77489c6cf7?auto=format&fit=crop&w=700&q=80',
          caption: 'Hudson River dusk',
        ),
      ],
    ),
    'walk': const _MomentData(
      id: 'walk',
      title: 'WALK',
      showLibertyStickers: false,
      cards: [
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1518717758536-85ae29035b6d?auto=format&fit=crop&w=700&q=80',
          caption: 'Morning buddy walk',
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1485871981521-5b1fd3805eee?auto=format&fit=crop&w=700&q=80',
          caption: 'Williamsburg Bridge',
        ),
        _MomentCardData(
          imageUrl:
              'https://images.unsplash.com/photo-1522083165195-3424ed129620?auto=format&fit=crop&w=700&q=80',
          caption: 'East River breeze',
        ),
      ],
    ),
  };

  static const _pins = [
    _MapPinData(
      momentId: 'west-ny',
      point: LatLng(31.2242, 121.4108), // 中山公园
      kind: _PinKind.single,
      rotation: -6,
      badgeMonth: 'MAY',
      badgeDay: 16,
      grayscale: true,
      imageUrl:
          'https://images.unsplash.com/photo-1518391846015-55a9cc003b25?auto=format&fit=crop&w=300&q=80',
    ),
    _MapPinData(
      momentId: 'place-of-power',
      point: _placeOfPowerPoint, // 人民广场
      kind: _PinKind.heroCluster,
      rotation: 0,
    ),
    _MapPinData(
      momentId: 'chelsea',
      point: LatLng(31.1903, 121.4369), // 徐家汇
      kind: _PinKind.single,
      rotation: -3,
      badgeMonth: 'MAY',
      badgeDay: 11,
      imageUrl:
          'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?auto=format&fit=crop&w=300&q=80',
    ),
    _MapPinData(
      momentId: 'gramercy',
      point: LatLng(31.2197, 121.4752), // 新天地
      kind: _PinKind.single,
      rotation: 6,
      badgeMonth: 'MAY',
      badgeDay: 23,
      imageUrl:
          'https://images.unsplash.com/photo-1522083165195-3424ed129620?auto=format&fit=crop&w=300&q=80',
    ),
    _MapPinData(
      momentId: 'sunset',
      point: LatLng(31.2397, 121.5015), // 陆家嘴
      kind: _PinKind.sunsetCluster,
      rotation: 0,
    ),
    _MapPinData(
      momentId: 'walk',
      point: LatLng(31.2095, 121.4680), // 田子坊
      kind: _PinKind.walkCluster,
      rotation: 0,
    ),
  ];

  static const _avatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=120&q=80',
  ];

  @override
  void dispose() {
    _toastTimer?.cancel();
    _stickerCtrl.dispose();
    _cardController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // 交互
  // -------------------------------------------------------------------------

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toastText = text);
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toastText = null);
    });
  }

  void _openDetail(String momentId) {
    setState(() {
      _openMomentId = momentId;
      _previewMode = false;
      _activePage = 2;
      _captionCycleIndex = 0;
    });
    if (_cardController.hasClients) {
      _cardController.jumpToPage(2);
    }
  }

  void _closeDetail() => setState(() => _openMomentId = null);

  void _onNewMoment() {
    _mapController.move(_placeOfPowerPoint, 13);
    Timer(const Duration(milliseconds: 280), () {
      if (mounted) _openDetail('place-of-power');
    });
  }

  void _bounceStickers() {
    _cardController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    _stickerCtrl.forward(from: 0);
  }

  void _cycleCaption() {
    setState(() {
      _captionCycleIndex = (_captionCycleIndex + 1) % _captionsCycle.length;
    });
    _showToast('Caption updated');
  }

  _MomentData get _activeMoment =>
      _moments[_openMomentId] ?? _moments['place-of-power']!;

  // -------------------------------------------------------------------------
  // 构建
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final detailOpen = _openMomentId != null;
    return Material(
      color: _paperCream,
      child: SafeArea(
        child: Stack(
          children: [
            // 地图视图（打开详情时缩放淡出）
            AnimatedScale(
              scale: detailOpen ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 420),
              curve: const Cubic(0.22, 1, 0.36, 1),
              child: AnimatedOpacity(
                opacity: detailOpen ? 0 : 1,
                duration: const Duration(milliseconds: 380),
                curve: const Cubic(0.22, 1, 0.36, 1),
                child: _buildMap(),
              ),
            ),
            // 地图页顶部栏
            if (!detailOpen) _buildMapHeader(),
            // 地图页底部按钮
            if (!detailOpen) _buildNewMomentButton(),
            // 手账详情视图
            IgnorePointer(
              ignoring: !detailOpen,
              child: AnimatedOpacity(
                opacity: detailOpen ? 1 : 0,
                duration: const Duration(milliseconds: 380),
                curve: const Cubic(0.22, 1, 0.36, 1),
                child: AnimatedScale(
                  scale: detailOpen ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 420),
                  curve: const Cubic(0.22, 1, 0.36, 1),
                  child: _buildDetailView(),
                ),
              ),
            ),
            // Toast
            _buildToast(),
          ],
        ),
      ),
    );
  }

  // ------------------------------ 地图视图 ------------------------------

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(31.2280, 121.4650), // 上海市区
        initialZoom: 12.2,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'github.hunmer.aboutme',
        ),
        MarkerLayer(
          markers: [
            for (final pin in _pins)
              Marker(
                point: pin.point,
                width: _pinSize(pin.kind).width,
                height: _pinSize(pin.kind).height,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _openDetail(pin.momentId),
                  child: _buildPin(pin),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Size _pinSize(_PinKind kind) => switch (kind) {
        _PinKind.single => const Size(72, 92),
        _PinKind.heroCluster => const Size(210, 240),
        _PinKind.sunsetCluster => const Size(180, 178),
        _PinKind.walkCluster => const Size(152, 158),
      };

  Widget _buildPin(_MapPinData pin) => switch (pin.kind) {
        _PinKind.single => _buildSinglePin(pin),
        _PinKind.heroCluster => _buildHeroCluster(),
        _PinKind.sunsetCluster => _buildSunsetCluster(),
        _PinKind.walkCluster => _buildWalkCluster(),
      };

  Widget _buildMapHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_paperCream, Color(0xD9F3EFE6), Color(0x00F3EFE6)],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 汉堡菜单
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 14,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Moments',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1917),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _retroTitle('NEW YORK', 31, 3.5),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: _ink),
                  const SizedBox(width: 10),
                  _avatar(_avatars[0], 28, borderColor: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewMomentButton() {
    return Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Center(
        child: FilledButton.icon(
          onPressed: _onNewMoment,
          style: FilledButton.styleFrom(
            backgroundColor: _accentBlue,
            padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
            shape: const StadiumBorder(),
            elevation: 12,
            shadowColor: _accentBlue.withValues(alpha: 0.55),
          ),
          icon: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 14, color: _accentBlue),
          ),
          label: const Text(
            'New Moment',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ------------------------------ 详情视图 ------------------------------

  Widget _buildDetailView() {
    final moment = _activeMoment;
    return Container(
      color: _paperCream,
      child: Column(
        children: [
          // 顶部：返回 / 标题 / 蓝点
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _closeDetail,
                  icon: const Icon(Icons.chevron_left, size: 30, color: _ink),
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _retroTitle(moment.title, 22, 3),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _accentBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentBlue.withValues(alpha: 0.15),
                      width: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 协作头像（3 个叠放总宽 68，整体居中）
          Center(
            child: SizedBox(
              width: 68,
              height: 28,
              child: Stack(
                children: [
                  for (var i = 0; i < _avatars.length; i++)
                    Positioned(
                      left: i * 20.0,
                      child: _avatar(_avatars[i], 28, borderColor: _paperCream),
                    ),
                ],
              ),
            ),
          ),
          // 卡片区（网格纸背景 + 横向翻页）
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _previewMode ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: CustomPaint(painter: _ScrapbookGridPainter()),
                  ),
                ),
                // 桌面端 PageView 默认只响应触摸拖拽，需显式放开鼠标
                ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PageView.builder(
                    controller: _cardController,
                    itemCount: 4, // 0=装饰边卡, 1..3=卡片 0..2
                    onPageChanged: (i) => setState(() => _activePage = i),
                    itemBuilder: (context, page) =>
                        _buildDetailPage(page, moment),
                  ),
                ),
              ],
            ),
          ),
          // 底部工具栏
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _toolButton(
                      icon: Icons.emoji_emotions_outlined,
                      tooltip: '贴纸弹跳',
                      onTap: _bounceStickers,
                    ),
                    const SizedBox(width: 12),
                    _toolButton(
                      icon: Icons.edit_outlined,
                      tooltip: '画笔',
                      onTap: () => _showToast('Pen mode ready'),
                    ),
                    const SizedBox(width: 12),
                    _toolButton(
                      text: 'Aa',
                      tooltip: '编辑文案',
                      onTap: _cycleCaption,
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () =>
                      setState(() => _previewMode = !_previewMode),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _previewMode ? _accentBlue : Colors.white,
                    foregroundColor: _previewMode
                        ? Colors.white
                        : const Color(0xFF272F8F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                    elevation: 4,
                  ),
                  child: Text(
                    _previewMode ? 'Done' : 'Preview',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPage(int page, _MomentData moment) {
    // 装饰边卡
    if (page == 0) {
      return _detailCard(
        imageUrl:
            'https://images.unsplash.com/photo-1499092346589-b9b6be3e94b2?auto=format&fit=crop&w=600&q=80',
        caption: 'soho loft',
        captionColor: const Color(0xFFA8A29E),
        rotationDeg: 2,
      );
    }
    final card = moment.cards[page - 1];
    final rotations = [-2.0, 1.0, 3.0];
    final isFocused = _activePage == page;
    final showStickers = moment.showLibertyStickers && page == 2;

    var caption = card.caption;
    var captionMuted = card.captionMuted;
    if (moment.id == 'place-of-power' && page == 2 && _captionCycleIndex > 0) {
      caption = _captionsCycle[_captionCycleIndex];
      captionMuted = false;
    }

    return _detailCard(
      imageUrl: card.imageUrl,
      caption: caption,
      captionColor: captionMuted
          ? const Color(0xFFA8A29E)
          : const Color(0xFF44403C),
      captionBold: !captionMuted,
      rotationDeg: rotations[page - 1],
      tag: card.tag,
      tagAlignment: card.tagAlignment,
      tagColor: card.tagColor,
      tagBorderColor: card.tagBorderColor,
      overlay: showStickers && isFocused ? _buildLibertyStickers() : null,
    );
  }

  Widget _buildLibertyStickers() {
    return AnimatedBuilder(
      animation: _stickerCtrl,
      builder: (context, _) {
        final t = _stickerCtrl.value;
        final wobble = math.sin(2 * math.pi * t) * (1 - t);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 自由女神贴纸（左上）
            Positioned(
              top: -64,
              left: -36,
              child: Transform.rotate(
                angle: (-6 + 12 * wobble) * math.pi / 180,
                child: Transform.scale(
                  scale: 1 + 0.18 * wobble,
                  child: SvgPicture.string(
                    _libertySvg,
                    width: 105,
                    height: 145,
                  ),
                ),
              ),
            ),
            // WOW 云朵贴纸（右下）
            Positioned(
              bottom: -28,
              right: -48,
              child: Transform.rotate(
                angle: -4 * wobble * math.pi / 180,
                child: Transform.scale(
                  scale: 1 + 0.16 * wobble,
                  child: _buildWowSticker(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWowSticker() {
    return SizedBox(
      width: 155,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.string(_wowCloudSvg, width: 155, height: 86),
          Transform.rotate(
            angle: -5 * math.pi / 180,
            child: _retroTitle('WOW', 32, 3.2, fillColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ------------------------------ 通用小部件 ------------------------------

  Widget _retroTitle(
    String text,
    double fontSize,
    double strokeWidth, {
    Color fillColor = const Color(0xFFF6F1E5),
  }) {
    final style = TextStyle(
      fontSize: fontSize,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w900,
      letterSpacing: fontSize * 0.03,
      height: 1.05,
      shadows: const [
        Shadow(color: _ink, offset: Offset(-1, 1)),
        Shadow(color: _ink, offset: Offset(-2, 2)),
        Shadow(color: _ink, offset: Offset(-3, 3)),
        Shadow(color: _ink, offset: Offset(-4, 4)),
      ],
    );
    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = _ink,
          ),
        ),
        Text(text, style: style.copyWith(color: fillColor)),
      ],
    );
  }

  Widget _avatar(String url, double size, {required Color borderColor}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(child: _netImage(url, fit: BoxFit.cover)),
    );
  }

  Widget _toolButton({
    IconData? icon,
    String? text,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: _ink)
                : Text(
                    text ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildToast() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _toastText != null ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _ink.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12),
                ],
              ),
              child: Text(
                _toastText ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------ 地图大头针 ------------------------------

  Widget _photoFrame({
    required double size,
    double? height,
    required double rotationDeg,
    required String imageUrl,
    bool grayscale = false,
    Widget? badge,
    Widget? extra,
    double frameRadius = 18,
    double imageRadius = 14,
  }) {
    Widget image = _netImage(imageUrl, fit: BoxFit.cover);
    if (grayscale) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Container(
        width: size,
        height: height ?? size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(frameRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3814141E),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(imageRadius),
                child: image,
              ),
            ),
            if (badge != null) badge,
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }

  Widget _calBadge(String month, int day, {double rotationDeg = 0}) {
    return Transform.rotate(
      angle: rotationDeg * math.pi / 180,
      child: Container(
        width: 30,
        height: 33,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: const BoxDecoration(
                color: Color(0xFF522120),
                borderRadius: BorderRadius.vertical(top: Radius.circular(6.5)),
              ),
              child: Text(
                month,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$day',
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePin(_MapPinData pin) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _photoFrame(
          size: 66,
          rotationDeg: pin.rotation,
          imageUrl: pin.imageUrl!,
          grayscale: pin.grayscale,
        ),
        if (pin.badgeMonth != null)
          Positioned(
            top: 2,
            left: 10,
            child: _calBadge(
              pin.badgeMonth!,
              pin.badgeDay!,
              rotationDeg: -pin.rotation / 2,
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCluster() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 蕨叶贴纸（右上）
        Positioned(
          top: -8,
          right: 4,
          child: Transform.rotate(
            angle: 12 * math.pi / 180,
            child: SvgPicture.string(_fernLeafSvg, width: 84, height: 84),
          ),
        ),
        // 后左照片 MAY 28
        Positioned(
          top: 12,
          left: 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _photoFrame(
                size: 95,
                rotationDeg: -12,
                imageUrl:
                    'https://images.unsplash.com/photo-1534430480872-3498386e7856?auto=format&fit=crop&w=300&q=80',
              ),
              Positioned(
                top: -12,
                left: 12,
                child: _calBadge('MAY', 28, rotationDeg: 6),
              ),
            ],
          ),
        ),
        // 后右照片
        Positioned(
          top: 28,
          right: 12,
          child: _photoFrame(
            size: 110,
            rotationDeg: 6,
            imageUrl:
                'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?auto=format&fit=crop&w=300&q=80',
          ),
        ),
        // 前景主照片
        Positioned(
          top: 44,
          left: 20,
          child: _photoFrame(
            size: 136,
            rotationDeg: -3,
            imageUrl:
                'https://images.unsplash.com/photo-1568515387631-8b650bbcdb90?auto=format&fit=crop&w=500&q=80',
            extra: Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // 协作头像（左下）
        Positioned(
          bottom: 30,
          left: 12,
          child: SizedBox(
            width: 64,
            height: 28,
            child: Stack(
              children: [
                for (var i = 0; i < _avatars.length; i++)
                  Positioned(
                    left: i * 18.0,
                    child: _avatar(_avatars[i], 28, borderColor: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        // PLACE OF POWER 蓝色贴纸（右下）
        Positioned(
          bottom: 12,
          right: 0,
          child: Transform.rotate(
            angle: -3 * math.pi / 180,
            child: Column(
              children: [
                _stickerLabel('PLACE', const EdgeInsets.symmetric(horizontal: 10)),
                Transform.translate(
                  offset: const Offset(0, -3),
                  child: _stickerLabel(
                    'OF POWER',
                    const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stickerLabel(String text, EdgeInsets padding) {
    return Container(
      padding: padding.add(const EdgeInsets.symmetric(vertical: 2)),
      decoration: BoxDecoration(
        color: _accentBlue,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E28A0).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildSunsetCluster() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 左照片 MAY 7
        Positioned(
          top: 16,
          left: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _photoFrame(
                size: 92,
                height: 98,
                rotationDeg: -6,
                imageUrl:
                    'https://images.unsplash.com/photo-1519125323398-675f0ddb6308?auto=format&fit=crop&w=300&q=80',
              ),
              Positioned(
                top: -12,
                left: 12,
                child: _calBadge('MAY', 7, rotationDeg: 3),
              ),
            ],
          ),
        ),
        // 右照片 MAY 9
        Positioned(
          top: 8,
          right: 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _photoFrame(
                size: 108,
                height: 112,
                rotationDeg: 6,
                imageUrl:
                    'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=400&q=80',
              ),
              Positioned(
                top: -12,
                left: 24,
                child: _calBadge('MAY', 9, rotationDeg: -6),
              ),
            ],
          ),
        ),
        // 头像（左下）
        Positioned(
          bottom: 38,
          left: 8,
          child: SizedBox(
            width: 44,
            height: 24,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: _avatar(_avatars[0], 24, borderColor: Colors.white),
                ),
                Positioned(
                  left: 16,
                  child: _avatar(_avatars[1], 24, borderColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
        // SUNSET 日出贴纸
        Positioned(
          bottom: 8,
          right: 8,
          child: SizedBox(
            width: 104,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.string(_sunburstSvg, width: 104, height: 48),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'SUNSET',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalkCluster() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 左照片 MAY 9
        Positioned(
          top: 12,
          left: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _photoFrame(
                size: 82,
                height: 88,
                rotationDeg: -6,
                imageUrl:
                    'https://images.unsplash.com/photo-1518717758536-85ae29035b6d?auto=format&fit=crop&w=300&q=80',
              ),
              Positioned(
                top: -12,
                left: 10,
                child: _calBadge('MAY', 9, rotationDeg: 3),
              ),
            ],
          ),
        ),
        // 右照片 MAY 13
        Positioned(
          top: 16,
          right: 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _photoFrame(
                size: 84,
                height: 88,
                rotationDeg: 6,
                imageUrl:
                    'https://images.unsplash.com/photo-1485871981521-5b1fd3805eee?auto=format&fit=crop&w=300&q=80',
              ),
              Positioned(
                top: -12,
                left: 20,
                child: _calBadge('MAY', 13, rotationDeg: -3),
              ),
            ],
          ),
        ),
        // 头像（左下）
        Positioned(
          bottom: 38,
          left: 8,
          child: _avatar(_avatars[2], 24, borderColor: Colors.white),
        ),
        // WALK 粉色贴纸
        Positioned(
          bottom: 12,
          right: 12,
          child: Transform.rotate(
            angle: -2 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCE7F3)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              child: const Text(
                'WALK',
                style: TextStyle(
                  color: Color(0xFFDB2777),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------ 详情卡片 ------------------------------

  Widget _detailCard({
    required String imageUrl,
    required String caption,
    required Color captionColor,
    required double rotationDeg,
    bool captionBold = false,
    String? tag,
    Alignment tagAlignment = Alignment.bottomLeft,
    Color? tagColor,
    Color? tagBorderColor,
    Widget? overlay,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(
                angle: rotationDeg * math.pi / 180,
                child: Container(
                  width: 258,
                  height: 262,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x381C1917),
                        blurRadius: 40,
                        offset: Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Color(0x141C1917),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _netImage(imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                      if (tag != null)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Align(
                              alignment: tagAlignment,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: tagColor ??
                                      _ink.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: tagBorderColor ??
                                        Colors.white.withValues(alpha: 0.15),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  tag,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
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
              if (overlay != null)
                Positioned.fill(child: overlay),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            caption,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              letterSpacing: -0.2,
              color: captionColor,
              fontWeight: captionBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _netImage(String url, {BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFE7E2D6),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        color: const Color(0xFF44403C),
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.white54),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 网格纸背景
// ---------------------------------------------------------------------------

class _ScrapbookGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(168, 160, 146, 0.2)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 贴纸 SVG（移植自原 HTML 内联 SVG）
// ---------------------------------------------------------------------------

const _fernLeafSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M50 85 C45 60, 20 40, 10 25 C28 28, 42 40, 48 52 C42 32, 32 15, 28 5 C45 15, 52 32, 54 48 C58 28, 68 12, 78 6 C74 24, 65 40, 58 55 C72 40, 85 32, 95 30 C82 46, 68 58, 55 72 Z" fill="#ffffff" stroke="#ffffff" stroke-width="9" stroke-linejoin="round"/>
  <path d="M50 85 C45 60, 20 40, 10 25 C28 28, 42 40, 48 52 C42 32, 32 15, 28 5 C45 15, 52 32, 54 48 C58 28, 68 12, 78 6 C74 24, 65 40, 58 55 C72 40, 85 32, 95 30 C82 46, 68 58, 55 72 Z" fill="#2f855a" stroke="#18181b" stroke-width="3" stroke-linejoin="round"/>
  <path d="M50 85 Q54 45 62 18" stroke="#68d391" stroke-width="2" fill="none"/>
</svg>
''';

const _libertySvg = '''
<svg viewBox="-10 -10 140 180" xmlns="http://www.w3.org/2000/svg">
  <g stroke="#ffffff" stroke-width="11" stroke-linejoin="round" stroke-linecap="round">
    <path d="M32 18 L38 42 L26 68 L42 148 L88 148 L94 82 L75 62 L58 38 L40 22 Z" fill="#ffffff"/>
  </g>
  <path d="M30 8 C24 16, 25 25, 33 27 C40 25, 42 16, 35 10 C34 14, 31 13, 30 8 Z" fill="#f59e0b" stroke="#18181b" stroke-width="3" stroke-linejoin="round"/>
  <rect x="28" y="26" width="12" height="6" rx="2" fill="#fbbf24" stroke="#18181b" stroke-width="2.8"/>
  <path d="M31 32 L36 68 L48 66 L40 32 Z" fill="#6ee7b7" stroke="#18181b" stroke-width="3" stroke-linejoin="round"/>
  <path d="M44 58 L38 42 L52 52 L55 35 L62 50 L74 37 L69 54 L85 45 L74 60 L90 57 L75 66 Z" fill="#6ee7b7" stroke="#18181b" stroke-width="2.8" stroke-linejoin="round"/>
  <path d="M47 58 C54 54, 68 55, 75 62 L72 78 C64 84, 54 83, 49 76 Z" fill="#6ee7b7" stroke="#18181b" stroke-width="3" stroke-linejoin="round"/>
  <path d="M53 66 L61 66 M64 67 L70 67" stroke="#18181b" stroke-width="2.8" stroke-linecap="round"/>
  <path d="M57 73 Q61 75 65 73" stroke="#18181b" stroke-width="2.2" fill="none" stroke-linecap="round"/>
  <path d="M35 66 L26 92 L38 96 L36 146 L86 146 L90 95 L74 78 L48 76 Z" fill="#34d399" stroke="#18181b" stroke-width="3.2" stroke-linejoin="round"/>
  <path d="M72 86 L94 80 L98 106 L76 112 Z" fill="#a7f3d0" stroke="#18181b" stroke-width="3" stroke-linejoin="round"/>
  <path d="M46 82 L44 142 M58 86 L55 144 M68 92 L69 144" stroke="#065f46" stroke-width="2.8" stroke-linecap="round"/>
</svg>
''';

const _wowCloudSvg = '''
<svg viewBox="0 0 170 95" xmlns="http://www.w3.org/2000/svg">
  <path d="M22 68 C10 68, 6 54, 18 48 C16 34, 34 26, 48 34 C58 20, 86 20, 96 34 C112 24, 136 30, 138 46 C154 46, 160 64, 146 72 C136 80, 36 80, 22 68 Z" fill="#ffffff" stroke="#e7e5e4" stroke-width="2"/>
  <path d="M24 68 C45 78, 125 78, 146 69 C136 82, 36 82, 24 68 Z" fill="#d6d3d1" opacity="0.65"/>
</svg>
''';

const _sunburstSvg = '''
<svg viewBox="0 0 120 55" xmlns="http://www.w3.org/2000/svg">
  <path d="M15 42 L60 8 L105 42 Z" fill="#fbbf24" stroke="#ffffff" stroke-width="4" stroke-linejoin="round"/>
  <path d="M28 42 L42 12 L60 42 L78 12 L92 42 Z" fill="#f97316"/>
  <circle cx="60" cy="36" r="14" fill="#fde047"/>
  <rect x="12" y="31" width="96" height="21" rx="5" fill="#ffffff"/>
</svg>
''';
