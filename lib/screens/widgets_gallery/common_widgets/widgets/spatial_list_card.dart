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

  /// 打开回调：非空时 header 右侧显示编辑按钮（用于进入编辑场景）
  final VoidCallback? onOpen;
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
    this.onOpen,
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

  /// 手账主题默认物品：中位手绘便签（显示 noteContent 摘要）+ 四周
  /// 手账素材贴纸（与 assets/svg/scrapbook 同源，内嵌 const 保持同步渲染）
  static const defaultItems = <SpatialListItemData>[
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapTapeSvg,
      width: 110,
      height: 40,
      collapsedOffset: Offset(-155, -35),
      expandedOffset: Offset(-162, -18),
      collapsedScale: 0.75,
      expandedScale: 0.95,
      angle: -18,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapAirplaneSvg,
      width: 84,
      height: 116,
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
      kind: SpatialListItemKind.custom,
      svg: _scrapCloudSvg,
      width: 104,
      height: 82,
      collapsedOffset: Offset(96, 20),
      expandedOffset: Offset(146, 44),
      collapsedScale: 0.88,
      expandedScale: 0.98,
      angle: 12,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapFujiSvg,
      width: 86,
      height: 94,
      collapsedOffset: Offset(8, 265),
      expandedOffset: Offset(-6, 232),
      expandedScale: 0.96,
      angle: -5,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapPlushieSvg,
      width: 92,
      height: 130,
      collapsedOffset: Offset(280, 95),
      expandedOffset: Offset(256, 88),
      expandedScale: 0.96,
      angle: -11,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapShinkansenSvg,
      width: 86,
      height: 128,
      collapsedOffset: Offset(175, 235),
      expandedOffset: Offset(152, 212),
      expandedScale: 0.96,
      angle: 4,
      expandedOnly: true,
    ),
    SpatialListItemData(
      kind: SpatialListItemKind.custom,
      svg: _scrapSparklesSvg,
      width: 96,
      height: 90,
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
                    if (widget.onOpen != null) ...[
                      SizedBox(width: 10 * scale),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpen,
                        child: Container(
                          width: 26 * scale,
                          height: 26 * scale,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFF111111),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14 * scale,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
                        item.kind != SpatialListItemKind.custom &&
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
    final svg = item.svg;
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

const _scrapTapeSvg = '''
<svg viewBox="0 0 44 16" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="tape" x1="0" y1="0" x2="1" y2="1">
      <stop stop-color="#EBF4F1EA"/>
      <stop offset="1" stop-color="#E0E8E4DB"/>
    </linearGradient>
  </defs>
  <rect x="0.5" y="0.5" width="43" height="15" rx="8" fill="url(#tape)" stroke="#1F000000" stroke-width="1"/>
  <line x1="13" y1="3" x2="13" y2="13" stroke="#73A09A8E" stroke-width="1"/>
  <line x1="31" y1="3" x2="31" y2="13" stroke="#73A09A8E" stroke-width="1"/>
</svg>
''';
const _scrapCloudSvg = '''
<svg viewBox="0 0 64 50" xmlns="http://www.w3.org/2000/svg">
  <path d="M16 34 C9 34 6 28 9 23 C6 17 11 11 18 12 C21 6 31 5 36 10 C43 6 52 10 52 17 C58 19 59 27 54 31 C55 36 48 40 42 38 C38 42 28 42 25 38 C21 40 16 38 16 34 Z"
        fill="#FFFFFF" stroke="#D4D0C8" stroke-width="1.5" stroke-linejoin="round"/>
  <circle cx="14" cy="42" r="2.6" fill="#FFFFFF" stroke="#D4D0C8" stroke-width="1.2"/>
  <circle cx="9" cy="46" r="1.6" fill="#FFFFFF" stroke="#D4D0C8" stroke-width="1.1"/>
  <text x="33" y="27" text-anchor="middle" font-family="sans-serif" font-size="9" font-weight="700" fill="#D9388A">omg!!</text>
</svg>
''';
const _scrapFujiSvg = '''
<svg viewBox="0 0 44 48" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="arch">
      <path d="M22 0 L38.7 13.4 L44 48 L0 48 L5.3 13.4 Z"/>
    </clipPath>
  </defs>
  <g clip-path="url(#arch)">
    <rect x="0" y="0" width="44" height="48" fill="#87A8C4"/>
    <rect x="0" y="0" width="44" height="48" fill="#CFE2F3" opacity="0.5"/>
    <path d="M4 34 L17 11 L27 11 L40 34 Z" fill="#4A6984"/>
    <path d="M17 11 L27 11 L31 19 L26 17 L22 20 L18 17 L13 19 Z" fill="#FFFFFF"/>
    <circle cx="6" cy="28" r="9" fill="#C84B31"/>
    <circle cx="38" cy="28" r="9" fill="#D96B27"/>
    <circle cx="4" cy="36" r="8" fill="#5C8244"/>
    <circle cx="40" cy="36" r="8" fill="#4E7338"/>
    <path d="M18 32 L11 48 L33 48 L26 32 Z" fill="#D9D2C5"/>
    <line x1="19" y1="32" x2="14" y2="48" stroke="#333333" stroke-width="1.2"/>
    <line x1="25" y1="32" x2="30" y2="48" stroke="#333333" stroke-width="1.2"/>
  </g>
</svg>
''';
const _scrapShinkansenSvg = '''
<svg viewBox="0 0 90 134" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="90" height="54" fill="#4B473E"/>
  <line x1="0" y1="18" x2="90" y2="18" stroke="#38342C" stroke-width="2"/>
  <line x1="0" y1="36" x2="90" y2="36" stroke="#38342C" stroke-width="2"/>
  <rect x="0" y="54" width="90" height="38" fill="#DCE7EB"/>
  <path d="M0 78 Q25 62 55 72 Q75 77 90 66 L90 92 L0 92 Z" fill="#4F6F46"/>
  <path d="M18 96 C22 76 48 68 90 66 L90 108 L18 108 Z" fill="#F7F7F7"/>
  <path d="M26 88 C34 78 52 74 68 74 L68 85 L26 88 Z" fill="#1E242B"/>
  <path d="M18 96 C26 92 55 90 90 90 L90 102 L18 102 Z" fill="#C92424"/>
  <rect x="0" y="108" width="90" height="26" fill="#18181A"/>
  <line x1="0" y1="115" x2="90" y2="115" stroke="#555555" stroke-width="1.5"/>
</svg>
''';
const _scrapPlushieSvg = '''
<svg viewBox="0 0 92 130" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="92" height="130" fill="#D8E2DC"/>
  <rect x="0" y="0" width="92" height="44" fill="#5A8F48"/>
  <circle cx="14" cy="24" r="12" fill="#76AA5E"/>
  <circle cx="38" cy="18" r="14" fill="#467836"/>
  <circle cx="66" cy="24" r="13" fill="#689F52"/>
  <circle cx="22" cy="14" r="4" fill="#FF9EBB"/>
  <circle cx="52" cy="22" r="4.5" fill="#FFD166"/>
  <ellipse cx="28" cy="96" rx="28" ry="30" fill="#F5CC27"/>
  <ellipse cx="72" cy="98" rx="26" ry="28" fill="#EBBF1E"/>
  <circle cx="15" cy="86" r="2.8" fill="#2B1E16"/>
  <circle cx="32" cy="87" r="2.8" fill="#2B1E16"/>
  <ellipse cx="23" cy="89.2" rx="2" ry="1.2" fill="#2B1E16"/>
  <circle cx="9" cy="92" r="4" fill="#B3E85D56"/>
  <circle cx="38" cy="93" r="4" fill="#B3E85D56"/>
</svg>
''';
const _scrapSparklesSvg = '''
<svg viewBox="0 0 36 34" xmlns="http://www.w3.org/2000/svg">
  <g fill="none" stroke="#D93829" stroke-width="1.3" stroke-linejoin="round">
    <path d="M18 2 C19 10 21 12 29 13 C21 14 19 16 18 24 C17 16 15 14 7 13 C15 12 17 10 18 2 Z"/>
    <path d="M9 17 C9.6 22 11 23 16 23.5 C11 24 9.6 25 9 30 C8.4 25 7 24 2 23.5 C7 23 8.4 22 9 17 Z"/>
  </g>
</svg>
''';
const _scrapAirplaneSvg = '''
<svg viewBox="0 0 90 124" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="dawn" x1="0" y1="0" x2="0" y2="1">
      <stop stop-color="#6B7A99"/>
      <stop offset="0.35" stop-color="#9A8FA6"/>
      <stop offset="0.62" stop-color="#D49B94"/>
      <stop offset="0.78" stop-color="#E59872"/>
      <stop offset="0.9" stop-color="#3E323B"/>
      <stop offset="1" stop-color="#221C24"/>
    </linearGradient>
    <clipPath id="win">
      <rect x="0" y="0" width="90" height="124" rx="24"/>
    </clipPath>
  </defs>
  <g clip-path="url(#win)">
    <rect x="0" y="0" width="90" height="124" fill="url(#dawn)"/>
    <ellipse cx="45" cy="90.5" width="117" height="15.5" rx="58" ry="8" fill="#A6FFAE78"/>
    <path d="M0 96.7 Q28.8 89.3 61.2 94.1 Q76.5 96.7 90 91.7 L90 124 L0 124 Z" fill="#2A2229"/>
    <path d="M0 102.9 Q39.6 98 90 101.7 L90 124 L0 124 Z" fill="#1A151B"/>
  </g>
  <rect x="1.25" y="1.25" width="87.5" height="121.5" rx="22.75" fill="none" stroke="#2C2933" stroke-width="2.5"/>
</svg>
''';
