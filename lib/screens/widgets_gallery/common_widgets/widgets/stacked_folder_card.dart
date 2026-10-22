/// 堆叠文件夹卡片（手绘纸卡风格）
///
/// 上方为层叠内容（照片 / 便签 / 文档，均为手绘纸卡，各自带旋转角度），
/// 底部为口袋卡片（纸底 + 淡排线 + rough 墨线框）。整卡 WiredDraw 描画
/// 入场；点击卡片或悬停时层叠内容扇出展开（fan-out），交互与参考一致。
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
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
/// 上方为层叠内容（照片 / 便签 / 文档，各自带旋转角度），
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

  /// 正面便签实测高度（初值取原固定高度，首帧后由 _MeasureSize 更新），
  /// notes 变体据此联动口袋卡片位置
  double _frontNoteHeight = 255;

  /// 口袋卡片与正面便签底边的插入深度（小于便签底部 padding，不遮文字）
  static const double _pocketOverlap = 24;

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
    final theme = AppTheme.of(context);
    final content =
        widget.size is SmallSize ? _buildCompact(theme) : _buildFull(theme);

    // 手绘纸卡：WiredDraw 描画入场（层叠逐项浮现动画保留）
    return WiredDraw(
      child: SizedBox(
        width: widget.inline ? double.maxFinite : 320 * widget.size.scale,
        height: widget.inline ? double.maxFinite : _defaultHeight(),
        child: content,
      ),
    );
  }

  /// 完整设计稿：320x410 内按绝对定位摆放层叠内容与口袋卡片
  Widget _buildFull(AppThemeData theme) {
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
                ..._buildLayers(theme),
                if (widget.variant == StackedFolderVariant.gallery)
                  _galleryRing(theme),
                _pocket(theme),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// 小尺寸精简版：仅保留口袋卡片
  Widget _buildCompact(AppThemeData theme) {
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
        child: DsSketchPanel(
          theme: theme,
          width: 170 * scale,
          height: 96 * scale,
          radius: BorderRadius.circular(24 * scale),
          padding: EdgeInsets.all(14 * scale),
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
                  color: theme.text,
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
                        color: theme.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                  _chevronButton(
                    theme,
                    dimension: 26 * scale,
                    iconSize: 14 * scale,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLayers(AppThemeData theme) {
    return switch (widget.variant) {
      StackedFolderVariant.gallery => _buildGalleryLayers(theme),
      StackedFolderVariant.notes => _buildNotesLayers(theme),
      StackedFolderVariant.drafts => _buildDraftsLayers(theme),
    };
  }

  // ============ Gallery：三张照片扇形堆叠 ============

  List<Widget> _buildGalleryLayers(AppThemeData theme) {
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
        child: _photoCard(photo(0), theme),
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
        child: _photoCard(photo(1), theme),
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
        child: _photoCard(photo(2), theme),
      ),
    ];
  }

  Widget _photoCard(String? url, AppThemeData theme) {
    Widget placeholder() => Container(
          color: theme.surfaceAlt,
          alignment: Alignment.center,
          child: WiredIcon(
            icon: Icons.image_outlined,
            size: 36,
            color: theme.textSub,
            drawConfig: theme.wired.drawConfig,
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
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

  /// Gallery 口袋外围的手绘墨线装饰环（替代原粉彩渐变描边）
  Widget _galleryRing(AppThemeData theme) {
    return Positioned(
      left: -9,
      right: -9,
      bottom: -9,
      height: 190,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(45),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  // ============ Notes：两张等宽便签 ============

  List<Widget> _buildNotesLayers(AppThemeData theme) {
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
    // 便签顶边锚定、高度随文字行数自适应（不留白）；
    // 口袋卡片跟随正面便签底边（见 _pocket），保持插入深度 _pocketOverlap，
    // 该深度小于便签底部 padding，不会遮挡文字
    return [
      _layer(
        width: 274,
        left: 34,
        top: -32,
        angle: 4.8 * _deg,
        fanOffset: const Offset(6, -20),
        fanAngle: 7 * _deg,
        index: 0,
        child: _noteCard(
          backLines,
          theme,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(24, 25, 24, 25),
          fontSize: 17.5,
          lineHeight: 1.46,
        ),
      ),
      _layer(
        width: 320,
        left: 0,
        top: 43,
        angle: 0,
        fanOffset: const Offset(0, -12),
        fanAngle: 0,
        index: 1,
        child: _MeasureSize(
          onChange:
              (size) => setState(() => _frontNoteHeight = size.height),
          child: _noteCard(
            frontLines,
            theme,
            radius: 36,
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
            fontSize: 17.2,
            lineHeight: 1.62,
            tinted: true,
          ),
        ),
      ),
    ];
  }

  Widget _noteCard(
    List<String> lines,
    AppThemeData theme, {
    required double radius,
    required EdgeInsets padding,
    required double fontSize,
    required double lineHeight,
    bool tinted = false,
  }) {
    return DsSketchPanel(
      theme: theme,
      fillColor: tinted ? theme.surfaceAlt : theme.surface,
      radius: BorderRadius.circular(radius),
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                color: theme.text,
              ),
              overflow: TextOverflow.clip,
            ),
        ],
      ),
    );
  }

  // ============ Drafts：两张文档 ============

  List<Widget> _buildDraftsLayers(AppThemeData theme) {
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
        child: _docBackCard(theme),
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
        child: _docFrontCard(theme),
      ),
    ];
  }

  /// 背面文档：灰纸底 + 内嵌微型规格页
  Widget _docBackCard(AppThemeData theme) {
    return DsSketchPanel(
      theme: theme,
      fillColor: theme.surfaceAlt,
      radius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(19, 21, 19, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: dsSketchDecoration(
          theme: theme,
          radius: const BorderRadius.vertical(top: Radius.circular(4)),
          fillColor: theme.surface,
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
                    color: theme.text,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 28,
                  height: 2,
                  color: theme.ink.withValues(alpha: 0.4),
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
                            color: theme.textSub,
                          ),
                        ),
                      ),
                    for (final w in widths)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: w,
                        height: 1.8,
                        color: theme.ink.withValues(alpha: 0.35),
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
  Widget _docFrontCard(AppThemeData theme) {
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
      color: theme.text,
    );
    return DsSketchPanel(
      theme: theme,
      fillColor: theme.surface,
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(21, 23, 20, 18),
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
                  color: theme.textSub.withValues(
                    alpha: i == bodyParagraphs.length - 1 ? 0.75 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============ 公共部分：口袋卡片 / 层叠动画 ============

  /// 底部口袋卡片：标题 + 副标题 + 圆形箭头按钮（纸底 + 淡排线 + 墨线框）。
  /// notes 变体时跟随正面便签底边（top 锚定，保持 _pocketOverlap 插入深度），
  /// 其余变体固定贴底
  Widget _pocket(AppThemeData theme) {
    final double? pocketTop =
        widget.variant == StackedFolderVariant.notes
        ? 43 + _frontNoteHeight - _pocketOverlap
        : null;
    return Positioned(
      left: 0,
      top: pocketTop,
      bottom: pocketTop != null ? null : 0,
      width: 320,
      height: 172,
      child: DsSketchPanel(
        theme: theme,
        radius: BorderRadius.circular(36),
        padding: const EdgeInsets.fromLTRB(32, 32, 26, 28),
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
                color: theme.text,
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
                      color: theme.textSub,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _chevronButton(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 圆形箭头按钮（手绘圆底徽章，悬停/扇出时图标右移并加深）
  Widget _chevronButton(
    AppThemeData theme, {
    double dimension = 48,
    double iconSize = 18,
  }) {
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
        child: Container(
          width: dimension,
          height: dimension,
          decoration: dsSketchDecoration(
            theme: theme,
            radius: BorderRadius.circular(dimension / 2),
            fillColor: theme.surfaceAlt,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(hovered ? 2.0 : 0.0, 0, 0),
              child: DsIcon(
                DsIconKind.chevronRight,
                size: iconSize,
                color: hovered ? theme.text : theme.textSub,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 层叠内容通用包装：入场依次浮现 + 扇出时平移并改变角度。
  /// [height] 为 null 时高度由内容自适应；[top]/[bottom] 提供锚定边，
  /// 顶边锚定时高度向下生长，底边锚定时向上生长
  Widget _layer({
    required double width,
    double? height,
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double angle,
    required Offset fanOffset,
    required double fanAngle,
    required int index,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: top != null ? null : bottom,
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

/// 帧末测量子树尺寸，仅在尺寸变化时回调（用于便签高度联动口袋位置）
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _last;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size != _last) {
        _last = box.size;
        widget.onChange(box.size);
      }
    });
    return widget.child;
  }
}
