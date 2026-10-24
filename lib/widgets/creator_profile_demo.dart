import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CreatorProfileDemo extends StatefulWidget {
  const CreatorProfileDemo({super.key});

  @override
  State<CreatorProfileDemo> createState() => _CreatorProfileDemoState();
}

class _CreatorProfileDemoState extends State<CreatorProfileDemo>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 1);
  late final AnimationController _artController;
  Timer? _initialCounterTimer;
  Timer? _followTimer;
  int _selectedTab = 1;
  int _followers = 20543;
  double _scrollProgress = 0;
  bool _following = false;

  static const _instagramItems = [
    _FeedItem('trench', 282, left: true),
    _FeedItem('pines', 385, left: true),
    _FeedItem('archway', 319, left: true),
    _FeedItem('minimalCafe', 412, left: true),
    _FeedItem('columns', 353),
    _FeedItem('laceBlack', 497),
    _FeedItem('knitCurtain', 524),
    _FeedItem('silkMirror', 618),
  ];

  static const _tiktokItems = [
    _FeedItem('puppy', 131400, left: true),
    _FeedItem('elevator', 84200, left: true),
    _FeedItem('coffee', 62900, left: true),
    _FeedItem('adidas', 97600),
    _FeedItem('zaraRed', 215800),
    _FeedItem('balcony', 149100),
  ];

  static const _xItems = [
    _FeedItem(
      'text',
      164,
      left: true,
      text:
          'Autumn capsule wardrobe essentials: oversized trench, crisp white trousers & vintage gold hoops ✨🧥',
      time: '2h ago',
      reposts: 28,
    ),
    _FeedItem('trench', 241, left: true),
    _FeedItem(
      'text',
      118,
      left: true,
      text:
          'New unboxing reel just dropped on TikTok! Honestly obsessed with the retro blue box packaging 👟💙',
      time: '3d ago',
      reposts: 14,
    ),
    _FeedItem('laceBlack', 309),
    _FeedItem(
      'text',
      195,
      text:
          'Golden hour hitting the lace curtains just right before dinner in Milan 🥂✨',
      time: '1d ago',
      reposts: 32,
    ),
    _FeedItem('columns', 276),
  ];

  @override
  void initState() {
    super.initState();
    _artController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _initialCounterTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _followers = 20545);
    });
  }

  @override
  void dispose() {
    _initialCounterTimer?.cancel();
    _followTimer?.cancel();
    _scrollController.dispose();
    _pageController.dispose();
    _artController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 440),
      curve: Curves.easeOutCubic,
    );
  }

  void _rollCounter() {
    setState(() {
      _followers = _followers == 20545 ? 20540 : _followers + 1;
    });
  }

  void _follow() {
    setState(() {
      _followers++;
      _following = true;
    });
    _followTimer?.cancel();
    _followTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _following = false);
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final progress = (notification.metrics.pixels / 152).clamp(0.0, 1.0);
    if ((progress - _scrollProgress).abs() > 0.001) {
      setState(() => _scrollProgress = progress);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFFF5F5F3), Color(0xFFE7E7E4)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              width: math.min(384, size.width),
              height: math.min(790, size.height * 0.94),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 70,
                    offset: Offset(0, 28),
                  ),
                  BoxShadow(color: Color(0x10000000), blurRadius: 18),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final eased =
                        1 - math.pow(1 - _scrollProgress, 1.65).toDouble();
                    return Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _handleScroll,
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: [
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 198),
                              ),
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _TabsHeaderDelegate(
                                  selectedTab: _selectedTab,
                                  onSelected: _selectTab,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 1030,
                                  child: PageView(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() => _selectedTab = index);
                                    },
                                    children: [
                                      _FeedPanel(
                                        items: _tiktokItems,
                                        platform: 0,
                                        artAnimation: _artController,
                                      ),
                                      const _FeedPanel(
                                        items: _instagramItems,
                                        platform: 1,
                                      ),
                                      const _FeedPanel(
                                        items: _xItems,
                                        platform: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          child: Opacity(
                            opacity: ((_scrollProgress - 0.82) / 0.18).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              height: 68,
                              color: const Color(0xF0FFFFFF),
                            ),
                          ),
                        ),
                        Positioned(
                          top: ui.lerpDouble(26, 18, eased),
                          left: ui.lerpDouble(
                            constraints.maxWidth / 2 - 56,
                            22,
                            eased,
                          ),
                          width: ui.lerpDouble(112, 34, eased),
                          height: ui.lerpDouble(112, 34, eased),
                          child: GestureDetector(
                            onTap: _rollCounter,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x10000000),
                                    blurRadius: 16,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const ClipOval(
                                child: CustomPaint(painter: _AvatarPainter()),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: ui.lerpDouble(152, 25, eased),
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Text(
                              '@popelz',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF111111),
                                fontSize: ui.lerpDouble(22, 17, eased),
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 190 - 112 * eased,
                          left: 0,
                          right: 0,
                          child: _FollowersCounter(
                            value: _followers,
                            morphProgress: (_scrollProgress / 0.72).clamp(
                              0.0,
                              1.0,
                            ),
                            onTap: _rollCounter,
                          ),
                        ),
                        Positioned(
                          top: 18,
                          right: 22,
                          child: _CircleButton(
                            onTap: () => _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 92,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xF5FFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 22,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _FollowButton(
                              platform: _selectedTab,
                              following: _following,
                              onTap: _follow,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabsHeaderDelegate({
    required this.selectedTab,
    required this.onSelected,
  });

  final int selectedTab;
  final ValueChanged<int> onSelected;

  @override
  double get minExtent => 114;

  @override
  double get maxExtent => 114;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: const Color(0xFAFFFFFF),
      child: Padding(
        padding: const EdgeInsets.only(top: 68, left: 22, right: 22),
        child: _PlatformTabs(selected: selectedTab, onSelected: onSelected),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedTab != selectedTab;
  }
}

class _PlatformTabs extends StatelessWidget {
  const _PlatformTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEBEBEE)),
          ),
          AnimatedAlign(
            alignment: Alignment(selected - 1, -1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(height: 2, color: const Color(0xFF111111)),
            ),
          ),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: InkWell(
                  key: ValueKey('creator_profile_tab_$index'),
                  onTap: () => onSelected(index),
                  child: Center(
                    child: _PlatformIcon(
                      platform: index,
                      size: index == 2 ? 16 : 18,
                      color: selected == index
                          ? const Color(0xFF111111)
                          : const Color(0xFFC4C4C7),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FollowersCounter extends StatelessWidget {
  const _FollowersCounter({
    required this.value,
    required this.morphProgress,
    required this.onTap,
  });

  final int value;
  final double morphProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final digits = value.toString().padLeft(5, '0');
    final labelProgress = (morphProgress * 1.15).clamp(0.0, 1.0);
    return Column(
      children: [
        GestureDetector(
          onTap: morphProgress > 0.25 ? null : onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(
                0xFFF5F5F7,
              ).withValues(alpha: math.max(0, 1 - morphProgress * 1.45)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final progress = (morphProgress * (0.85 + index * 0.05)).clamp(
                  0.0,
                  1.0,
                );
                final wave = const [1.35, 0.9, 0.65, 0.9, 1.35][index];
                return Opacity(
                  opacity: 1 - math.pow(progress, 1.35).toDouble(),
                  child: Transform.translate(
                    offset: Offset(0, -16 * wave * math.pow(progress, 1.2)),
                    child: Transform.scale(
                      scale: 1 - 0.18 * progress,
                      child: _OdometerDigit(
                        digit: int.parse(digits[index]),
                        index: index,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: 1 - math.pow(labelProgress, 1.2).toDouble(),
          child: Transform.translate(
            offset: Offset(0, -10 * labelProgress),
            child: const Text(
              'total followers count',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ],
    );
  }
}

class _OdometerDigit extends StatelessWidget {
  const _OdometerDigit({required this.digit, required this.index});

  final int digit;
  final int index;

  @override
  Widget build(BuildContext context) {
    final target = index >= 3 && digit <= 5 ? digit + 10 : digit;
    return SizedBox(
      width: 11,
      height: 22,
      child: ClipRect(
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Duration(milliseconds: 550 + index * 60),
              curve: Curves.easeOutCubic,
              top: -target * 22,
              left: 0,
              right: 0,
              child: Column(
                children: List.generate(
                  20,
                  (value) => SizedBox(
                    height: 22,
                    child: Text(
                      '${value % 10}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF18181B),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F4F6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.close, size: 16, color: Color(0xFF18181B)),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.platform,
    required this.following,
    required this.onTap,
  });

  final int platform;
  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Color(0x0A000000)),
      ),
      elevation: 8,
      shadowColor: const Color(0x30000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    following ? 'Following on' : 'Follow on',
                    key: ValueKey(following),
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _PlatformIcon(
                    key: ValueKey(platform),
                    platform: platform,
                    size: 15,
                    color: const Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedPanel extends StatelessWidget {
  const _FeedPanel({
    required this.items,
    required this.platform,
    this.artAnimation,
  });

  final List<_FeedItem> items;
  final int platform;
  final Animation<double>? artAnimation;

  @override
  Widget build(BuildContext context) {
    final left = items.where((item) => item.left).toList();
    final right = items.where((item) => !item.left).toList();
    final leftOffset = platform == 0 ? 0.0 : (platform == 1 ? 40.0 : 22.0);
    final rightOffset = platform == 0 ? 40.0 : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FeedColumn(
              items: left,
              offset: leftOffset,
              platform: platform,
              artAnimation: artAnimation,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _FeedColumn(
              items: right,
              offset: rightOffset,
              platform: platform,
              artAnimation: artAnimation,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn({
    required this.items,
    required this.offset,
    required this.platform,
    this.artAnimation,
  });

  final List<_FeedItem> items;
  final double offset;
  final int platform;
  final Animation<double>? artAnimation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: offset),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: 18),
            _FeedCard(
              key: ValueKey(
                '$platform-${items[index].scene}-${items[index].count}',
              ),
              item: items[index],
              platform: platform,
              artAnimation: artAnimation,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({
    super.key,
    required this.item,
    required this.platform,
    this.artAnimation,
  });

  final _FeedItem item;
  final int platform;
  final Animation<double>? artAnimation;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartController;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    if (widget.platform == 0) return;
    setState(() => _liked = !_liked);
    if (_liked) _heartController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isText = item.scene == 'text';
    final statColor = _liked
        ? const Color(0xFFEF4444)
        : const Color(0xFFB8B8BE);
    return GestureDetector(
      onTap: _toggleLike,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F5),
                border: isText
                    ? Border.all(color: const Color(0xFFF0F0F2))
                    : null,
              ),
              child: Stack(
                children: [
                  if (isText)
                    Container(
                      constraints: const BoxConstraints(minHeight: 168),
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFF8F8FA),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.text!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF27272A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.time!, style: _metaStyle),
                              Text('↻ ${item.reposts}', style: _metaStyle),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: widget.platform == 0 ? 9 / 13.2 : 1 / 1.05,
                      child: widget.artAnimation == null
                          ? CustomPaint(painter: _CreatorArtPainter(item.scene))
                          : AnimatedBuilder(
                              animation: widget.artAnimation!,
                              builder: (context, child) => CustomPaint(
                                painter: _CreatorArtPainter(
                                  item.scene,
                                  time: widget.artAnimation!.value * 12,
                                ),
                              ),
                            ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _heartController,
                        builder: (context, child) {
                          final value = _heartController.value;
                          if (value == 0) return const SizedBox.shrink();
                          return Opacity(
                            opacity: 1 - value,
                            child: Transform.scale(
                              scale: 1.5 * Curves.easeOut.transform(value),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.white,
                                size: 48,
                                shadows: [
                                  Shadow(
                                    color: Color(0x40000000),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.platform == 0 ? Icons.play_arrow : Icons.favorite,
                size: widget.platform == 0 ? 11 : 12,
                color: statColor,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(item.count + (_liked ? 1 : 0)),
                style: TextStyle(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: statColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _metaStyle = TextStyle(fontSize: 11, color: Color(0xFFA1A1AA));

  static String _formatCount(int count) {
    if (count < 1000) return '$count';
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
}

class _FeedItem {
  const _FeedItem(
    this.scene,
    this.count, {
    this.left = false,
    this.text,
    this.time,
    this.reposts,
  });

  final String scene;
  final int count;
  final bool left;
  final String? text;
  final String? time;
  final int? reposts;
}

class _PlatformIcon extends StatelessWidget {
  const _PlatformIcon({
    super.key,
    required this.platform,
    required this.size,
    required this.color,
  });

  final int platform;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlatformIconPainter(platform, color),
    );
  }
}

class _PlatformIconPainter extends CustomPainter {
  const _PlatformIconPainter(this.platform, this.color);

  final int platform;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    if (platform == 0) {
      final path = Path()
        ..moveTo(19.59, 6.69)
        ..cubicTo(17.55, 6.12, 16.1, 4.65, 15.82, 2.44)
        ..lineTo(15.82, 2)
        ..lineTo(12.37, 2)
        ..lineTo(12.37, 15.67)
        ..cubicTo(12.1, 20.2, 6.45, 20.15, 7.17, 17.41)
        ..cubicTo(7.55, 14.8, 9.4, 12.3, 10.36, 12.9)
        ..lineTo(10.36, 9.4)
        ..cubicTo(2.5, 8.2, 1.8, 18.7, 5, 20.1)
        ..cubicTo(8.1, 24, 15.3, 20.8, 15.86, 15.67)
        ..lineTo(15.86, 8.67)
        ..cubicTo(17.5, 9.7, 19, 10.2, 20.63, 10.19)
        ..lineTo(20.63, 6.79)
        ..lineTo(19.59, 6.69);
      canvas.drawPath(path, paint);
    } else if (platform == 1) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2.5, 2.5, 19, 19),
          const Radius.circular(5.5),
        ),
        paint,
      );
      canvas.drawCircle(const Offset(12, 12), 4, paint);
      canvas.drawCircle(const Offset(17.5, 6.5), 0.2, paint);
    } else {
      final path = Path()
        ..moveTo(18.24, 2.25)
        ..lineTo(21.55, 2.25)
        ..lineTo(14.32, 10.51)
        ..lineTo(22.83, 21.75)
        ..lineTo(16.17, 21.75)
        ..lineTo(10.96, 14.93)
        ..lineTo(4.99, 21.75)
        ..lineTo(1.68, 21.75)
        ..lineTo(9.41, 12.92)
        ..lineTo(1.25, 2.25)
        ..lineTo(8.08, 2.25)
        ..lineTo(12.79, 8.48)
        ..close()
        ..moveTo(17.08, 19.77)
        ..lineTo(18.92, 19.77)
        ..lineTo(7.08, 4.13)
        ..lineTo(5.12, 4.13)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PlatformIconPainter oldDelegate) {
    return oldDelegate.platform != platform || oldDelegate.color != color;
  }
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 224, size.height / 224);
    final paint = Paint()..isAntiAlias = true;
    paint.shader = const LinearGradient(
      colors: [Color(0xFFCFC2AE), Color(0xFFDFD4C3), Color(0xFFB8A993)],
    ).createShader(const Rect.fromLTWH(0, 0, 224, 224));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 224, 224), paint);
    paint.shader = null;
    for (var i = 0; i < 7; i++) {
      paint.color = i.isEven
          ? const Color(0x245F4E3A)
          : const Color(0x30FFF8EA);
      canvas.drawRect(Rect.fromLTWH(i * 34, 0, 17, 224), paint);
    }
    paint.color = const Color(0xFF36383B);
    canvas.drawOval(const Rect.fromLTWH(43, 170, 156, 96), paint);
    paint.color = const Color(0xFFE5BAA0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(103, 125, 28, 42),
        const Radius.circular(12),
      ),
      paint,
    );
    paint.color = const Color(0xFFCBB082);
    canvas.drawCircle(const Offset(121, 94), 46, paint);
    paint.color = const Color(0xFFEDC3A8);
    canvas.drawOval(const Rect.fromLTWH(80, 59, 68, 86), paint);
    paint.color = const Color(0xFFD4B47C);
    final leftHair = Path()
      ..moveTo(110, 59)
      ..quadraticBezierTo(76, 63, 79, 109)
      ..quadraticBezierTo(90, 85, 110, 73)
      ..close();
    final rightHair = Path()
      ..moveTo(110, 59)
      ..quadraticBezierTo(150, 61, 150, 115)
      ..quadraticBezierTo(142, 87, 110, 73)
      ..close();
    canvas.drawPath(leftHair, paint);
    canvas.drawPath(rightHair, paint);
    paint.color = const Color(0xFF3B2E25);
    canvas.drawCircle(const Offset(101, 101), 3.2, paint);
    canvas.drawCircle(const Offset(127, 101), 3.2, paint);
    paint.color = const Color(0xFFC47468);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.8;
    paint.strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(106, 125)
        ..quadraticBezierTo(114, 129, 123, 124),
      paint,
    );
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFFF2CCB4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(76, 130, 28, 18),
        const Radius.circular(9),
      ),
      paint,
    );
    paint.color = const Color(0xFF3F4145);
    canvas.drawPath(
      Path()
        ..moveTo(63, 224)
        ..lineTo(81, 143)
        ..lineTo(110, 150)
        ..lineTo(101, 224)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) => false;
}

class _CreatorArtPainter extends CustomPainter {
  const _CreatorArtPainter(this.scene, {this.time = 0});

  final String scene;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final height =
        const {
          'puppy',
          'adidas',
          'elevator',
          'zaraRed',
          'coffee',
          'balcony',
        }.contains(scene)
        ? 460.0
        : 336.0;
    canvas.scale(size.width / 320, size.height / height);
    final paint = Paint()..isAntiAlias = true;
    switch (scene) {
      case 'trench':
        _gradient(canvas, paint, const [
          Color(0xFFEEF1EB),
          Color(0xFFCFD6C8),
        ], 336);
        for (var i = 0; i < 28; i++) {
          paint.color = const [
            Color(0xFF3C5A35),
            Color(0xFF4F7144),
            Color(0xFF688B58),
            Color(0xFF2D4628),
          ][i % 4];
          canvas.drawCircle(
            Offset((i * 37) % 320, 40 + (i * 53) % 218),
            24 + (i % 18),
            paint,
          );
        }
        paint.color = const Color(0xFFCBB79C);
        canvas.drawPath(
          Path()
            ..moveTo(51, 336)
            ..quadraticBezierTo(70, 175, 166, 175)
            ..quadraticBezierTo(262, 175, 282, 336)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFF3B3C36);
        canvas.drawPath(
          Path()
            ..moveTo(134, 178)
            ..lineTo(198, 178)
            ..lineTo(176, 336)
            ..lineTo(144, 336)
            ..close(),
          paint,
        );
        _personHead(
          canvas,
          paint,
          166,
          128,
          hair: const Color(0xFFE5CFA3),
          radius: 48,
        );
        paint.color = const Color(0xFF18181B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(131, 111, 22, 13),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(170, 111, 22, 13),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawRect(const Rect.fromLTWH(131, 114, 61, 3), paint);
      case 'columns':
        _gradient(canvas, paint, const [
          Color(0xFFF2F0EC),
          Color(0xFFDCDAD5),
        ], 336);
        paint.color = const Color(0xFF25282A);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(104, 65, 112, 190),
            const Radius.circular(56),
          ),
          paint,
        );
        paint.color = const Color(0xFFE5E3DE);
        canvas.drawRect(const Rect.fromLTWH(24, 0, 28, 255), paint);
        canvas.drawRect(const Rect.fromLTWH(268, 0, 28, 255), paint);
        paint.color = const Color(0xFF9CA0A3);
        canvas.drawRect(const Rect.fromLTWH(0, 255, 320, 81), paint);
        paint.color = const Color(0xFFFAFAFA);
        canvas.drawPath(
          Path()
            ..moveTo(141, 175)
            ..lineTo(186, 175)
            ..lineTo(205, 309)
            ..lineTo(170, 309)
            ..lineTo(163, 222)
            ..lineTo(147, 309)
            ..lineTo(115, 309)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFF18181B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(122, 98, 76, 82),
            const Radius.circular(12),
          ),
          paint,
        );
        _personHead(
          canvas,
          paint,
          160,
          77,
          hair: const Color(0xFFE2C792),
          radius: 20,
        );
      case 'pines':
        paint.color = const Color(0xFF243523);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 336), paint);
        for (var i = 0; i < 45; i++) {
          final x = (i * 43) % 320.0;
          final y = (i * 29) % 286.0;
          paint.color = const [
            Color(0xFF1B2B1A),
            Color(0xFF2E462C),
            Color(0xFF3D5C38),
            Color(0xFF4F6F46),
          ][i % 4];
          canvas.drawPath(
            Path()
              ..moveTo(x, y - 28)
              ..lineTo(x - 24, y + 20)
              ..lineTo(x + 24, y + 20)
              ..close(),
            paint,
          );
        }
        paint.color = const Color(0x8CFFE6A0);
        for (var i = 0; i < 14; i++) {
          canvas.drawCircle(
            Offset(30 + (i * 67) % 260, 30 + (i * 47) % 218),
            3.5,
            paint,
          );
        }
        paint.color = const Color(0xFF73767A);
        canvas.drawRect(const Rect.fromLTWH(0, 282, 320, 54), paint);
        paint.color = const Color(0xFFF8F8FA);
        canvas.drawRect(const Rect.fromLTWH(138, 208, 18, 72), paint);
        canvas.drawRect(const Rect.fromLTWH(163, 208, 18, 72), paint);
        paint.color = const Color(0xFF161618);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(125, 121, 68, 92),
            const Radius.circular(10),
          ),
          paint,
        );
        _personHead(
          canvas,
          paint,
          160,
          104,
          hair: const Color(0xFFE5CC99),
          radius: 19,
        );
      case 'laceBlack':
        _gradient(canvas, paint, const [
          Color(0xFFE5DCCB),
          Color(0xFFF3ECE0),
          Color(0xFFCFC2AD),
        ], 336);
        for (var x = 0; x < 320; x += 22) {
          paint.color = x % 44 == 0
              ? const Color(0x59FFFFFF)
              : const Color(0x1FA08C73);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), 0, 12, 336), paint);
        }
        paint.color = const Color(0xFF1B191A);
        canvas.drawPath(
          Path()
            ..moveTo(134, 141)
            ..quadraticBezierTo(208, 148, 205, 336)
            ..lineTo(112, 336)
            ..quadraticBezierTo(115, 218, 134, 141)
            ..close(),
          paint,
        );
        _personHead(
          canvas,
          paint,
          151,
          94,
          hair: const Color(0xFFD8BC88),
          radius: 24,
        );
      case 'archway':
        paint.color = const Color(0xFFD8D3C8);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 336), paint);
        paint.color = const Color(0xFF2D322C);
        canvas.drawPath(
          Path()
            ..addArc(const Rect.fromLTWH(65, 80, 190, 190), math.pi, math.pi)
            ..lineTo(255, 336)
            ..lineTo(65, 336)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFF5C7457);
        canvas.drawArc(
          const Rect.fromLTWH(82, 97, 156, 156),
          math.pi,
          math.pi,
          true,
          paint,
        );
        paint.color = const Color(0xFFE5E0D5);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 6;
        canvas.drawLine(const Offset(160, 67), const Offset(160, 336), paint);
        canvas.drawLine(const Offset(64, 175), const Offset(256, 175), paint);
      case 'puppy':
        _gradient(canvas, paint, const [
          Color(0xFFC6BAA9),
          Color(0xFFE8E4DF),
          Color(0xFFF7F6F4),
        ], 460);
        paint.color = Colors.white;
        canvas.drawOval(const Rect.fromLTWH(-48, 285, 416, 258), paint);
        final bob = math.sin(time * 2.8) * 5;
        paint.color = const Color(0xFF0284C7);
        for (var i = -2; i <= 2; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(90 + i * 16, 273 + bob),
              width: 28,
              height: 36,
            ),
            paint,
          );
        }
        paint.color = const Color(0xFF0EA5E9);
        canvas.drawCircle(Offset(90, 225 + bob), 50, paint);
        paint.color = const Color(0xFF0F172A);
        canvas.drawCircle(Offset(74, 231 + bob), 5.5, paint);
        canvas.drawCircle(Offset(104, 229 + bob), 5.5, paint);
        final puppyY = 258 + math.cos(time * 2.4) * 3;
        paint.color = const Color(0xFFC89D74);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(182, puppyY + 8),
            width: 48,
            height: 84,
          ),
          paint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(276, puppyY + 8),
            width: 48,
            height: 84,
          ),
          paint,
        );
        paint.color = const Color(0xFFE5C5A3);
        canvas.drawCircle(Offset(230, puppyY), 52, paint);
        canvas.drawCircle(Offset(208, puppyY - 26), 30, paint);
        canvas.drawCircle(Offset(252, puppyY - 26), 30, paint);
        paint.color = const Color(0xFFF0DAC2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(226, puppyY + 16),
            width: 56,
            height: 44,
          ),
          paint,
        );
        paint.color = const Color(0xFF1C1917);
        canvas.drawCircle(Offset(210, puppyY - 4), 6.5, paint);
        canvas.drawCircle(Offset(246, puppyY - 4), 6.5, paint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(228, puppyY + 12),
            width: 18,
            height: 14,
          ),
          paint,
        );
      case 'adidas':
        paint.color = const Color(0xFFD6D1C7);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 460), paint);
        paint.color = const Color(0xFFC49A6C);
        canvas.drawPath(
          Path()
            ..moveTo(20, 30)
            ..lineTo(310, 15)
            ..lineTo(300, 195)
            ..lineTo(15, 175)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFFF5F5F4);
        canvas.drawPath(
          Path()
            ..moveTo(28, 170)
            ..lineTo(298, 145)
            ..lineTo(305, 310)
            ..lineTo(18, 285)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFF18181B);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(95, 201 - math.sin(time) * 8, 130, 52),
            const Radius.circular(18),
          ),
          paint,
        );
        paint.color = const Color(0xFF0284C7);
        canvas.drawPath(
          Path()
            ..moveTo(12, 235)
            ..lineTo(218, 340)
            ..lineTo(320, 290)
            ..lineTo(320, 430)
            ..lineTo(198, 455)
            ..lineTo(12, 325)
            ..close(),
          paint,
        );
        paint.color = Colors.white;
        for (var i = 0; i < 3; i++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(92 + i * 22, 292 + i * 10, 12, 68),
              const Radius.circular(3),
            ),
            paint,
          );
        }
        paint.color = const Color(0xFFEABBA0);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(250 + math.sin(time) * 12, 240),
            width: 96,
            height: 44,
          ),
          paint,
        );
      case 'elevator':
        paint.color = const Color(0xFFD5D0C8);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 460), paint);
        paint.color = const Color(0xFFBDB7AE);
        canvas.drawRect(const Rect.fromLTWH(70, 40, 180, 345), paint);
        paint.color = const Color(0xFF8C857B);
        canvas.drawRect(const Rect.fromLTWH(109, 75, 102, 299), paint);
        final sway = math.sin(time * 2.6) * 6;
        paint.color = const Color(0xFFE0B194);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(120 + sway, 237, 68, 76),
            const Radius.circular(20),
          ),
          paint,
        );
        paint.color = const Color(0xFFF8FAFC);
        canvas.drawPath(
          Path()
            ..moveTo(122 + sway, 303)
            ..lineTo(186 + sway, 303)
            ..lineTo(202 + sway, 460)
            ..lineTo(106 + sway, 460)
            ..close(),
          paint,
        );
        paint.color = const Color(0xFFE2C690);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(154 + sway, 217),
            width: 56,
            height: 72,
          ),
          paint,
        );
      case 'zaraRed':
        if (math.sin(time * 1.35) < -0.24) {
          paint.color = const Color(0xFFE5E2DC);
          canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 460), paint);
          paint.color = const Color(0xFF27272A);
          canvas.drawRect(const Rect.fromLTWH(24, 150, 272, 240), paint);
          _text(
            canvas,
            'ZARA',
            const Offset(160, 118),
            44,
            const Color(0xFF18181B),
          );
        } else {
          paint.color = const Color(0xFFECE7DF);
          canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 460), paint);
          paint.color = const Color(0xFFE3B598);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(90, 35, 140, 70),
              const Radius.circular(24),
            ),
            paint,
          );
          paint.color = const Color(0xFFB91C1C);
          final sway = math.sin(time * 3.2) * 10;
          canvas.drawPath(
            Path()
              ..moveTo(134, 35)
              ..lineTo(186, 35)
              ..lineTo(230, 160)
              ..lineTo(282 + sway, 460)
              ..lineTo(45 + sway, 460)
              ..lineTo(90, 160)
              ..close(),
            paint,
          );
          paint.color = const Color(0x47FF7878);
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 3;
          for (var i = -2; i <= 2; i++) {
            canvas.drawLine(
              Offset(160 + i * 12, 95),
              Offset(160 + i * 34 + sway, 460),
              paint,
            );
          }
        }
      case 'coffee':
        _gradient(canvas, paint, const [
          Color(0xFFE7E2D8),
          Color(0xFFC8BFAF),
        ], 460);
        paint.color = const Color(0xFFF7F4EC);
        canvas.drawOval(const Rect.fromLTWH(55, 305, 210, 65), paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(92, 135, 136, 190),
            const Radius.circular(25),
          ),
          paint,
        );
        paint.color = const Color(0xFF658354);
        canvas.drawOval(
          Rect.fromLTWH(96, 137 + math.sin(time * 2) * 3, 128, 50),
          paint,
        );
        paint.color = const Color(0xFFA7BE91);
        canvas.drawCircle(const Offset(160, 160), 25, paint);
      case 'balcony':
        _gradient(canvas, paint, const [
          Color(0xFFF2D2AE),
          Color(0xFFB8A48C),
        ], 460);
        paint.color = const Color(0xFF8D7564);
        for (var i = 0; i < 7; i++) {
          canvas.drawRect(
            Rect.fromLTWH(i * 52.0, 170 + (i % 3) * 25, 42, 210),
            paint,
          );
        }
        paint.color = const Color(0xFF4B4240);
        canvas.drawRect(const Rect.fromLTWH(0, 310, 320, 12), paint);
        for (var i = 0; i < 8; i++) {
          canvas.drawRect(Rect.fromLTWH(i * 46.0, 315, 7, 145), paint);
        }
        paint.color = const Color(0xFF1F2937);
        canvas.drawPath(
          Path()
            ..moveTo(125, 210)
            ..lineTo(195, 210)
            ..lineTo(230 + math.sin(time * 2) * 5, 460)
            ..lineTo(90, 460)
            ..close(),
          paint,
        );
        _personHead(
          canvas,
          paint,
          160,
          180,
          hair: const Color(0xFFDEC392),
          radius: 32,
        );
      default:
        _gradient(canvas, paint, const [
          Color(0xFFE8DFD1),
          Color(0xFFCBBBA4),
        ], 336);
        for (var x = 0; x < 320; x += 26) {
          paint.color = const Color(0x47FFFFFF);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), 0, 13, 336), paint);
        }
        paint.color = scene == 'minimalCafe'
            ? const Color(0xFFD8C5AC)
            : const Color(0xFF2A2627);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(102, 155, 115, 190),
            const Radius.circular(28),
          ),
          paint,
        );
        _personHead(
          canvas,
          paint,
          160,
          118,
          hair: const Color(0xFFDEC392),
          radius: 32,
        );
    }
  }

  static void _gradient(
    Canvas canvas,
    Paint paint,
    List<Color> colors,
    double height,
  ) {
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(Rect.fromLTWH(0, 0, 320, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 320, height), paint);
    paint.shader = null;
  }

  static void _personHead(
    Canvas canvas,
    Paint paint,
    double x,
    double y, {
    required Color hair,
    required double radius,
  }) {
    paint.style = PaintingStyle.fill;
    paint.color = hair;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: radius * 2,
        height: radius * 2.7,
      ),
      paint,
    );
    paint.color = const Color(0xFFF2CEB6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y - radius * 0.15),
        width: radius * 1.15,
        height: radius * 1.45,
      ),
      paint,
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CreatorArtPainter oldDelegate) {
    return oldDelegate.scene != scene || oldDelegate.time != time;
  }
}
