import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

/// 堆叠文件夹卡片变体
enum StackedFolderVariant { gallery, notes, drafts }

const double _deg = math.pi / 180;

/// 背面文档的微型规格栏数据（标题 + 线条宽度列表）
const List<(String?, List<double>)> _microGroups = [
  ('SATUCADERE SOCIOGAOR', [18.0, 22.0, 19.0, 24.0]),
  ('SFA2 3300ept', [15.0, 12.0, 14.0, 16.0, 26.0, 20.0]),
  (null, [21.0, 18.0, 19.0]),
];

/// 堆叠文件夹卡片
///
/// 上方为层叠内容（照片 / 便签 / 文档，各自带旋转角度与阴影），
/// 底部为白色口袋卡片（标题 + 副标题 + 圆形箭头按钮）。
/// 点击卡片或悬停时层叠内容扇出展开（fan-out），与参考 HTML 的交互一致。
class StackedFolderCardWidget extends StatefulWidget {
  /// 口袋卡片标题
  final String title;

  /// 口袋卡片副标题（如 '15 photos'）
  final String subtitle;

  /// 层叠内容变体
  final StackedFolderVariant variant;

  /// gallery 变体的照片地址，顺序为 [背面, 中间, 正面]
  final List<String> photos;

  /// notes 变体背面便签的文本行
  final List<String> noteBackLines;

  /// notes 变体正面便签的文本行
  final List<String> noteFrontLines;

  /// drafts 变体正面文档的标题
  final String docHeading;

  /// drafts 变体正面文档的元信息行
  final List<String> docMetaLines;

  /// drafts 变体正面文档的正文段落
  final List<String> docBodyParagraphs;

  /// 箭头按钮点击回调，null 时点击切换扇出状态
  final VoidCallback? onOpen;

  /// 卡片整体点击回调，null 时点击切换扇出状态
  final VoidCallback? onCardTap;

  /// 是否为内联模式（内联模式使用 double.maxFinite，非内联模式使用固定尺寸）
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const StackedFolderCardWidget({
    super.key,
    this.title = 'Gallery',
    this.subtitle = '15 photos',
    this.variant = StackedFolderVariant.gallery,
    this.photos = const [],
    this.noteBackLines = const [],
    this.noteFrontLines = const [],
    this.docHeading = 'Creative Brief',
    this.docMetaLines = const [],
    this.docBodyParagraphs = const [],
    this.onOpen,
    this.onCardTap,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  factory StackedFolderCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final variant = switch (props['variant']) {
      'notes' => StackedFolderVariant.notes,
      'drafts' => StackedFolderVariant.drafts,
      _ => StackedFolderVariant.gallery,
    };
    final defaultTitle = switch (variant) {
      StackedFolderVariant.gallery => 'Gallery',
      StackedFolderVariant.notes => 'Quick Notes',
      StackedFolderVariant.drafts => 'Drafts',
    };
    final defaultSubtitle = switch (variant) {
      StackedFolderVariant.gallery => '15 photos',
      StackedFolderVariant.notes => '7 notes',
      StackedFolderVariant.drafts => '4 files',
    };
    List<String> parseLines(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    return StackedFolderCardWidget(
      title: props['title'] as String? ?? defaultTitle,
      subtitle: props['subtitle'] as String? ?? defaultSubtitle,
      variant: variant,
      photos: parseLines(props['photos']),
      noteBackLines: parseLines(props['noteBackLines']),
      noteFrontLines: parseLines(props['noteFrontLines']),
      docHeading: props['docHeading'] as String? ?? 'Creative Brief',
      docMetaLines: parseLines(props['docMetaLines']),
      docBodyParagraphs: parseLines(props['docBodyParagraphs']),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<StackedFolderCardWidget> createState() =>
      _StackedFolderCardWidgetState();
}

class _StackedFolderCardWidgetState extends State<StackedFolderCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 点击后的激活状态（对应 HTML 的 is-active）
  bool _active = false;

  /// 桌面端悬停状态
  bool _hover = false;

  /// 箭头按钮悬停
  bool _btnHover = false;

  /// 是否扇出展开
  bool get _fanned => _active || _hover;

  static const _fanDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _defaultHeight() {
    final scale = widget.size.scale;
    if (widget.size is SmallSize) return 110 * scale;
    if (widget.size is MediumSize || widget.size is WideSize) {
      return 190 * scale;
    }
    if (widget.size is Wide2Size) return 210 * scale;
    if (widget.size is LargeSize) return 390 * scale;
    return 410 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content =
        widget.size is SmallSize ? _buildCompact(isDark) : _buildFull(isDark);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: widget.inline ? double.maxFinite : 320 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        child: content,
      ),
    );
  }

  /// 完整设计稿：320x410 内按绝对定位摆放层叠内容与口袋卡片
  Widget _buildFull(bool isDark) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 320,
          height: 410,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.onCardTap != null) {
                widget.onCardTap!();
              } else {
                setState(() => _active = !_active);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ..._buildLayers(isDark),
                if (widget.variant == StackedFolderVariant.gallery)
                  _galleryRing(),
                _pocket(isDark),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// 小尺寸精简版：仅保留口袋卡片
  Widget _buildCompact(bool isDark) {
    final scale = widget.size.scale;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.onCardTap != null) {
            widget.onCardTap!();
          } else {
            setState(() => _active = !_active);
          }
        },
        child: Container(
          width: 170 * scale,
          height: 96 * scale,
          padding: EdgeInsets.all(14 * scale),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24 * scale),
            boxShadow: _pocketShadows(isDark),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  height: 1.15,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0E0E12),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 10.5 * scale,
                        fontWeight: FontWeight.w400,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1F1F26),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  _chevronButton(isDark, dimension: 26 * scale, iconSize: 14 * scale),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLayers(bool isDark) {
    return switch (widget.variant) {
      StackedFolderVariant.gallery => _buildGalleryLayers(isDark),
      StackedFolderVariant.notes => _buildNotesLayers(isDark),
      StackedFolderVariant.drafts => _buildDraftsLayers(isDark),
    };
  }

  // ============ Gallery：三张照片扇形堆叠 ============

  List<Widget> _buildGalleryLayers(bool isDark) {
    String? photo(int i) =>
        widget.photos.length > i ? widget.photos[i] : null;
    return [
      _layer(
        width: 214,
        height: 255,
        right: 10,
        bottom: 112,
        angle: 9.5 * _deg,
        fanOffset: const Offset(12, -18),
        fanAngle: 13 * _deg,
        index: 0,
        child: _photoCard(
          photo(0),
          isDark,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x1F000000),
              offset: const Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
      ),
      _layer(
        width: 222,
        height: 238,
        left: 44,
        bottom: 114,
        angle: -5.2 * _deg,
        fanOffset: const Offset(0, -22),
        fanAngle: -3.5 * _deg,
        index: 1,
        child: _photoCard(
          photo(1),
          isDark,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x24000000),
              offset: const Offset(-4, 10),
              blurRadius: 26,
            ),
          ],
        ),
      ),
      _layer(
        width: 215,
        height: 222,
        left: 12,
        bottom: 100,
        angle: -4.5 * _deg,
        fanOffset: const Offset(-10, -14),
        fanAngle: -7.5 * _deg,
        index: 2,
        child: _photoCard(
          photo(2),
          isDark,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.4) : const Color(0x29000000),
              offset: const Offset(-6, 12),
              blurRadius: 26,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _photoCard(String? url, bool isDark, {required List<BoxShadow> boxShadow}) {
    Widget placeholder() => Container(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E5EA),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            size: 36,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFFA8A8B3),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: boxShadow,
      ),
      child: url != null ? _buildImage(url, placeholder()) : placeholder(),
    );
  }

  /// 按图源前缀分发加载方式：
  /// - http(s):// 开头 → 网络图片
  /// - asset:// 或 assets/ 开头 → 资源图片
  /// - 其余 → 本地文件路径
  Widget _buildImage(String source, Widget placeholder) {
    if (source.startsWith('asset://')) {
      source = source.substring('asset://'.length);
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return Image.file(
      File(source),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  /// Gallery 口袋外围的粉彩渐变描边
  Widget _galleryRing() {
    return Positioned(
      left: -9,
      right: -9,
      bottom: -9,
      height: 190,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFD7BDFA), Color(0xFFC6D5FA), Color(0xFFBBE3F0)],
            ),
            borderRadius: BorderRadius.circular(45),
          ),
          child: SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFD7C0FC).withOpacity(0.35),
                    const Color(0xFFD2E0FA).withOpacity(0.25),
                    const Color(0xFFBEE8F5).withOpacity(0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(42.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============ Notes：两张等宽便签 ============

  List<Widget> _buildNotesLayers(bool isDark) {
    final backLines = widget.noteBackLines.isNotEmpty
        ? widget.noteBackLines
        : const ['Ideas for story:', 'Once upon a time in a...', 'Characters...'];
    final frontLines = widget.noteFrontLines.isNotEmpty
        ? widget.noteFrontLines
        : const [
            'To-Do List:',
            '1. Update project assets',
            '2. Call Mom at 6 PM',
            '3. Review design layout',
          ];
    return [
      _layer(
        width: 274,
        height: 200,
        left: 34,
        bottom: 242,
        angle: 4.8 * _deg,
        fanOffset: const Offset(6, -20),
        fanAngle: 7 * _deg,
        index: 0,
        child: _noteCard(
          backLines,
          isDark,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 25),
          fontSize: 17.5,
          lineHeight: 1.46,
        ),
      ),
      _layer(
        width: 320,
        height: 255,
        left: 0,
        bottom: 112,
        angle: 0,
        fanOffset: const Offset(0, -12),
        fanAngle: 0,
        index: 1,
        child: _noteCard(
          frontLines,
          isDark,
          radius: 36,
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
          fontSize: 17.2,
          lineHeight: 1.62,
          tinted: true,
        ),
      ),
    ];
  }

  Widget _noteCard(
    List<String> lines,
    bool isDark, {
    required double radius,
    required EdgeInsets padding,
    required double fontSize,
    required double lineHeight,
    bool tinted = false,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? (tinted ? const Color(0xFF263449) : const Color(0xFF334155))
            : (tinted ? const Color(0xFFEAEBF2) : Colors.white),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0B0F0F19),
            offset: const Offset(0, 10),
            blurRadius: 30,
          ),
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x060F0F19),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(
              line,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                height: lineHeight,
                letterSpacing: -0.4,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF16161C),
              ),
              overflow: TextOverflow.clip,
            ),
        ],
      ),
    );
  }

  // ============ Drafts：两张文档 ============

  List<Widget> _buildDraftsLayers(bool isDark) {
    return [
      _layer(
        width: 248,
        height: 292,
        right: 6,
        bottom: 118,
        angle: 9.2 * _deg,
        fanOffset: const Offset(12, -18),
        fanAngle: 12.5 * _deg,
        index: 0,
        child: _docBackCard(isDark),
      ),
      _layer(
        width: 250,
        height: 278,
        left: 10,
        bottom: 104,
        angle: -4.5 * _deg,
        fanOffset: const Offset(-8, -15),
        fanAngle: -6.8 * _deg,
        index: 1,
        child: _docFrontCard(isDark),
      ),
    ];
  }

  /// 背面文档：灰紫色边框 + 内嵌微型规格页
  Widget _docBackCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 21, 19, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBCCD6),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0F0F0F19),
            offset: const Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF7F7FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.15) : const Color(0x08000000),
              offset: const Offset(0, 1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HCS',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF232329),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 28,
                  height: 2,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFFB5B6C2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (title, widths) in _microGroups) ...[
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 4.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF454552),
                          ),
                        ),
                      ),
                    for (final w in widths)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: w,
                        height: 1.8,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFFB8B9C4),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 正面文档：Creative Brief
  Widget _docFrontCard(bool isDark) {
    final metaLines = widget.docMetaLines.isNotEmpty
        ? widget.docMetaLines
        : const ['Project: Brand Update', 'Goals: Increase engagement'];
    final bodyParagraphs = widget.docBodyParagraphs.isNotEmpty
        ? widget.docBodyParagraphs
        : const [
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed diamwo '
                'noniuno mradipat eeloidunt naionvoo diitum ooonunut noetum enim '
                'ad erinion louraineono evétuzaeo et eneettabuo volottciter uieirisl '
                'exiermct labortin ut inoituino nili aliquie ex ea commodo consequat.',
            'Cuale, increase engagement aon moseditate naveo catpatisoa '
                'costssantum ie ceatooss oveie ads uinm haoinia. Cinpam atant '
                'calipurtut in resspust. Ucbreen contaals is tit, praii ésio iis voleidant '
                'nalcuz eneia in vuca voorcheniartix. Zut colest, eioist biesnant ut '
                'anne ex alaumenaasu conserum.',
            'Project cilum dolorai arest, funolerum engagemas eute cortcultzot '
                '...nnosetevm iocalaiom, ut uitecoa oolopulatos',
          ];
    final headingStyle = TextStyle(
      fontSize: 13.2,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.26,
      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF18181F),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 23, 20, 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0E0F0F19),
            offset: const Offset(-6, 8),
            blurRadius: 24,
          ),
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x080F0F19),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.docHeading, style: headingStyle),
          const SizedBox(height: 11),
          for (final meta in metaLines)
            Text(
              meta,
              style: headingStyle.copyWith(
                fontSize: 13.1,
                letterSpacing: -0.33,
                height: 1.36,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 16),
          for (int i = 0; i < bodyParagraphs.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == bodyParagraphs.length - 1 ? 4 : 9),
              child: Text(
                bodyParagraphs[i],
                style: TextStyle(
                  fontSize: 6.5,
                  fontWeight: FontWeight.w400,
                  height: 1.44,
                  letterSpacing: -0.03,
                  color: isDark
                      ? const Color(0xFF94A3B8).withOpacity(
                          i == bodyParagraphs.length - 1 ? 0.75 : 1)
                      : const Color(0xFF383842).withOpacity(
                          i == bodyParagraphs.length - 1 ? 0.75 : 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ 公共部分：口袋卡片 / 层叠动画 ============

  List<BoxShadow> _pocketShadows(bool isDark) {
    return [
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x110F0F19),
        offset: const Offset(0, 18),
        blurRadius: 38,
      ),
      BoxShadow(
        color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x090F0F19),
        offset: const Offset(0, 4),
        blurRadius: 12,
      ),
    ];
  }

  /// 底部口袋卡片：标题 + 副标题 + 圆形箭头按钮
  Widget _pocket(bool isDark) {
    return Positioned(
      left: 0,
      bottom: 0,
      width: 320,
      height: 172,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 26, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: _pocketShadows(isDark),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.64,
                height: 1.15,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0E0E12),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 20.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.25,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1F1F26),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _chevronButton(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 圆形箭头按钮（悬停/扇出时加深底色、图标右移）
  Widget _chevronButton(bool isDark, {double dimension = 48, double iconSize = 18}) {
    final hovered = _btnHover || _fanned;
    return MouseRegion(
      onEnter: (_) => setState(() => _btnHover = true),
      onExit: (_) => setState(() => _btnHover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.onOpen != null) {
            widget.onOpen!();
          } else {
            setState(() => _active = !_active);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: dimension,
          height: dimension,
          decoration: BoxDecoration(
            color: isDark
                ? (hovered ? const Color(0xFF475569) : const Color(0xFF334155))
                : (hovered ? const Color(0xFFE2E2EA) : const Color(0xFFEBEBF0)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(hovered ? 2.0 : 0.0, 0, 0),
              child: Icon(
                Icons.chevron_right,
                size: iconSize,
                color: isDark
                    ? (hovered ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8))
                    : (hovered ? const Color(0xFF555562) : const Color(0xFF8C8C96)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 层叠内容通用包装：入场依次浮现 + 扇出时平移并改变角度
  Widget _layer({
    required double width,
    required double height,
    double? left,
    double? right,
    required double bottom,
    required double angle,
    required Offset fanOffset,
    required double fanAngle,
    required int index,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: _entrance(
        index,
        AnimatedContainer(
          duration: _fanDuration,
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: _fanned
              ? (Matrix4.translationValues(fanOffset.dx, fanOffset.dy, 0)
                ..rotateZ(fanAngle))
              : (Matrix4.translationValues(0, 0, 0)..rotateZ(angle)),
          child: child,
        ),
      ),
    );
  }

  /// 入场动画：依次淡入并上浮
  Widget _entrance(int index, Widget child) {
    final start = 0.12 + index * 0.14;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, math.min(start + 0.4, 1.0), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
