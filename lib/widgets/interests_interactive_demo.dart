import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InterestsInteractiveDemo extends StatefulWidget {
  const InterestsInteractiveDemo({super.key});

  @override
  State<InterestsInteractiveDemo> createState() =>
      _InterestsInteractiveDemoState();
}

class _InterestsInteractiveDemoState extends State<InterestsInteractiveDemo>
    with TickerProviderStateMixin {
  final _stageKey = GlobalKey();
  final _counterKey = GlobalKey();
  final _selectedIds = <String>{'camping'};

  late final AnimationController _burstController;
  late final AnimationController _counterController;

  _Interest? _burstItem;
  Offset _burstOrigin = Offset.zero;
  Offset _burstDestination = Offset.zero;
  Size _burstStageSize = Size.zero;
  int _displayedCount = 1;
  bool _showLeftMask = false;
  bool _showRightMask = true;

  static const _rows = [
    [
      _Interest('roadtrip', 'Roadtrip', '🚙'),
      _Interest('football', 'Football', '⚽'),
      _Interest('music', 'Music', '🎵'),
      _Interest('painting', 'Painting', '🎨'),
      _Interest('cooking', 'Cooking', '🍳'),
      _Interest('running', 'Running', '🏃'),
      _Interest('meditation', 'Meditation', '🧘‍♀️'),
      _Interest('guitar', 'Guitar', '🎸'),
      _Interest('climbing', 'Climbing', '🧗'),
      _Interest('cycling', 'Cycling', '🚴'),
      _Interest('tech', 'Tech', '📱'),
    ],
    [
      _Interest('pets', 'Pets', '🐶'),
      _Interest('camping', 'Camping', '⛺'),
      _Interest('beach', 'Beach', '🏖️'),
      _Interest('travel', 'Travel', '🚂'),
      _Interest('dancing', 'Dancing', '💃'),
      _Interest('museums', 'Museums', '🏛️', _museumSvg),
      _Interest('crafting', 'Crafting', '🧵'),
      _Interest('flying', 'Flying', '✈️'),
      _Interest('darts', 'Darts', '🎯'),
      _Interest('bubbletea', 'Bubbletea', '🧋', _bubbleTeaSvg),
      _Interest('drawing', 'Drawing', '🖌️'),
      _Interest('plants', 'Plants', '🪴'),
    ],
    [
      _Interest('baking', 'Baking', '🎂'),
      _Interest('hiking', 'Hiking', '🥾'),
      _Interest('piano', 'Piano', '🎹'),
      _Interest('drums', 'Drums', '🥁'),
      _Interest('blogging', 'Blogging', '✍️'),
      _Interest('arcade', 'Arcade', '🕹️'),
      _Interest('kites', 'Kites', '🪁', _kiteSvg),
      _Interest('concerts', 'Concerts', '🎟️'),
      _Interest('pizza', 'Pizza', '🍕'),
      _Interest('festivals', 'Festivals', '🥣'),
      _Interest('boardgames', 'Boardgames', '🎲', _boardGamesSvg),
      _Interest('yoga', 'Yoga', '🧘'),
    ],
    [
      _Interest('journaling', 'Journaling', '📓'),
      _Interest('carnivals', 'Carnivals', '🎡'),
      _Interest('pottery', 'Pottery', '🏺'),
      _Interest('nature', 'Nature', '🌿'),
      _Interest('shopping', 'Shopping', '🛒'),
      _Interest('knitting', 'Knitting', '🧶'),
      _Interest('desserts', 'Desserts', '🍰'),
      _Interest('score', 'Score', '🎼'),
      _Interest('coloring', 'Coloring', '🖍️'),
      _Interest('drones', 'Drones', '🚁'),
      _Interest('radios', 'Radios', '📡'),
      _Interest('sketching', 'Sketching', '🎨'),
    ],
    [
      _Interest('snowboarding', 'Snowboarding', '🏂'),
      _Interest('trekking', 'Trekking', '🎒'),
      _Interest('walking', 'Walking', '🚶'),
      _Interest('organizing', 'Organizing', '🗂️'),
      _Interest('telescopes', 'Telescopes', '🔭'),
      _Interest('science', 'Science', '🔬'),
      _Interest('music_theory', 'Music', '🎼'),
      _Interest('filmmaking', 'Filmmaking', '🎥'),
      _Interest('calligraphy', 'Calligraphy', '🎨'),
      _Interest('sunsets', 'Sunsets', '🌄'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1380),
    );
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _burstController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  void _toggleInterest(_Interest item, BuildContext pillContext) {
    if (_selectedIds.contains(item.id)) {
      setState(() => _selectedIds.remove(item.id));
      _animateCounter();
      return;
    }

    final stageBox = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final pillBox = pillContext.findRenderObject() as RenderBox?;
    final counterBox =
        _counterKey.currentContext?.findRenderObject() as RenderBox?;
    if (stageBox == null || pillBox == null || counterBox == null) return;

    setState(() {
      _selectedIds.add(item.id);
      _burstItem = item;
      _burstStageSize = stageBox.size;
      _burstOrigin = stageBox.globalToLocal(
        pillBox.localToGlobal(
          Offset(pillBox.size.width * 0.35, pillBox.size.height * 0.5),
        ),
      );
      _burstDestination = stageBox.globalToLocal(
        counterBox.localToGlobal(
          Offset(counterBox.size.width * 0.46, counterBox.size.height * 0.38),
        ),
      );
    });
    _burstController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1120), () {
      if (mounted) _animateCounter();
    });
  }

  void _animateCounter() {
    if (_displayedCount == _selectedIds.length) return;
    setState(() => _displayedCount = _selectedIds.length);
    _counterController.forward(from: 0);
  }

  bool _updateMasks(ScrollNotification notification) {
    final position = notification.metrics;
    final showLeft = position.pixels > 6;
    final showRight = position.pixels < position.maxScrollExtent - 6;
    if (showLeft != _showLeftMask || showRight != _showRightMask) {
      setState(() {
        _showLeftMask = showLeft;
        _showRightMask = showRight;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 36),
          child: ClipRect(
            child: Stack(
              key: _stageKey,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 34),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Interests',
                          style: TextStyle(
                            color: Color(0xFF202022),
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Stack(
                      children: [
                        NotificationListener<ScrollNotification>(
                          onNotification: _updateMasks,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(34, 8, 34, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < _rows.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      for (
                                        var j = 0;
                                        j < _rows[i].length;
                                        j++
                                      ) ...[
                                        if (j > 0) const SizedBox(width: 12),
                                        _InterestPill(
                                          item: _rows[i][j],
                                          selected: _selectedIds.contains(
                                            _rows[i][j].id,
                                          ),
                                          onTap: _toggleInterest,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _EdgeMask(
                          visible: _showLeftMask,
                          alignment: Alignment.centerLeft,
                          colors: const [Color(0xF5FFFFFF), Color(0x00FFFFFF)],
                        ),
                        _EdgeMask(
                          visible: _showRightMask,
                          alignment: Alignment.centerRight,
                          colors: const [Color(0x00FFFFFF), Color(0xF5FFFFFF)],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _CounterPill(
                      key: _counterKey,
                      count: _displayedCount,
                      animation: _counterController,
                    ),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _burstController,
                      builder: (context, child) {
                        final t = _burstController.value;
                        final opacity = t < 0.25
                            ? Curves.easeOut.transform(t / 0.25)
                            : t < 0.7
                            ? 1.0
                            : 1 -
                                  Curves.easeIn.transform(
                                    ((t - 0.7) / 0.3).clamp(0.0, 1.0),
                                  );
                        return Opacity(
                          opacity: _burstController.isAnimating ? opacity : 0,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -0.04),
                                radius: 0.85,
                                colors: [
                                  Color(0xBFFFFFFF),
                                  Color(0x7AFFFFFF),
                                  Color(0x00FFFFFF),
                                ],
                                stops: [0, 0.58, 1],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_burstItem != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _burstController,
                        builder: (context, child) {
                          if (!_burstController.isAnimating) {
                            return const SizedBox.shrink();
                          }
                          return Stack(
                            children: [
                              for (var i = 0; i < 3; i++)
                                _FlyingIcon(
                                  item: _burstItem!,
                                  index: i,
                                  progress: _burstController.value,
                                  origin: _burstOrigin,
                                  destination: _burstDestination,
                                  size: _burstStageSize,
                                ),
                            ],
                          );
                        },
                      ),
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

class _InterestPill extends StatefulWidget {
  const _InterestPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Interest item;
  final bool selected;
  final void Function(_Interest item, BuildContext context) onTap;

  @override
  State<_InterestPill> createState() => _InterestPillState();
}

class _InterestPillState extends State<_InterestPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => widget.onTap(widget.item, context),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 20),
          decoration: BoxDecoration(
            color: widget.selected ? Colors.white : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              width: 1.5,
              color: widget.selected
                  ? const Color(0xFFD8DADF)
                  : Colors.transparent,
            ),
            boxShadow: widget.selected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InterestIcon(item: widget.item, size: 24),
              const SizedBox(width: 9),
              Text(
                widget.item.label,
                style: const TextStyle(
                  color: Color(0xFF222224),
                  fontSize: 17.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestIcon extends StatelessWidget {
  const _InterestIcon({required this.item, required this.size});

  final _Interest item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final svg = item.svg;
    if (svg != null) {
      return SvgPicture.string(
        svg,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          item.emoji,
          style: TextStyle(fontSize: size * 0.875, height: 1),
        ),
      ),
    );
  }
}

class _EdgeMask extends StatelessWidget {
  const _EdgeMask({
    required this.visible,
    required this.alignment,
    required this.colors,
  });

  final bool visible;
  final Alignment alignment;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({super.key, required this.count, required this.animation});

  final int count;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final scaleX = t < 0.35
            ? 1 + 0.07 * (t / 0.35)
            : t < 0.7
            ? 1.07 - 0.09 * ((t - 0.35) / 0.35)
            : 0.98 + 0.02 * ((t - 0.7) / 0.3);
        final scaleY = t < 0.35
            ? 1 - 0.05 * (t / 0.35)
            : t < 0.7
            ? 0.95 + 0.07 * ((t - 0.35) / 0.35)
            : 1.02 - 0.02 * ((t - 0.7) / 0.3);
        return Transform.scale(scaleX: scaleX, scaleY: scaleY, child: child);
      },
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x0D000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1C000000),
              blurRadius: 28,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 480),
                switchInCurve: const Cubic(0.22, 1, 0.36, 1),
                switchOutCurve: const Cubic(0.22, 1, 0.36, 1),
                transitionBuilder: (child, animation) {
                  final isNew = (child as Text).data == '$count';
                  return ClipRect(
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: isNew ? const Offset(0, 1) : const Offset(0, -1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$count',
                  key: ValueKey(count),
                  style: const TextStyle(
                    color: Color(0xFF48484C),
                    fontSize: 18.5,
                    fontWeight: FontWeight.w600,
                    height: 26 / 18.5,
                    fontFeatures: [],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Interests',
              style: TextStyle(
                color: Color(0xFF48484C),
                fontSize: 18.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlyingIcon extends StatelessWidget {
  const _FlyingIcon({
    required this.item,
    required this.index,
    required this.progress,
    required this.origin,
    required this.destination,
    required this.size,
  });

  final _Interest item;
  final int index;
  final double progress;
  final Offset origin;
  final Offset destination;
  final Size size;

  static const _configs = [
    (Offset(-8, -44), -8.0, -16.0, 1.06, 0.0),
    (Offset(-66, 34), -22.0, -28.0, 0.94, 0.033),
    (Offset(64, 20), 16.0, 12.0, 1.0, 0.065),
  ];

  @override
  Widget build(BuildContext context) {
    final config = _configs[index];
    final t = ((progress - config.$5) / (1 - config.$5)).clamp(0.0, 1.0);
    final cluster = Offset(size.width * 0.48, size.height * 0.48) + config.$1;
    final swoop = Offset(
      cluster.dx + (destination.dx - cluster.dx) * 0.65,
      cluster.dy + (destination.dy - cluster.dy) * 0.58,
    );

    late Offset position;
    late double scale;
    late double opacity;
    if (t < 0.28) {
      final p = Curves.easeOutBack.transform(t / 0.28);
      position = Offset.lerp(origin, cluster, p)!;
      scale = 0.18 + (config.$4 * 1.04 - 0.18) * p;
      opacity = (t / 0.12).clamp(0.0, 1.0);
    } else if (t < 0.62) {
      final p = (t - 0.28) / 0.34;
      position = cluster - Offset(0, 6 * p);
      scale = config.$4 * (1.04 - 0.04 * p);
      opacity = 1;
    } else if (t < 0.84) {
      final p = Curves.easeInOut.transform((t - 0.62) / 0.22);
      position = Offset.lerp(cluster - const Offset(0, 6), swoop, p)!;
      scale = config.$4 + (0.56 - config.$4) * p;
      opacity = 1 - 0.05 * p;
    } else {
      final p = Curves.easeIn.transform(((t - 0.84) / 0.16).clamp(0.0, 1.0));
      position = Offset.lerp(swoop, destination, p)!;
      scale = 0.56 - 0.4 * p;
      opacity = 0.95 * (1 - p);
    }

    final rotation =
        (config.$2 + (config.$3 - config.$2) * t) * 3.141592653589793 / 180;
    return Positioned(
      left: position.dx - 61,
      top: position.dy - 61,
      width: 122,
      height: 122,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 24,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: _InterestIcon(item: item, size: 112),
            ),
          ),
        ),
      ),
    );
  }
}

class _Interest {
  const _Interest(this.id, this.label, this.emoji, [this.svg]);

  final String id;
  final String label;
  final String emoji;
  final String? svg;
}

const _kiteSvg = '''
<svg viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="kiteTL" x1="20" y1="15" x2="60" y2="55" gradientUnits="userSpaceOnUse"><stop stop-color="#8F79FF"/><stop offset="1" stop-color="#6046F5"/></linearGradient>
<linearGradient id="kiteTR" x1="60" y1="15" x2="98" y2="55" gradientUnits="userSpaceOnUse"><stop stop-color="#6E58FA"/><stop offset="1" stop-color="#4832D8"/></linearGradient>
<linearGradient id="kiteBL" x1="25" y1="50" x2="60" y2="95" gradientUnits="userSpaceOnUse"><stop stop-color="#7660FC"/><stop offset="1" stop-color="#533CE6"/></linearGradient>
<linearGradient id="kiteBR" x1="60" y1="50" x2="95" y2="95" gradientUnits="userSpaceOnUse"><stop stop-color="#5842E3"/><stop offset="1" stop-color="#3C25C4"/></linearGradient>
<linearGradient id="ribbonGrad" x1="20" y1="75" x2="80" y2="118" gradientUnits="userSpaceOnUse"><stop stop-color="#5094FF"/><stop offset="1" stop-color="#2563EB"/></linearGradient>
</defs>
<path d="M56 89 C46 101 24 96 18 110 C14 117 28 118 36 112" stroke="url(#ribbonGrad)" stroke-width="5.5" stroke-linecap="round"/>
<path d="M40 94 L32 88 L35 99 Z" fill="#60A5FA"/><path d="M40 94 L48 100 L44 89 Z" fill="#3B82F6"/>
<path d="M25 103 L17 98 L20 108 Z" fill="#60A5FA"/><path d="M25 103 L33 108 L30 98 Z" fill="#3B82F6"/>
<path d="M62 10 L22 44 L60 50 Z" fill="url(#kiteTL)"/><path d="M62 10 L98 48 L60 50 Z" fill="url(#kiteTR)"/>
<path d="M22 44 L56 91 L60 50 Z" fill="url(#kiteBL)"/><path d="M98 48 L56 91 L60 50 Z" fill="url(#kiteBR)"/>
<path d="M62 10 L56 91" stroke="#68A8FF" stroke-width="3.5" stroke-linecap="round"/>
<path d="M22 44 Q60 32 98 48" stroke="#76B2FF" stroke-width="3.5" stroke-linecap="round"/>
<circle cx="60" cy="40" r="3" fill="#B8D8FF"/>
</svg>''';

const _museumSvg = '''
<svg viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="roofTop" x1="60" y1="14" x2="60" y2="45" gradientUnits="userSpaceOnUse"><stop stop-color="#D9D3C7"/><stop offset="1" stop-color="#B5ADA0"/></linearGradient>
<linearGradient id="colGrad" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#EFECE6"/><stop offset=".55" stop-color="#D8D2C5"/><stop offset="1" stop-color="#ACA495"/></linearGradient>
<linearGradient id="innerWall" x1="60" y1="48" x2="60" y2="92" gradientUnits="userSpaceOnUse"><stop stop-color="#5B554C"/><stop offset="1" stop-color="#3E3A33"/></linearGradient>
</defs>
<rect x="24" y="46" width="72" height="46" fill="url(#innerWall)"/>
<path d="M60 14 L106 42 L14 42 Z" fill="url(#roofTop)" stroke="#9E9587" stroke-width="1.5" stroke-linejoin="round"/>
<path d="M60 21 L93 38 L27 38 Z" fill="#9A9183"/><path d="M60 23 L90 38 L30 38 Z" fill="#C7C0B3"/>
<rect x="16" y="42" width="88" height="7" rx="2" fill="#DFD9CE" stroke="#ABA293"/>
<g><rect x="23" y="49" width="12" height="4" rx="1.5" fill="#E5E0D5"/><rect x="25" y="53" width="8" height="35" fill="url(#colGrad)"/><rect x="23" y="88" width="12" height="4" rx="1.5" fill="#E5E0D5"/>
<rect x="43" y="49" width="12" height="4" rx="1.5" fill="#E5E0D5"/><rect x="45" y="53" width="8" height="35" fill="url(#colGrad)"/><rect x="43" y="88" width="12" height="4" rx="1.5" fill="#E5E0D5"/>
<rect x="65" y="49" width="12" height="4" rx="1.5" fill="#E5E0D5"/><rect x="67" y="53" width="8" height="35" fill="url(#colGrad)"/><rect x="65" y="88" width="12" height="4" rx="1.5" fill="#E5E0D5"/>
<rect x="85" y="49" width="12" height="4" rx="1.5" fill="#E5E0D5"/><rect x="87" y="53" width="8" height="35" fill="url(#colGrad)"/><rect x="85" y="88" width="12" height="4" rx="1.5" fill="#E5E0D5"/></g>
<rect x="16" y="92" width="88" height="6" rx="2" fill="#D8D2C7" stroke="#A89F91"/><rect x="11" y="98" width="98" height="7" rx="2.5" fill="#C5BEB1" stroke="#999082"/>
</svg>''';

const _bubbleTeaSvg = '''
<svg viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="teaGrad" x1="32" y1="45" x2="88" y2="106" gradientUnits="userSpaceOnUse"><stop stop-color="#F3D6B3"/><stop offset=".55" stop-color="#DFAF7E"/><stop offset="1" stop-color="#C68B59"/></linearGradient>
<linearGradient id="strawGrad" x1="50" y1="8" x2="68" y2="90" gradientUnits="userSpaceOnUse"><stop stop-color="#8D5B4C"/><stop offset=".5" stop-color="#6E4235"/><stop offset="1" stop-color="#4E2C22"/></linearGradient>
<linearGradient id="domeGrad" x1="30" y1="24" x2="90" y2="48" gradientUnits="userSpaceOnUse"><stop stop-color="#FFFFFF" stop-opacity=".85"/><stop offset=".5" stop-color="#E5EEF7" stop-opacity=".45"/><stop offset="1" stop-color="#C7D6E6" stop-opacity=".65"/></linearGradient>
</defs>
<path d="M67 10 L55 96" stroke="url(#strawGrad)" stroke-width="10" stroke-linecap="round"/><ellipse cx="67" cy="10" rx="5" ry="2.2" transform="rotate(8 67 10)" fill="#3B2119"/>
<path d="M30 46 C30 22 90 22 90 46 Z" fill="url(#domeGrad)" stroke="#CBD5E1" stroke-width="2"/>
<path d="M32 46 L40 103 C40.6 107 44 110 48 110 L72 110 C76 110 79.4 107 80 103 L88 46 Z" fill="url(#teaGrad)" stroke="#E2E8F0" stroke-width="2"/>
<ellipse cx="60" cy="52" rx="26" ry="4.5" fill="#FBE8D0"/>
<g fill="#2B1810"><circle cx="46" cy="99" r="5.2"/><circle cx="58" cy="101" r="5.5"/><circle cx="71" cy="99" r="5.2"/><circle cx="51" cy="89" r="5"/><circle cx="64" cy="90" r="5.3"/><circle cx="74" cy="88" r="4.6"/><circle cx="44" cy="88" r="4.4"/></g>
<g fill="#7C5849" opacity=".7"><circle cx="44.5" cy="97.5" r="1.6"/><circle cx="56.5" cy="99.5" r="1.6"/><circle cx="69.5" cy="97.5" r="1.6"/><circle cx="49.5" cy="87.5" r="1.5"/><circle cx="62.5" cy="88.5" r="1.5"/></g>
<rect x="27" y="43" width="66" height="6" rx="3" fill="#F1F5F9" stroke="#CBD5E1" stroke-width="1.5"/><path d="M37 53 L43 98" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" opacity=".55"/>
</svg>''';

const _boardGamesSvg = '''
<svg viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
<defs>
<linearGradient id="dieTop" x1="20" y1="16" x2="95" y2="55" gradientUnits="userSpaceOnUse"><stop stop-color="#FFFFFF"/><stop offset="1" stop-color="#E6E8EC"/></linearGradient>
<linearGradient id="dieLeft" x1="16" y1="42" x2="60" y2="106" gradientUnits="userSpaceOnUse"><stop stop-color="#E5E7EB"/><stop offset="1" stop-color="#C4C9D2"/></linearGradient>
<linearGradient id="dieRight" x1="60" y1="42" x2="104" y2="106" gradientUnits="userSpaceOnUse"><stop stop-color="#D1D5DB"/><stop offset="1" stop-color="#9CA3AF"/></linearGradient>
</defs>
<path d="M60 14 C63 14 100 31 102 35 C104 39 64 58 60 58 C56 58 16 39 18 35 C20 31 57 14 60 14 Z" fill="url(#dieTop)"/>
<path d="M17 36 C17 36 56 56 60 58 L60 106 C55 106 20 86 18 81 C16 76 17 36 17 36 Z" fill="url(#dieLeft)"/>
<path d="M103 36 C103 36 64 56 60 58 L60 106 C65 106 100 86 102 81 C104 76 103 36 103 36 Z" fill="url(#dieRight)"/>
<path d="M18 35 L60 57 L102 35" stroke="#FFFFFF" stroke-width="2.5" stroke-linecap="round" opacity=".8"/><path d="M60 57 L60 105" stroke="#E5E7EB" stroke-width="2" stroke-linecap="round" opacity=".6"/>
<ellipse cx="60" cy="36" rx="9.5" ry="6.2" fill="#EF233C"/><ellipse cx="60" cy="37" rx="8.5" ry="5.2" fill="#D90429"/>
<ellipse cx="29" cy="54" rx="5.2" ry="6.8" transform="rotate(-18 29 54)" fill="#1F2937"/><ellipse cx="39" cy="69" rx="5.2" ry="6.8" transform="rotate(-18 39 69)" fill="#1F2937"/><ellipse cx="49" cy="84" rx="5.2" ry="6.8" transform="rotate(-18 49 84)" fill="#1F2937"/>
<ellipse cx="75" cy="64" rx="5.2" ry="6.8" transform="rotate(18 75 64)" fill="#111827"/><ellipse cx="89" cy="79" rx="5.2" ry="6.8" transform="rotate(18 89 79)" fill="#111827"/>
</svg>''';
