/// 切角统计网格卡片小组件（手绘纸卡风格）
///
/// 手绘纸卡（纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场）：
/// 左上液体切角装饰与圆形图标徽章保留（数据色实底 + 墨线描边）。
library;

import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/utils/icon_utils.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

class CutoutStatItemData {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;

  const CutoutStatItemData({
    required this.label,
    required this.value,
    this.unit = '',
    required this.icon,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    this.iconColor = const Color(0xFF222222),
  });
}

class CutoutStatGridCardWidget extends StatefulWidget {
  final String title;
  final List<CutoutStatItemData> items;
  final Color? backgroundColor;
  final bool inline;
  final HomeWidgetSize size;

  /// 自定义头部行：非空时替代 [title] 文本行（如日卡日期头）
  final Widget? header;

  /// 自定义内容：非空时替代统计项网格
  final Widget? child;

  /// 整卡填色模式（日卡用）：整卡以该数据色实底呈现，
  /// 左上角液体咬角（透出下层背景）并叠加 [icon] 圆形徽章，
  /// [header]/[child] 直接铺在色底上（参考切角统计卡效果图）
  final Color? accentColor;

  /// accent 模式的左上角圆形徽章图标
  final IconData? icon;

  const CutoutStatGridCardWidget({
    super.key,
    this.title = '',
    this.items = const [],
    this.backgroundColor,
    this.inline = false,
    this.size = const Large3Size(),
    this.header,
    this.child,
    this.accentColor,
    this.icon,
  });

  factory CutoutStatGridCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((item) {
            if (item is CutoutStatItemData) return item;
            final map = item is Map ? item : const <String, dynamic>{};
            return CutoutStatItemData(
              label: map['label'] as String? ?? '',
              value: map['value']?.toString() ?? '0',
              unit: map['unit'] as String? ?? '',
              icon: _parseIcon(map['icon'], Icons.school_rounded),
              backgroundColor: _parseColor(
                map['backgroundColor'],
                const Color(0xFFC8B9EC),
              ),
              iconBackgroundColor: _parseColor(
                map['iconBackgroundColor'],
                const Color(0xFFDCD2F5),
              ),
              iconColor: _parseColor(map['iconColor'], const Color(0xFF222222)),
            );
          }).toList()
        : <CutoutStatItemData>[];

    return CutoutStatGridCardWidget(
      title: props['title'] as String? ?? '',
      items: items,
      backgroundColor: props['backgroundColor'] == null
          ? null
          : _parseColor(props['backgroundColor'], const Color(0xFFEEF2F5)),
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CutoutStatGridCardWidget> createState() =>
      _CutoutStatGridCardWidgetState();
}

class _CutoutStatGridCardWidgetState extends State<CutoutStatGridCardWidget> {
  double get _height {
    final scale = widget.size.scale;
    if (widget.size is Large3Size) return 340 * scale;
    return 240 * scale;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = widget.size.scale;
    // 切角装饰颜色 = 实际卡底色（props 数据色可空 → 纸底）
    final backgroundColor = widget.backgroundColor ?? theme.surface;
    // accent 色降饱和调浅：亮色模式混白、暗色模式混黑，
    // 保留色调的同时保证卡内墨色文字可读（插件原色多高饱和）
    final accent =
        widget.accentColor == null
            ? null
            : theme.isDark
            ? Color.lerp(widget.accentColor!, Colors.black, 0.40)!
            : Color.lerp(widget.accentColor!, Colors.white, 0.55)!;
    final accentMode = accent != null;
    final p = widget.size.getPadding();

    // 普通模式头部行：优先自定义 header，否则回落 title 文本
    final Widget? titleWidget = accentMode
        ? null
        : widget.header ??
              (widget.title.isNotEmpty
                  ? Text(
                      widget.title,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: widget.size.getTitleFontSize(),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null);

    Widget content = accentMode
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // header 与徽章同行（徽章右侧），child 铺满其余空间
              if (widget.header != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(58 * scale, 8 * scale, p.left, 0),
                  child: widget.header!,
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    p.left,
                    widget.header != null ? 10 * scale : 62 * scale,
                    p.right,
                    p.bottom,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titleWidget != null) ...[
                titleWidget,
                SizedBox(height: 14 * scale),
              ],
              Expanded(
                child:
                    widget.child ??
                    Row(
                      children: [
                        for (
                          var index = 0;
                          index < widget.items.length;
                          index++
                        ) ...[
                          if (index > 0) SizedBox(width: 9 * scale),
                          Expanded(
                            child: _CutoutStatItem(
                              data: widget.items[index],
                              cutoutColor: backgroundColor,
                              size: widget.size,
                            ),
                          ),
                        ],
                      ],
                    ),
              ),
            ],
          );

    // 手绘纸卡：纸底 + 淡排线 + rough 墨线框，WiredDraw 描画入场
    Widget card = DsSketchPanel(
      theme: theme,
      width: widget.inline ? double.maxFinite : 384 * scale,
      height: widget.inline ? double.maxFinite : _height,
      radius: BorderRadius.circular(24 * scale),
      // accent 模式自管内边距（切角/徽章须贴卡片左上角）
      padding: accentMode ? EdgeInsets.zero : p,
      fillColor: accentMode ? accent : widget.backgroundColor,
      // accent 模式纯色平涂（同统计项色块），不叠排线
      hachure: !accentMode,
      // 圆角裁剪内容层（滚动列表不越过圆角），墨线/排线层不受影响
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (accentMode) {
      // 整卡（含墨线描边）裁掉左上咬角：咬角处透出下层页面底色，
      // 描边在咬角处自然断开；圆形图标徽章叠在裁剪层外
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipPath(
              clipper: _CutoutNotchClipper(scale: scale),
              child: card,
            ),
          ),
          if (widget.icon != null)
            Positioned(
              top: 5 * scale,
              left: 5 * scale,
              child: Container(
                width: 43 * scale,
                height: 43 * scale,
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  fillColor: theme.surface,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: widget.icon!,
                    size: 23 * scale,
                    color: theme.text,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return WiredDraw(child: card);
  }
}

/// 日卡日期头部（[CutoutStatGridCardWidget] accent 模式的配套组件）
///
/// 直接铺在整卡数据色底上：左侧周几+日期，右侧可选摘要文本、
/// 计数徽标和＋新建按钮。文字用墨色（色底上保持可读）。
class CutoutDayCardHeader extends StatelessWidget {
  /// 数据色（计数徽标文字由此派生）
  final Color color;

  /// 卡片对应日期
  final DateTime date;

  /// 计数徽标（null 时不显示）
  final int? count;

  /// 右侧摘要文本（如收支汇总，null 时不显示）
  final String? summary;

  /// ＋新建回调（null 时不显示按钮）
  final VoidCallback? onAdd;

  const CutoutDayCardHeader({
    super.key,
    required this.color,
    required this.date,
    this.count,
    this.summary,
    this.onAdd,
  });

  static const List<String> _dayNames = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);

    return Row(
      children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayNames[date.weekday - 1],
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${date.month}/${date.day}',
                style: TextStyle(
                  color: theme.text.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (summary != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      child: Text(
                        summary!,
                        style: TextStyle(
                          color: theme.text.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    // 计数徽章:卡底色实底小胶囊，数据色文字
                    decoration: dsSketchDecoration(
                      theme: theme,
                      fillColor: theme.surface,
                      radius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (onAdd != null)
                  GestureDetector(
                    onTap: onAdd,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: DsIcon(
                        DsIconKind.plus,
                        size: 18,
                        color: theme.text,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CutoutStatItem extends StatelessWidget {
  final CutoutStatItemData data;
  final Color cutoutColor;
  final HomeWidgetSize size;

  const _CutoutStatItem({
    required this.data,
    required this.cutoutColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scale = size.scale;
    // 数据色实底 + 墨线描边（小控件档）
    return Container(
      decoration: dsSketchDecoration(
        theme: theme,
        radius: BorderRadius.circular(26 * scale),
        fillColor: data.backgroundColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26 * scale),
        child: Stack(
          children: [
            // 液体切角装饰（内容层，保留）
            Positioned(
              top: 0,
              left: 0,
              child: SizedBox(
                width: 66 * scale,
                height: 66 * scale,
                child: CustomPaint(
                  painter: _CutoutCornerPainter(
                    color: cutoutColor,
                    scale: scale,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5 * scale,
              left: 5 * scale,
              child: Container(
                width: 43 * scale,
                height: 43 * scale,
                decoration: dsSketchDecoration(
                  theme: theme,
                  circle: true,
                  fillColor: data.iconBackgroundColor,
                ),
                child: Center(
                  child: WiredIcon(
                    icon: data.icon,
                    size: 23 * scale,
                    color: data.iconColor,
                    drawConfig: theme.wired.drawConfig,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12 * scale,
                  62 * scale,
                  12 * scale,
                  13 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: size.getSubtitleFontSize(),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: data.value,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: size.getTitleFontSize() * 1.15,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          if (data.unit.isNotEmpty)
                            TextSpan(
                              text: ' ${data.unit}',
                              style: TextStyle(
                                color: theme.textSub,
                                fontSize: size.getLegendFontSize(),
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 左上液体切角形状：rrect 主体 + 两处曲线补块（painter 与 clipper 共用，
/// 保证咬角裁剪与装饰绘制完全同形）
Path _cutoutNotchPath(double scale) {
  final side = 50 * scale;
  final curve = 16 * scale;
  Path shape = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, side, side),
        bottomRight: Radius.circular(26 * scale),
      ),
    );
  for (final rect in [
    Rect.fromLTWH(side, 0, curve, curve),
    Rect.fromLTWH(0, side, curve, curve),
  ]) {
    // 补块 = rect 减去内切圆（月牙形）；不能用 even-odd——圆超出 rect
    // 的部分会被误并入形状，union 后在边缘多出圆形缺口
    final patch = Path()..addRect(rect);
    final hole = Path()
      ..addOval(Rect.fromCircle(center: rect.bottomRight, radius: curve));
    shape = Path.combine(
      PathOperation.union,
      shape,
      Path.combine(PathOperation.difference, patch, hole),
    );
  }
  return shape;
}

/// 按切角形状裁掉卡片左上角（咬角处透出下层，描边断开）
class _CutoutNotchClipper extends CustomClipper<Path> {
  final double scale;

  const _CutoutNotchClipper({required this.scale});

  @override
  Path getClip(Size size) {
    final card =
        Path()..addRRect(
          RRect.fromRectAndCorners(
            Offset.zero & size,
            topLeft: Radius.circular(24 * scale),
            topRight: Radius.circular(24 * scale),
            bottomLeft: Radius.circular(24 * scale),
            bottomRight: Radius.circular(24 * scale),
          ),
        );
    return Path.combine(
      PathOperation.difference,
      card,
      _cutoutNotchPath(scale),
    );
  }

  @override
  bool shouldReclip(covariant _CutoutNotchClipper oldDelegate) {
    return oldDelegate.scale != scale;
  }
}

class _CutoutCornerPainter extends CustomPainter {
  final Color color;
  final double scale;

  const _CutoutCornerPainter({required this.color, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_cutoutNotchPath(scale), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CutoutCornerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scale != scale;
  }
}

Color _parseColor(dynamic value, Color fallback) {
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    try {
      final hex = value.startsWith('#')
          ? value.substring(1)
          : value.startsWith('0x')
          ? value.substring(2)
          : '';
      if (hex.length == 6) {
        return Color(0xFF000000 | int.parse(hex, radix: 16));
      }
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }
  return fallback;
}

IconData _parseIcon(dynamic value, IconData fallback) {
  if (value is IconData) return value;
  final codePoint = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  if (codePoint == null) return fallback;
  return dynamicIconData(codePoint, fontFamily: 'MaterialIcons');
}
