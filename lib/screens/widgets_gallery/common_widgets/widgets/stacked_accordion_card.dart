/// 堆叠手风琴卡片组（手绘纸卡风格）
///
/// 手绘纸卡层叠（后一张覆盖前一张底部，卡片为数据色纸底 + rough 墨线框，
/// WiredDraw 描画入场）：点击卡片展开手风琴面板（互斥）：斜纹进度条从 0
/// 生长到目标值，条目列表交错渐入，箭头旋转 90°。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';
import 'package:aboutme/screens/widgets_gallery/common_widgets/utils/striped_fill.dart';

/// CSS var(--spring-easing): cubic-bezier(0.22, 1, 0.36, 1)
const Cubic _springCurve = Cubic(0.22, 1, 0.36, 1);
const Duration _springDuration = Duration(milliseconds: 520);

/// 展开面板中的列表条目（主文本 + 次文本）
class StackedAccordionEntryData {
  final String term;
  final String subtitle;

  const StackedAccordionEntryData({required this.term, this.subtitle = ''});
}

/// 单张堆叠卡片数据
class StackedAccordionCardData {
  final String title;

  /// 标题行右侧的百分比/数值文本
  final String percentage;

  /// 胶囊标签组
  final List<String> tags;

  /// 展开面板进度条比例（0~1）
  final double progress;

  /// 进度区左侧标签
  final String progressLabel;

  /// 进度区右侧数值文本
  final String progressValue;

  /// 展开面板的条目列表
  final List<StackedAccordionEntryData> entries;

  final Color backgroundColor;

  /// 覆盖自动的明暗文字判断（null 时按背景亮度自动判断）
  final bool? lightText;

  const StackedAccordionCardData({
    required this.title,
    this.percentage = '',
    this.tags = const [],
    this.progress = 0,
    this.progressLabel = '',
    this.progressValue = '',
    this.entries = const [],
    this.backgroundColor = const Color(0xFFD8C2F8),
    this.lightText,
  });

  bool get useLightText =>
      lightText ?? backgroundColor.computeLuminance() < 0.45;
}

/// 默认演示数据（与参考 HTML 一致的 5 张卡片）
const List<StackedAccordionCardData> kStackedAccordionDemoItems = [
  StackedAccordionCardData(
    title: 'Social issues',
    percentage: '23%',
    tags: ['Pre-intermediate', '48 words'],
    progress: 0.23,
    progressLabel: 'Mastery progress',
    progressValue: '11 / 48 learned',
    entries: [
      StackedAccordionEntryData(
        term: 'Inequality',
        subtitle: 'noun · /ˌɪnɪˈkwɒləti/',
      ),
      StackedAccordionEntryData(
        term: 'Sustainability',
        subtitle: 'noun · /səˌsteɪnəˈbɪləti/',
      ),
      StackedAccordionEntryData(
        term: 'Demographics',
        subtitle: 'noun · /ˌdeməˈɡræfɪks/',
      ),
      StackedAccordionEntryData(
        term: 'Welfare',
        subtitle: 'noun · /ˈwelfeər/',
      ),
    ],
    backgroundColor: Color(0xFFD8C2F8),
  ),
  StackedAccordionCardData(
    title: 'Museum',
    percentage: '78%',
    tags: ['Intermediate', '26 words'],
    progress: 0.78,
    progressLabel: 'Mastery progress',
    progressValue: '20 / 26 learned',
    entries: [
      StackedAccordionEntryData(
        term: 'Exhibition',
        subtitle: 'noun · /ˌeksɪˈbɪʃn/',
      ),
      StackedAccordionEntryData(
        term: 'Curator',
        subtitle: 'noun · /kjʊˈreɪtər/',
      ),
      StackedAccordionEntryData(
        term: 'Artifact',
        subtitle: 'noun · /ˈɑːrtɪfækt/',
      ),
      StackedAccordionEntryData(
        term: 'Antiquity',
        subtitle: 'noun · /ænˈtɪkwəti/',
      ),
    ],
    backgroundColor: Color(0xFFDCFA76),
  ),
  StackedAccordionCardData(
    title: 'Daily life',
    percentage: '98%',
    tags: ['Elementary', '167 words'],
    progress: 0.98,
    progressLabel: 'Mastery progress',
    progressValue: '164 / 167 learned',
    entries: [
      StackedAccordionEntryData(
        term: 'Commute',
        subtitle: 'verb · /kəˈmjuːt/',
      ),
      StackedAccordionEntryData(
        term: 'Groceries',
        subtitle: 'noun · /ˈɡroʊsəriz/',
      ),
      StackedAccordionEntryData(term: 'Chore', subtitle: 'noun · /tʃɔːr/'),
      StackedAccordionEntryData(
        term: 'Neighborhood',
        subtitle: 'noun · /ˈnɛɪbərˌhʊd/',
      ),
    ],
    backgroundColor: Color(0xFF3B50D6),
  ),
  StackedAccordionCardData(
    title: 'Food',
    percentage: '100%',
    tags: ['Pre-intermediate', '96 words'],
    progress: 1,
    progressLabel: 'Mastery progress',
    progressValue: '96 / 96 learned',
    entries: [
      StackedAccordionEntryData(
        term: 'Ingredient',
        subtitle: 'noun · /ɪnˈɡriːdiənt/',
      ),
      StackedAccordionEntryData(
        term: 'Cuisine',
        subtitle: 'noun · /kwɪˈziːn/',
      ),
      StackedAccordionEntryData(
        term: 'Savory',
        subtitle: 'adj · /ˈseɪvəri/',
      ),
      StackedAccordionEntryData(
        term: 'Fermentation',
        subtitle: 'noun · /ˌfɜːrmenˈteɪʃn/',
      ),
    ],
    backgroundColor: Color(0xFFEC582A),
  ),
  StackedAccordionCardData(
    title: 'Music',
    percentage: '92%',
    tags: ['Intermediate', '64 words'],
    progress: 0.92,
    progressLabel: 'Mastery progress',
    progressValue: '59 / 64 learned',
    entries: [
      StackedAccordionEntryData(
        term: 'Harmony',
        subtitle: 'noun · /ˈhɑːrməni/',
      ),
      StackedAccordionEntryData(
        term: 'Acoustic',
        subtitle: 'adj · /əˈkuːstɪk/',
      ),
      StackedAccordionEntryData(term: 'Tempo', subtitle: 'noun · /ˈtempoʊ/'),
      StackedAccordionEntryData(
        term: 'Crescendo',
        subtitle: 'noun · /krəˈʃendoʊ/',
      ),
    ],
    backgroundColor: Color(0xFFD8C2F8),
  ),
];

/// 堆叠手风琴卡片组
///
/// 卡片自上而下层叠（后一张覆盖前一张底部），点击卡片展开手风琴面板
/// （互斥）：进度条从 0 生长到目标值，条目列表交错渐入，箭头旋转 90°。
class StackedAccordionCardWidget extends StatefulWidget {
  final List<StackedAccordionCardData> items;

  /// 初始展开的卡片下标（null 全部收起）
  final int? initiallyExpandedIndex;

  /// 卡片点击回调；null 时点击切换展开/收起
  final ValueChanged<int>? onCardTap;

  /// 卡片长按回调
  final ValueChanged<int>? onCardLongPress;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式固定宽 348×scale）
  final bool inline;

  final HomeWidgetSize size;

  const StackedAccordionCardWidget({
    super.key,
    this.items = kStackedAccordionDemoItems,
    this.initiallyExpandedIndex,
    this.onCardTap,
    this.onCardLongPress,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  ///
  /// items: [{title, percentage, tags, progress, progressLabel,
  /// progressValue, entries: [{term, subtitle}], color, lightText}]
  factory StackedAccordionCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = <StackedAccordionCardData>[
      if (rawItems is List)
        for (final e in rawItems)
          if (e is Map)
            StackedAccordionCardData(
              title: e['title']?.toString() ?? '',
              percentage: e['percentage']?.toString() ?? '',
              tags: [
                for (final t in (e['tags'] as List?) ?? const <dynamic>[])
                  t.toString(),
              ],
              progress: ((e['progress'] as num?)?.toDouble() ?? 0).clamp(
                0.0,
                1.0,
              ),
              progressLabel: e['progressLabel']?.toString() ?? '',
              progressValue: e['progressValue']?.toString() ?? '',
              entries: [
                for (final x in (e['entries'] as List?) ?? const <dynamic>[])
                  if (x is Map)
                    StackedAccordionEntryData(
                      term: x['term']?.toString() ?? '',
                      subtitle: x['subtitle']?.toString() ?? '',
                    ),
              ],
              backgroundColor: Color(
                (e['color'] as num?)?.toInt() ?? 0xFFD8C2F8,
              ),
              lightText: e['lightText'] as bool?,
            ),
    ];

    return StackedAccordionCardWidget(
      items: items.isNotEmpty ? items : kStackedAccordionDemoItems,
      initiallyExpandedIndex: props['initiallyExpandedIndex'] as int?,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<StackedAccordionCardWidget> createState() =>
      _StackedAccordionCardWidgetState();
}

class _StackedAccordionCardWidgetState extends State<StackedAccordionCardWidget> {
  /// 当前展开的卡片下标（手风琴互斥）
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _expandedIndex = widget.initiallyExpandedIndex;
  }

  void _handleTap(int index) {
    if (widget.onCardTap != null) {
      widget.onCardTap!(index);
      return;
    }
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _AccordionMetrics(
      widget.size.scale,
      widget.size is SmallSize,
    );

    // 手绘纸卡层叠：WiredDraw 描画入场（墨线画上纸面）
    return SizedBox(
      width: widget.inline ? double.maxFinite : 348 * metrics.scale,
      child: WiredDraw(
        child: _ShiftedColumn(
          overlap: metrics.overlap,
          children: [
            for (int i = 0; i < widget.items.length; i++)
              _AccordionCard(
                data: widget.items[i],
                expanded: _expandedIndex == i,
                isLast: i == widget.items.length - 1,
                metrics: metrics,
                onTap: () => _handleTap(i),
                onLongPress:
                    widget.onCardLongPress == null
                        ? null
                        : () => widget.onCardLongPress!(i),
              ),
          ],
        ),
      ),
    );
  }
}

/// 尺寸派生的度量（SmallSize 为紧凑档，其余同设计稿按 scale 缩放）
class _AccordionMetrics {
  final double scale;
  final bool compact;

  const _AccordionMetrics(this.scale, this.compact);

  double get radius => (compact ? 18 : 28) * scale;

  /// 后一张卡片覆盖前一张底部的距离
  double get overlap => (compact ? 28 : 46) * scale;

  double get paddingH => (compact ? 15 : 22) * scale;
  double get paddingV => (compact ? 15 : 22) * scale;

  /// 被下一张覆盖时预留的底部内边距（展开时略增以保持呼吸感）
  double get bottomPadCovered => (compact ? 48 : 66) * scale;
  double get bottomPadExpanded => (compact ? 52 : 70) * scale;
  double get bottomPadLast => (compact ? 16 : 24) * scale;

  double get titleSize => (compact ? 17 : 26) * scale;
  double get percentageSize => (compact ? 11.5 : 14) * scale;
  double get pillSize => (compact ? 11 : 13) * scale;
  double get pillBorderWidth => (compact ? 1 : 1.2) * scale;
  double get btnSize => (compact ? 27 : 34) * scale;
  double get iconSize => (compact ? 13 : 16) * scale;
  double get progressLabelSize => (compact ? 10.5 : 12) * scale;
  double get trackHeight => (compact ? 5 : 6) * scale;
  double get entryTermSize => (compact ? 12.5 : 14) * scale;
  double get entrySubSize => (compact ? 10.5 : 12) * scale;
  double get sectionSpacing => (compact ? 10 : 14) * scale;
  double get entrySpacing => (compact ? 5 : 7) * scale;
}

class _AccordionCard extends StatefulWidget {
  final StackedAccordionCardData data;
  final bool expanded;
  final bool isLast;
  final _AccordionMetrics metrics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AccordionCard({
    required this.data,
    required this.expanded,
    required this.isLast,
    required this.metrics,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_AccordionCard> createState() => _AccordionCardState();
}

class _AccordionCardState extends State<_AccordionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expand;

  /// 桌面端悬停状态（未展开卡片轻微上浮）
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(vsync: this, duration: _springDuration);
    if (widget.expanded) _expand.value = 1;
  }

  @override
  void didUpdateWidget(_AccordionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      widget.expanded ? _expand.forward() : _expand.reverse();
    }
  }

  @override
  void dispose() {
    _expand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final m = widget.metrics;
    final data = widget.data;
    final light = data.useLightText;
    // 前景色为数据底色的对比色（随背景亮度），不属于主题色
    final fg = light ? Colors.white : const Color(0xFF19191B);
    final subFg = fg.withValues(alpha: light ? 0.72 : 0.62);
    final dividerColor = fg.withValues(alpha: light ? 0.18 : 0.12);
    final itemBg = fg.withValues(alpha: light ? 0.12 : 0.06);
    final hovered = _hover && !widget.expanded;

    Widget card = AnimatedContainer(
      duration: _springDuration,
      curve: _springCurve,
      transform: Matrix4.translationValues(0, hovered ? -3.0 : 0.0, 0),
      // 手绘纸卡：数据色纸底 + rough 墨线框（无柔影）。
      // hachureColor 必须同步传数据色——hachure:false 时装饰层走
      // solid 实底（色值取 hachureColor ?? theme.hatch），
      // 不传会把所有卡盖成统一的主题排线色
      child: DsSketchPanel(
        theme: theme,
        fillColor: data.backgroundColor,
        hachureColor: data.backgroundColor,
        hachure: false,
        radius: BorderRadius.circular(m.radius),
        padding: EdgeInsets.fromLTRB(
          m.paddingH,
          m.paddingV,
          m.paddingH,
          widget.isLast
              ? m.bottomPadLast
              : (widget.expanded ? m.bottomPadExpanded : m.bottomPadCovered),
        ),
        child: _cardContent(m, theme, data, fg, subFg, dividerColor, itemBg),
      ),
    );

    final wrapped = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: card,
      ),
    );

    return wrapped;
  }

  Widget _cardContent(
    _AccordionMetrics m,
    AppThemeData theme,
    StackedAccordionCardData data,
    Color fg,
    Color subFg,
    Color dividerColor,
    Color itemBg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题行：标题 + 百分比
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                data.title,
                style: TextStyle(
                  fontSize: m.titleSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.025 * m.titleSize,
                  height: 1.15,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (data.percentage.isNotEmpty) ...[
              SizedBox(width: 8 * m.scale),
              Text(
                data.percentage,
                style: TextStyle(
                  fontSize: m.percentageSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.01 * m.percentageSize,
                  color: fg.withValues(alpha: 0.88),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: m.sectionSpacing),
        // 标签行：手绘胶囊标签组 + 圆形箭头按钮
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6 * m.scale,
                runSpacing: 6 * m.scale,
                children: [
                  for (final tag in data.tags)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 13 * m.scale,
                        vertical: 5.5 * m.scale,
                      ),
                      decoration: dsSketchDecoration(
                        theme: theme,
                        radius: BorderRadius.circular(999),
                        stroke: fg,
                        strokeWidth: m.pillBorderWidth,
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: m.pillSize,
                          fontWeight: FontWeight.w400,
                          height: 1.15,
                          letterSpacing: -0.01 * m.pillSize,
                          color: fg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 8 * m.scale),
            _arrowButton(m, theme),
          ],
        ),
        _accordionBody(m, theme, fg, subFg, dividerColor, itemBg),
      ],
    );
  }

  /// 圆形箭头按钮（墨底纸色图标，展开时旋转 90°）
  Widget _arrowButton(_AccordionMetrics m, AppThemeData theme) {
    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) {
        return Container(
          width: m.btnSize,
          height: m.btnSize,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(m.btnSize / 2),
            fillColor: theme.ink,
          ),
          child: Center(
            child: Transform.rotate(
              angle: _expand.value * math.pi / 2,
              child: WiredIcon(
                icon: Icons.arrow_forward,
                size: m.iconSize,
                color: theme.surface,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 手风琴面板：高度裁切 + 淡入 + 上移三者并行（对应 CSS grid 0fr→1fr）
  Widget _accordionBody(
    _AccordionMetrics m,
    AppThemeData theme,
    Color fg,
    Color subFg,
    Color dividerColor,
    Color itemBg,
  ) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _expand,
        builder: (context, child) {
          final t = _expand.value;
          return Opacity(
            // 透明度在动画前 73%（≈0.38s）内完成
            opacity: (t / 0.73).clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: t,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - t)),
                child: child,
              ),
            ),
          );
        },
        child: _bodyContent(m, theme, fg, subFg, dividerColor, itemBg),
      ),
    );
  }

  Widget _bodyContent(
    _AccordionMetrics m,
    AppThemeData theme,
    Color fg,
    Color subFg,
    Color dividerColor,
    Color itemBg,
  ) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度区（顶部分割线）
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: m.sectionSpacing),
            Container(
              width: double.infinity,
              height: 1,
              color: dividerColor,
            ),
            SizedBox(height: m.sectionSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (data.progressLabel.isNotEmpty)
                  Text(
                    data.progressLabel,
                    style: TextStyle(
                      fontSize: m.progressLabelSize,
                      fontWeight: FontWeight.w500,
                      color: subFg,
                    ),
                  ),
                if (data.progressValue.isNotEmpty)
                  Text(
                    data.progressValue,
                    style: TextStyle(
                      fontSize: m.progressLabelSize,
                      fontWeight: FontWeight.w500,
                      color: subFg,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 7 * m.scale),
            _progressTrack(m, theme, fg),
          ],
        ),
        // 条目列表（交错渐入）
        SizedBox(height: m.sectionSpacing),
        for (int i = 0; i < data.entries.length; i++)
          _staggered(
            i,
            Container(
              margin: EdgeInsets.only(
                bottom: i == data.entries.length - 1 ? 0 : m.entrySpacing,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 13 * m.scale,
                vertical: 9 * m.scale,
              ),
              decoration: dsSketchDecoration(
                theme: theme,
                radius: BorderRadius.circular(14 * m.scale),
                fillColor: itemBg,
                stroke: fg.withValues(alpha: 0.3),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      data.entries[i].term,
                      style: TextStyle(
                        fontSize: m.entryTermSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.01 * m.entryTermSize,
                        color: fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (data.entries[i].subtitle.isNotEmpty) ...[
                    SizedBox(width: 8 * m.scale),
                    Flexible(
                      child: Text(
                        data.entries[i].subtitle,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: m.entrySubSize,
                          fontWeight: FontWeight.w400,
                          color: subFg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 斜纹进度条：展开时从 0 生长到目标值（0.72s + 0.08s 延迟）
  ///
  /// 轨道 surfaceAlt 底 + 淡墨斜纹，进度段数据色（卡片前景色）浅底 +
  /// 浓斜纹 + 数据色描边。
  Widget _progressTrack(_AccordionMetrics m, AppThemeData theme, Color dataColor) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('progress-${widget.expanded}-${widget.data.progress}'),
      tween: Tween(begin: 0, end: widget.expanded ? widget.data.progress : 0),
      duration: const Duration(milliseconds: 720),
      curve: const Interval(0.11, 1.0, curve: _springCurve),
      builder: (context, value, _) {
        return SizedBox(
          height: m.trackHeight,
          child: CustomPaint(
            size: Size(double.infinity, m.trackHeight),
            painter: _StripedMiniTrackPainter(
              value: value.clamp(0.0, 1.0),
              dataColor: dataColor,
              theme: theme,
              scale: m.scale,
            ),
          ),
        );
      },
    );
  }

  /// 条目交错渐入（展开时依次 0.05s / 0.09s / 0.13s ... 延迟）
  Widget _staggered(int index, Widget child) {
    final start = ((0.05 + index * 0.04) / 0.52).clamp(0.0, 0.9);
    final animation = CurvedAnimation(
      parent: _expand,
      curve: Interval(
        start,
        math.min(start + 0.73, 1.0),
        curve: Curves.easeOut,
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 斜纹迷你进度条绘制器（胶囊轨道 + 数据色斜纹进度段）
class _StripedMiniTrackPainter extends CustomPainter {
  final double value;
  final Color dataColor;
  final AppThemeData theme;
  final double scale;

  const _StripedMiniTrackPainter({
    required this.value,
    required this.dataColor,
    required this.theme,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );

    // 轨道：surfaceAlt 底 + 淡墨斜纹 + 淡墨描边
    final trackPath = Path()..addRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = theme.surfaceAlt);
    paintDiagonalStripes(
      canvas,
      trackPath,
      Offset.zero & size,
      color: theme.ink.withValues(alpha: 0.28),
      strokeWidth: 1.5 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale,
    );

    if (value <= 0) return;
    final w = size.width * value;
    final fillRect = Rect.fromLTWH(0, 0, w, size.height);
    final fillRRect = RRect.fromRectAndRadius(
      fillRect,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(fillRRect, Paint()..color = dataColor.withValues(alpha: 0.28));
    paintDiagonalStripes(
      canvas,
      Path()..addRRect(fillRRect),
      fillRect,
      color: dataColor.withValues(alpha: 0.9),
      strokeWidth: 3 * scale,
      spacing: 6.5 * scale,
    );
    canvas.drawRRect(
      fillRRect,
      Paint()
        ..color = dataColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _StripedMiniTrackPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.dataColor != dataColor ||
        oldDelegate.theme != theme ||
        oldDelegate.scale != scale;
  }
}

/// 层叠列布局：后一张卡片在布局上上移 [overlap]，覆盖前一张卡片底部。
/// 与 Transform 平移不同，布局高度天然紧凑（不残留尾部空白），
/// 绘制顺序为 children 顺序（后者覆盖前者），命中测试随之正确。
class _ShiftedColumn extends MultiChildRenderObjectWidget {
  /// 相邻卡片间的层叠覆盖距离
  final double overlap;

  const _ShiftedColumn({required this.overlap, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderShiftedColumn(overlap: overlap);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderShiftedColumn renderObject,
  ) {
    renderObject.overlap = overlap;
  }
}

class _RenderShiftedColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, StackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, StackParentData> {
  _RenderShiftedColumn({required double overlap}) : _overlap = overlap;

  double _overlap;

  set overlap(double value) {
    if (_overlap != value) {
      _overlap = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StackParentData) {
      child.parentData = StackParentData();
    }
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    var y = 0.0;
    var width = 0.0;
    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      child.layout(constraints.loosen(), parentUsesSize: true);
      (child.parentData as StackParentData).offset = Offset(0, y);
      width = math.max(width, child.size.width);
      y += child.size.height;
      // 非最后一张卡片：下一张向上层叠覆盖其底部
      if (i < children.length - 1) {
        y -= _overlap;
      }
    }
    size = constraints.constrain(Size(width, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
