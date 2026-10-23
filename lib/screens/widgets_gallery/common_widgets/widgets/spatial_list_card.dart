import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

enum SpatialListItemKind {
  note,
  bottle,
  pesto,
  mayo,
  crackers,
  spinach,
  cheese,
  hummus,
  custom,
}

class SpatialListItemData {
  final SpatialListItemKind kind;
  final String? svg;
  final int quantity;
  final double width;
  final double height;
  final Offset collapsedOffset;
  final Offset expandedOffset;
  final double collapsedScale;
  final double expandedScale;
  final double angle;
  final bool expandedOnly;

  const SpatialListItemData({
    required this.kind,
    this.svg,
    this.quantity = 1,
    required this.width,
    required this.height,
    required this.collapsedOffset,
    required this.expandedOffset,
    this.collapsedScale = 0.85,
    this.expandedScale = 1,
    this.angle = 0,
    this.expandedOnly = false,
  });

  factory SpatialListItemData.fromProps(Map<String, dynamic> props) {
    Offset parseOffset(dynamic value, Offset fallback) {
      if (value is List && value.length >= 2) {
        return Offset(
          (value[0] as num?)?.toDouble() ?? fallback.dx,
          (value[1] as num?)?.toDouble() ?? fallback.dy,
        );
      }
      return fallback;
    }

    final kind =
        SpatialListItemKind.values.asNameMap()[props['kind']] ??
        SpatialListItemKind.custom;
    return SpatialListItemData(
      kind: kind,
      svg: props['svg'] as String?,
      quantity: (props['quantity'] as num?)?.toInt() ?? 1,
      width: (props['width'] as num?)?.toDouble() ?? 100,
      height: (props['height'] as num?)?.toDouble() ?? 120,
      collapsedOffset: parseOffset(props['collapsedOffset'], Offset.zero),
      expandedOffset: parseOffset(props['expandedOffset'], Offset.zero),
      collapsedScale: (props['collapsedScale'] as num?)?.toDouble() ?? 0.85,
      expandedScale: (props['expandedScale'] as num?)?.toDouble() ?? 1,
      angle: (props['angle'] as num?)?.toDouble() ?? 0,
      expandedOnly: props['expandedOnly'] as bool? ?? false,
    );
  }
}

class SpatialListCardWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final String updatedLabel;
  final int itemCount;
  final String noteTitle;
  final String noteAuthor;
  final String noteContent;
  final List<SpatialListItemData> items;
  final bool initialExpanded;
  final ValueChanged<bool>? onExpandedChanged;
  final bool inline;
  final HomeWidgetSize size;

  const SpatialListCardWidget({
    super.key,
    this.title = 'Sunday Brunch Prep',
    this.subtitle = 'Ready for fresh croissants and OJ!',
    this.updatedLabel = '2 days ago',
    this.itemCount = 14,
    this.noteTitle = 'Note 1',
    this.noteAuthor = 'Belle',
    this.noteContent =
        'Check the produce aisle for any discounts, crooked carrots and flat fruit still work in the snack plate',
    this.items = const [],
    this.initialExpanded = false,
    this.onExpandedChanged,
    this.inline = false,
    this.size = const Large3Size(),
  });

  factory SpatialListCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    return SpatialListCardWidget(
      title: props['title'] as String? ?? 'Sunday Brunch Prep',
      subtitle:
          props['subtitle'] as String? ?? 'Ready for fresh croissants and OJ!',
      updatedLabel: props['updatedLabel'] as String? ?? '2 days ago',
      itemCount: (props['itemCount'] as num?)?.toInt() ?? 14,
      noteTitle: props['noteTitle'] as String? ?? 'Note 1',
      noteAuthor: props['noteAuthor'] as String? ?? 'Belle',
      noteContent:
          props['noteContent'] as String? ??
          'Check the produce aisle for any discounts, crooked carrots and flat fruit still work in the snack plate',
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => SpatialListItemData.fromProps(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : defaultItems,
      initialExpanded: props['initialExpanded'] as bool? ?? false,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  static const defaultItems = <SpatialListItemData>[
    SpatialListItemData(
      kind: SpatialListItemKind.mayo,
      width: 78,
      height: 105,
      collapsedOffset: Offset(-155, -35),
      expandedOffset: Offset(-162, -18),
      collapsedScale: 0.75,
      expandedScale: 0.95,
      angle: -18,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.bottle,
      quantity: 2,
      width: 82,
      height: 154,
      collapsedOffset: Offset(-96, 8),
      expandedOffset: Offset(-118, 152),
      collapsedScale: 0.86,
      expandedScale: 0.95,
      angle: -14,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.note,
      width: 158,
      height: 156,
      collapsedOffset: Offset(2, 16),
      expandedOffset: Offset(-4, 56),
      collapsedScale: 0.76,
      expandedScale: 1.03,
      angle: -6,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.pesto,
      width: 86,
      height: 112,
      collapsedOffset: Offset(96, 20),
      expandedOffset: Offset(146, 44),
      collapsedScale: 0.88,
      expandedScale: 0.98,
      angle: 12,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.crackers,
      width: 86,
      height: 110,
      collapsedOffset: Offset(8, 265),
      expandedOffset: Offset(-6, 232),
      collapsedScale: 0.8,
      expandedScale: 0.96,
      angle: -5,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.spinach,
      quantity: 2,
      width: 114,
      height: 138,
      collapsedOffset: Offset(280, 95),
      expandedOffset: Offset(256, 88),
      expandedScale: 0.96,
      angle: -11,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.cheese,
      width: 112,
      height: 118,
      collapsedOffset: Offset(175, 235),
      expandedOffset: Offset(152, 212),
      expandedScale: 0.96,
      angle: 4,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.hummus,
      width: 100,
      height: 88,
      collapsedOffset: Offset(300, -25),
      expandedOffset: Offset(274, -26),
      expandedScale: 0.96,
      angle: 8,
      expandedOnly: true,
    ),
  ];

  @override
  State<SpatialListCardWidget> createState() => _SpatialListCardWidgetState();
}

class _SpatialListCardWidgetState extends State<SpatialListCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Offset _pan = Offset.zero;
  Offset _panStart = Offset.zero;
  Offset _dragOrigin = Offset.zero;

  bool get _expanded => _controller.value > 0.5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
      value: widget.initialExpanded ? 1 : 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setExpanded(bool expanded) {
    setState(() => _pan = Offset.zero);
    if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpandedChanged?.call(expanded);
  }

  void _toggleExpanded() => _setExpanded(!_expanded);

  @override
  Widget build(BuildContext context) {
    final scale = widget.size.scale;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          key: const Key('spatial_list_card'),
          width: widget.inline ? double.maxFinite : 384 * scale,
          height: (204 + 234 * progress) * scale,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF6F6F4),
            borderRadius: BorderRadius.circular(28 * scale),
          ),
          child: Column(
            children: [
              _buildHeader(scale),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    10 * scale,
                    (6 + 8 * progress) * scale,
                    10 * scale,
                    10 * progress * scale,
                  ),
                  child: _buildCanvas(progress, scale, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(double scale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : const Color(0xFF111111);
    final secondary = isDark ? Colors.white60 : const Color(0xFF7C7C78);
    return GestureDetector(
      key: const Key('spatial_list_header'),
      behavior: HitTestBehavior.opaque,
      onTap: _toggleExpanded,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20 * scale, 16 * scale, 20 * scale, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13 * scale, color: secondary),
                    SizedBox(width: 6 * scale),
                    Text(
                      widget.updatedLabel,
                      style: TextStyle(fontSize: 12 * scale, color: secondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.notes, size: 13 * scale, color: secondary),
                    SizedBox(width: 4 * scale),
                    Text(
                      '${widget.itemCount}',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22 * scale,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6 * scale,
                color: primary,
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              widget.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5 * scale, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas(double progress, double scale, bool isDark) {
    final items = widget.items.isEmpty
        ? SpatialListCardWidget.defaultItems
        : widget.items;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          key: const Key('spatial_list_canvas'),
          behavior: HitTestBehavior.opaque,
          onTap: _expanded ? null : _toggleExpanded,
          onPanStart: _expanded
              ? (details) {
                  _panStart = _pan;
                  _dragOrigin = details.localPosition;
                }
              : null,
          onPanUpdate: _expanded
              ? (details) {
                  final next = _panStart + details.localPosition - _dragOrigin;
                  setState(() {
                    _pan = Offset(
                      next.dx.clamp(-230.0, 60.0),
                      next.dy.clamp(-60.0, 60.0),
                    );
                  });
                }
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22 * scale),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.transparent,
                  isDark ? const Color(0xFF242426) : Colors.white,
                  progress,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03 * progress),
                    blurRadius: 12 * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DotGridPainter(progress: progress, scale: scale),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    for (final item in items)
                      _buildItem(item, constraints, progress, scale),
                    Positioned(
                      right: 12 * scale,
                      bottom: 12 * scale,
                      child: Opacity(
                        opacity: progress,
                        child: Transform.scale(
                          scale: 0.82 + 0.18 * progress,
                          child: _buildMinimap(scale),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
    SpatialListItemData item,
    BoxConstraints constraints,
    double progress,
    double scale,
  ) {
    final width = item.width * scale;
    final height = item.height * scale;
    final offset =
        Offset.lerp(item.collapsedOffset, item.expandedOffset, progress)! *
            scale +
        _pan * progress;
    final itemScale =
        item.collapsedScale +
        (item.expandedScale - item.collapsedScale) * progress;
    final opacity = item.expandedOnly ? progress : 1.0;
    return Positioned(
      left: constraints.maxWidth / 2 - width / 2,
      top: 0,
      width: width,
      height: height,
      child: IgnorePointer(
        ignoring: opacity == 0,
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: item.angle * math.pi / 180,
              child: Transform.scale(
                scale: itemScale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: width,
                      height: height,
                      child: _buildItemContent(item),
                    ),
                    if (item.kind != SpatialListItemKind.note &&
                        item.kind != SpatialListItemKind.crackers &&
                        item.kind != SpatialListItemKind.cheese &&
                        item.kind != SpatialListItemKind.hummus)
                      Positioned(
                        right: -4 * scale,
                        bottom: 2 * scale,
                        child: Opacity(
                          opacity: progress,
                          child: Transform.scale(
                            scale: 0.5 + 0.5 * progress,
                            child: Container(
                              width: 24 * scale,
                              height: 24 * scale,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF141414),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x38000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${item.quantity}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11 * scale,
                                  fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }

  Widget _buildItemContent(SpatialListItemData item) {
    if (item.kind == SpatialListItemKind.note) {
      return _SpatialNote(
        title: widget.noteTitle,
        author: widget.noteAuthor,
        content: widget.noteContent,
        scale: widget.size.scale,
      );
    }
    final svg = item.svg ?? _defaultSvg[item.kind];
    if (svg == null) return const SizedBox.shrink();
    return SvgPicture.string(svg, fit: BoxFit.contain);
  }

  Widget _buildMinimap(double scale) {
    return Container(
      width: 68 * scale,
      height: 68 * scale,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: const Color(0x0F000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16 * scale,
            top: 24 * scale,
            child: Container(
              width: 10 * scale,
              height: 10 * scale,
              color: const Color(0x99FDE68A),
            ),
          ),
          Positioned(
            right: 14 * scale,
            top: 20 * scale,
            child: Container(
              width: 8 * scale,
              height: 8 * scale,
              decoration: const BoxDecoration(
                color: Color(0x9986EFAC),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 11 * scale,
            top: 26 * scale,
            child: Transform.translate(
              key: const Key('spatial_list_minimap_viewport'),
              offset: Offset(-_pan.dx / 200 * 18, -_pan.dy / 120 * 10) * scale,
              child: Container(
                width: 28 * scale,
                height: 29 * scale,
                decoration: BoxDecoration(
                  color: const Color(0x0A3B82F6),
                  border: Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 1.6 * scale,
                  ),
                  borderRadius: BorderRadius.circular(5 * scale),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpatialNote extends StatelessWidget {
  final String title;
  final String author;
  final String content;
  final double scale;

  const _SpatialNote({
    required this.title,
    required this.author,
    required this.content,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFFCD34D)],
        ),
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: const Color(0x33F59E0B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38B48214),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xBF451A03),
                    fontSize: 9.5 * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 4 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCCFDE047),
                  borderRadius: BorderRadius.circular(20 * scale),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10 * scale,
                      height: 10 * scale,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD97706),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4 * scale),
                    Text(
                      author,
                      style: TextStyle(
                        color: const Color(0xFF451A03),
                        fontSize: 8.5 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          Expanded(
            child: Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF291504),
                fontSize: 9.5 * scale,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SvgPicture.string(_noteDoodle, height: 44 * scale),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final double progress;
  final double scale;

  const _DotGridPainter({required this.progress, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final paint = Paint()
      ..color = const Color(0xFFE6E6E1).withValues(alpha: progress);
    final spacing = 16 * scale;
    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.25 * scale, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.scale != scale;
}

const _noteDoodle = '''
<svg viewBox="0 0 130 48" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 36 C32 38,56 14,42 7 C28 0,24 22,48 25 C70 28,92 20,108 11" fill="none" stroke="#78350f" stroke-width="2.1" stroke-linecap="round"/>
  <path d="M100 8 L109 10 L105 19 M77 29 C74 24,67 25,67 31 C67 36,75 41,77 44 C79 41,87 36,87 31 C87 25,80 24,77 29 Z" fill="none" stroke="#78350f" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

const _defaultSvg = <SpatialListItemKind, String>{
  SpatialListItemKind.bottle: '''
<svg viewBox="0 0 100 190" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="pink" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#fbcfe8"/><stop offset=".5" stop-color="#f9a8d4"/><stop offset="1" stop-color="#f472b6"/></linearGradient></defs>
  <rect x="41" y="4" width="18" height="14" rx="3" fill="#f8fafc" stroke="#e2e8f0"/><rect x="41" y="9" width="18" height="4" fill="#f472b6"/>
  <path d="M42 18 L40 60 C25 78 22 90 22 112 L22 172 C22 180 28 184 36 184 L64 184 C72 184 78 180 78 172 L78 112 C78 90 75 78 60 60 L58 18 Z" fill="url(#pink)" stroke="#f472b6"/>
  <path d="M30 85 L30 168" stroke="#fff" stroke-width="4.5" stroke-linecap="round" opacity=".55"/>
  <rect x="25" y="102" width="50" height="54" rx="6" fill="#fff1f2" stroke="#fecdd3"/>
  <circle cx="50" cy="120" r="9" fill="#ffe4e6"/><path d="M45 120 Q50 112 55 120 Q50 128 45 120" fill="#fb7185"/>
  <text x="50" y="139" text-anchor="middle" fill="#9f1239" font-size="8.5" font-weight="700" font-style="italic">Rosé Spritz</text><text x="50" y="148" text-anchor="middle" fill="#be123c" font-size="5.5">SPARKLING</text>
</svg>''',
  SpatialListItemKind.pesto: '''
<svg viewBox="0 0 110 140" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="6" width="70" height="17" rx="5" fill="#4d7c0f" stroke="#3f6212"/><rect x="24" y="22" width="62" height="8" rx="2" fill="#365314"/>
  <rect x="14" y="28" width="82" height="102" rx="18" fill="#3f6212" stroke="#1a2e05"/><circle cx="30" cy="42" r="6" fill="#4d7c0f"/><circle cx="75" cy="115" r="8" fill="#65a30d" opacity=".4"/>
  <rect x="16" y="45" width="78" height="62" rx="6" fill="#fef08a"/><path d="M20 58 Q55 46 90 58" stroke="#dc2626" stroke-width="8" fill="none" stroke-linecap="round"/>
  <text x="55" y="57" text-anchor="middle" fill="#fff" font-size="6.5" font-weight="800">FILIPPO BERIO</text><ellipse cx="55" cy="80" rx="31" ry="18" fill="#1e3a8a" stroke="#fff" stroke-width="1.5"/>
  <text x="55" y="81" text-anchor="middle" fill="#fff" font-size="11" font-weight="900">PESTO</text><text x="55" y="90" text-anchor="middle" fill="#fde047" font-size="5.5" font-weight="700">CLASSIC BASIL</text>
  <path d="M24 35 L24 120" stroke="#fff" stroke-width="3.5" stroke-linecap="round" opacity=".35"/>
</svg>''',
  SpatialListItemKind.mayo: '''
<svg viewBox="0 0 100 130" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="4" width="60" height="16" rx="5" fill="#1d4ed8"/><rect x="12" y="18" width="76" height="100" rx="22" fill="#f7f2df" stroke="#e5dec2" stroke-width="1.5"/>
  <path d="M22 28 C22 50 22 90 22 108" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".7"/><rect x="13" y="42" width="74" height="48" fill="#fef08a"/>
  <polygon points="50,44 84,66 50,88 16,66" fill="#1e3a8a"/><text x="50" y="65" text-anchor="middle" fill="#fff" font-size="8.5" font-weight="800">HELLMANN'S</text><text x="50" y="75" text-anchor="middle" fill="#93c5fd" font-size="6.5" font-weight="700">REAL</text>
</svg>''',
  SpatialListItemKind.crackers: '''
<svg viewBox="0 0 100 126" xmlns="http://www.w3.org/2000/svg">
  <polygon points="10,6 90,6 86,14 14,14" fill="#1d4ed8"/><polygon points="14,112 86,112 90,120 10,120" fill="#1d4ed8"/><rect x="12" y="12" width="76" height="102" rx="6" fill="#0284c7" stroke="#0369a1" stroke-width="1.5"/>
  <rect x="20" y="22" width="60" height="82" rx="4" fill="#fff"/><g transform="translate(50 63) rotate(-90)"><text x="0" y="-4" text-anchor="middle" fill="#dc2626" font-size="15" font-weight="900">TWO BY</text><text x="0" y="13" text-anchor="middle" fill="#dc2626" font-size="16" font-weight="900">TWO</text></g><circle cx="30" cy="34" r="6" fill="#fbbf24"/>
</svg>''',
  SpatialListItemKind.spinach: '''
<svg viewBox="0 0 120 145" xmlns="http://www.w3.org/2000/svg">
  <rect x="14" y="8" width="92" height="128" rx="12" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1.5"/><rect x="18" y="24" width="84" height="92" rx="8" fill="#15803d"/>
  <circle cx="42" cy="48" r="16" fill="#166534"/><circle cx="72" cy="52" r="18" fill="#22c55e" opacity=".7"/><circle cx="52" cy="85" r="20" fill="#14532d"/><circle cx="80" cy="88" r="15" fill="#4ade80" opacity=".6"/>
  <rect x="16" y="54" width="88" height="34" fill="#fff" opacity=".95"/><text x="60" y="69" text-anchor="middle" fill="#14532d" font-size="8.5" font-weight="800">ORGANIC</text><text x="60" y="80" text-anchor="middle" fill="#15803d" font-size="7.5" font-weight="700">BABY SPINACH</text>
</svg>''',
  SpatialListItemKind.cheese: '''
<svg viewBox="0 0 120 120" xmlns="http://www.w3.org/2000/svg">
  <polygon points="60,12 104,92 18,98" fill="#fef9c3" stroke="#fde047" stroke-width="2" stroke-linejoin="round"/><polygon points="104,92 18,98 24,108 108,102" fill="#fde047"/><polygon points="58,42 82,78 38,81" fill="#1c1917"/>
  <text x="60" y="69" text-anchor="middle" fill="#fef08a" font-size="6.5" font-weight="700">PARMIGIANO</text><text x="60" y="76" text-anchor="middle" fill="#fff" font-size="5">24 MONTHS</text>
</svg>''',
  SpatialListItemKind.hummus: '''
<svg viewBox="0 0 120 100" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="60" cy="56" rx="44" ry="28" fill="#f5e6d3" stroke="#d6c5b3" stroke-width="1.5"/><ellipse cx="60" cy="46" rx="48" ry="30" fill="#b91c1c"/><ellipse cx="60" cy="44" rx="42" ry="25" fill="#fef3c7"/><ellipse cx="60" cy="44" rx="22" ry="12" fill="#991b1b"/><text x="60" y="47" text-anchor="middle" fill="#fff" font-size="7.5" font-weight="800">SABRA</text>
</svg>''',
};
