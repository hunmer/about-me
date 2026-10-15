import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:aboutme/screens/home_screen/models/home_widget_size.dart';

import 'cute_notepad_stickers.dart';
import 'cute_notepad_variants.dart';

/// 画布坐标系宽度（与网页版 viewBox 一致）
const double _kViewBoxWidth = 300;

/// 最小画布高度
const double _kMinViewBoxHeight = 300;

/// 自由文本行高（viewBox 单位）
const double _kFreeformLineHeight = 26;

/// 底部留白（保证底部贴纸不遮挡文字）
const double _kBottomClearance = 73;

/// 手写正文字号（viewBox 单位）
const double _kBodyFontSize = 15.2;

/// 手账手写字体（851 手写杂书体）
const String _kHandFont = 'TegakiZatsu';

/// 可爱手账便签卡片
///
/// 移植自 Cute Template Notepad：手绘便签底图（方格/格纹/波浪框/撕边/活页孔等
/// 16 种风格预设）+ 可爱贴纸（flutter_svg 渲染）+ 手写标题/正文/待办内容。
/// 高度随内容自动撑开（viewBox 300×H），单一组件入口，通过 [variant] 切换风格。
class CuteNotepadCardWidget extends StatefulWidget {
  /// 风格预设
  final CuteNotepadVariant variant;

  /// 覆盖标题（null 使用预设标题，空串隐藏标题）
  final String? title;

  /// 自由文本内容（freeform 类型）
  final String? text;

  /// 待办/横线行（null 使用预设空白行）
  final List<CuteNotepadTodoItem>? items;

  /// 是否为内联模式
  final bool inline;

  /// 组件尺寸
  final HomeWidgetSize size;

  const CuteNotepadCardWidget({
    super.key,
    required this.variant,
    this.title,
    this.text,
    this.items,
    this.inline = false,
    this.size = const Large3Size(),
  });

  /// 从 props 创建实例
  ///
  /// - style: 风格 id（如 'pinkGridBunny'）或序号 0~15，缺省用第一种
  /// - title / text / items: 覆盖预设内容
  factory CuteNotepadCardWidget.fromProps(
    Map<String, dynamic> props,
    HomeWidgetSize size,
  ) {
    final variant =
        props['variant'] is CuteNotepadVariant
            ? props['variant']! as CuteNotepadVariant
            : resolveCuteNotepadVariant(props['style']);

    List<CuteNotepadTodoItem>? items;
    final itemsData = props['items'];
    if (itemsData is List) {
      items =
          itemsData.map((e) {
            if (e is Map) {
              return CuteNotepadTodoItem(
                checked: e['checked'] == true,
                text: e['text']?.toString() ?? '',
              );
            }
            return const CuteNotepadTodoItem();
          }).toList();
    }

    return CuteNotepadCardWidget(
      variant: variant,
      title: props['title'] as String?,
      text: props['text'] as String?,
      items: items,
      inline: props['inline'] as bool? ?? false,
      size: size,
    );
  }

  @override
  State<CuteNotepadCardWidget> createState() => _CuteNotepadCardWidgetState();
}

class _CuteNotepadCardWidgetState extends State<CuteNotepadCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final title = widget.title ?? variant.title ?? '';
    final text = widget.text ?? '';
    final items = widget.items ?? variant.items;
    final layout = _NoteLayoutEngine.compute(variant, title, text, items);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animation.value)),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: widget.inline ? double.maxFinite : 384 * widget.size.scale,
        child: AspectRatio(
          aspectRatio: _kViewBoxWidth / layout.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final unit = constraints.maxWidth / _kViewBoxWidth;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CuteNotepadPainter(
                        variant: variant,
                        layout: layout,
                      ),
                    ),
                  ),
                  for (int i = 0; i < variant.stickers.length; i++)
                    _buildSticker(variant.stickers[i], layout.height, unit, i),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 按锚点方位计算贴纸在 viewBox 坐标系中的位置
  Offset _stickerOffset(CuteNotepadSticker st, double canvasHeight) {
    const margin = 10.0;
    late double baseX;
    late double baseY;
    switch (st.anchor) {
      case CuteNotepadStickerAnchor.topLeft:
        baseX = margin;
        baseY = margin;
      case CuteNotepadStickerAnchor.topCenter:
        baseX = (_kViewBoxWidth - st.w) / 2;
        baseY = 4;
      case CuteNotepadStickerAnchor.topRight:
        baseX = _kViewBoxWidth - st.w - margin;
        baseY = margin;
      case CuteNotepadStickerAnchor.bottomLeft:
        baseX = margin;
        baseY = canvasHeight - st.h - margin;
      case CuteNotepadStickerAnchor.bottomRight:
        baseX = _kViewBoxWidth - st.w - margin;
        baseY = canvasHeight - st.h - margin;
      case CuteNotepadStickerAnchor.center:
        baseX = (_kViewBoxWidth - st.w) / 2;
        baseY = (canvasHeight - st.h) / 2;
    }
    return Offset(baseX + st.dx, baseY + st.dy);
  }

  Widget _buildSticker(
    CuteNotepadSticker sticker,
    double canvasHeight,
    double unit,
    int index,
  ) {
    final pos = _stickerOffset(sticker, canvasHeight);
    // 贴纸依次弹性弹出
    final begin = math.min(0.35 + index * 0.07, 0.85);
    final pop = CurvedAnimation(
      parent: _animationController,
      curve: Interval(begin, math.min(begin + 0.45, 1.0),
          curve: Curves.easeOutBack),
    );

    return Positioned(
      left: pos.dx * unit,
      top: pos.dy * unit,
      width: sticker.w * unit,
      height: sticker.h * unit,
      child: AnimatedBuilder(
        animation: pop,
        builder: (context, child) {
          return Transform.scale(scale: pop.value.clamp(0.0, 1.2), child: child);
        },
        child: SvgPicture.string(
          cuteNotepadStickerSvg(sticker.asset),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 布局引擎（移植网页版 computeNoteLayout：按内容计算画布高度与各行坐标）
// ---------------------------------------------------------------------------

/// 单条待办/横线行的布局
class _NoteItemLayout {
  final int itemIndex;
  final double top;
  final double height;
  final List<double> underlineYs;
  final bool checked;
  final TextPainter? painter;
  final double textLeft;

  const _NoteItemLayout({
    required this.itemIndex,
    required this.top,
    required this.height,
    required this.underlineYs,
    required this.checked,
    this.painter,
    required this.textLeft,
  });
}

/// 整张便签的布局结果
class _NoteLayout {
  final double height;

  final TextPainter? titlePainter;
  final Offset titleOffset;
  final double titleRotateRad;
  final Offset titleRotateOrigin;

  final TextPainter? freeformPainter;
  final Offset freeformOffset;

  final List<_NoteItemLayout> itemLayouts;
  final bool hasCheck;

  const _NoteLayout({
    required this.height,
    this.titlePainter,
    this.titleOffset = Offset.zero,
    this.titleRotateRad = 0,
    this.titleRotateOrigin = Offset.zero,
    this.freeformPainter,
    this.freeformOffset = Offset.zero,
    required this.itemLayouts,
    required this.hasCheck,
  });
}

class _NoteLayoutEngine {
  static _NoteLayout compute(
    CuteNotepadVariant variant,
    String title,
    String text,
    List<CuteNotepadTodoItem> items,
  ) {
    var curY = variant.contentStartY;
    final spacing = variant.lineSpacing;

    final hasCheck =
        variant.type == CuteNotepadNoteType.checklist ||
        variant.type == CuteNotepadNoteType.freeform ||
        variant.showChecksOnLined;
    final lineX1 = hasCheck ? 62.0 : (variant.lineX1 ?? 36.0);
    final lineX2 = variant.lineX2 ?? 252.0;
    final textLeft = hasCheck ? 63.0 : lineX1 + 2;
    final textWidth = lineX2 - textLeft;

    // 1. 标题
    TextPainter? titlePainter;
    Offset titleOffset = Offset.zero;
    double titleRotateRad = 0;
    Offset titleRotateOrigin = Offset.zero;
    final tp = variant.titlePos;
    if (title.isNotEmpty && tp != null) {
      titlePainter = _textPainter(
        title,
        fontSize: tp.fontSize,
        lineHeight: tp.fontSize * 1.15,
        maxWidth: tp.width,
        color: variant.textColor,
        weight: FontWeight.w700,
        align: tp.center ? TextAlign.center : TextAlign.left,
      );
      // 网页版文字基线在 top + 17，近似换算为绘制顶部
      titleOffset = Offset(tp.left, tp.top + 17 - tp.fontSize * 0.8);
      if (tp.rotate != 0) {
        titleRotateRad = tp.rotate * math.pi / 180;
        titleRotateOrigin = Offset(tp.left + 20, tp.top + 14);
      }
    }

    // 2. 自由文本区
    TextPainter? freeformPainter;
    Offset freeformOffset = Offset.zero;
    if (variant.type == CuteNotepadNoteType.freeform) {
      final minLines = items.isEmpty ? variant.minFreeformLines : 2;
      var lines = minLines;
      if (text.isNotEmpty) {
        freeformPainter = _textPainter(
          text,
          fontSize: 15.5,
          lineHeight: _kFreeformLineHeight,
          maxWidth: variant.freeformWidth - 4,
          color: variant.textColor,
        );
        lines = math.max(minLines, freeformPainter.computeLineMetrics().length);
      }
      freeformOffset = Offset(variant.freeformLeft + 2, curY + 1);
      curY += lines * _kFreeformLineHeight + (items.isNotEmpty ? 6 : 0);
    }

    // 3. 待办/横线行
    final itemLayouts = <_NoteItemLayout>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      TextPainter? painter;
      var lineCount = 1;
      if (item.text.isNotEmpty) {
        painter = _textPainter(
          item.text,
          fontSize: _kBodyFontSize,
          lineHeight: spacing,
          maxWidth: textWidth - 4,
          color: item.checked
              ? variant.textColor.withOpacity(0.6)
              : variant.textColor,
          lineThrough: item.checked,
        );
        lineCount = math.max(1, painter.computeLineMetrics().length);
      }
      final top = curY;
      final height = lineCount * spacing;
      final underlineYs = List<double>.generate(
        lineCount,
        (l) => top + (l + 1) * spacing - 8,
      );
      itemLayouts.add(
        _NoteItemLayout(
          itemIndex: i,
          top: top,
          height: height,
          underlineYs: underlineYs,
          checked: item.checked,
          painter: painter,
          textLeft: textLeft,
        ),
      );
      curY += height;
    }

    final height = math.max(
      _kMinViewBoxHeight,
      (curY + _kBottomClearance).ceilToDouble(),
    );

    return _NoteLayout(
      height: height,
      titlePainter: titlePainter,
      titleOffset: titleOffset,
      titleRotateRad: titleRotateRad,
      titleRotateOrigin: titleRotateOrigin,
      freeformPainter: freeformPainter,
      freeformOffset: freeformOffset,
      itemLayouts: itemLayouts,
      hasCheck: hasCheck,
    );
  }

  static TextPainter _textPainter(
    String text, {
    required double fontSize,
    required double lineHeight,
    required double maxWidth,
    required Color color,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.left,
    bool lineThrough = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _kHandFont,
          fontSize: fontSize,
          height: lineHeight / fontSize,
          color: color,
          fontWeight: weight,
          decoration: lineThrough ? TextDecoration.lineThrough : null,
          decorationColor: color,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }
}

// ---------------------------------------------------------------------------
// 便签画笔（底图 + 复选框 + 手绘底线 + 文字，viewBox 300×H 坐标系）
// ---------------------------------------------------------------------------

class _CuteNotepadPainter extends CustomPainter {
  final CuteNotepadVariant variant;
  final _NoteLayout layout;

  _CuteNotepadPainter({required this.variant, required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _kViewBoxWidth);
    final h = layout.height;

    _paintBackground(canvas, h);
    _paintItems(canvas);
    _paintTexts(canvas);

    canvas.restore();
  }

  // ---- 底图 ----

  void _paintBackground(Canvas canvas, double h) {
    switch (variant.background) {
      case CuteNotepadBackground.gridPaper:
        _paper(canvas, h, radius: 6, stroke: true);
        _grid(
          canvas,
          rect: Rect.fromLTRB(14, 14, 280, h - 20),
          step: variant.gridStep,
        );
      case CuteNotepadBackground.wavyInner:
        _paper(canvas, h, radius: 8, stroke: true);
        _fillPath(
          canvas,
          _wavyRectPath(22, 24, 272, h - 30, 3),
          variant.innerFillColor,
        );
      case CuteNotepadBackground.plain:
        _paper(canvas, h, radius: 6, stroke: true);
      case CuteNotepadBackground.innerRoundFrame:
        _paper(canvas, h, radius: 8, stroke: false);
        _innerRoundRect(canvas, h);
      case CuteNotepadBackground.waveTopHeader:
        _paper(canvas, h, radius: 6, stroke: true);
        _waveTopHeader(canvas);
      case CuteNotepadBackground.leftBinderHoles:
        _paper(canvas, h, radius: 5, stroke: true);
        for (double cy = 42; cy <= h - 36; cy += 36) {
          _leftHole(canvas, cy);
        }
      case CuteNotepadBackground.plaidInnerRound:
        _paper(canvas, h, radius: 6, stroke: false);
        _plaid(canvas, Rect.fromLTRB(6, 6, 288, h - 12), variant.plaidStep);
        _strokeRect(canvas, Rect.fromLTRB(6, 6, 288, h - 12), 6,
            variant.paperStroke, 1.5);
        _fillRRect(
          canvas,
          RRect.fromRectAndRadius(
            Rect.fromLTRB(22, 22, 272, h - 28),
            const Radius.circular(28),
          ),
          variant.innerFillColor,
        );
      case CuteNotepadBackground.gridBanner:
        _paper(canvas, h, radius: 6, stroke: true);
        _grid(canvas, rect: Rect.fromLTRB(12, 12, 282, h - 18),
            step: variant.gridStep);
        _banner(canvas);
      case CuteNotepadBackground.tornEdge:
        final path = _tornEdgePath(h);
        _fillPath(canvas, path.shift(const Offset(4, 4)), variant.shadowColor);
        _fillPath(canvas, path, variant.paperColor);
        _strokePath(canvas, path, variant.paperStroke, 1.5);
      case CuteNotepadBackground.doubleWavyFrame:
        _paper(canvas, h, radius: 6, stroke: true);
        _strokePath(
          canvas,
          _wavyRectPath(21, 21, 273, h - 27, 3),
          variant.innerStrokeColor,
          2.2,
        );
        _strokePath(
          canvas,
          _wavyRectPath(24, 24, 270, h - 30, 2),
          variant.innerStroke2Color,
          1.2,
        );
      case CuteNotepadBackground.rightWaveEdge:
        final path = _rightWaveEdgePath(h);
        _fillPath(canvas, path.shift(const Offset(4, 4)), variant.shadowColor);
        _fillPath(canvas, path, variant.paperColor);
        _strokePath(canvas, path, variant.paperStroke, 1.5);
      case CuteNotepadBackground.plaidCloudFrame:
        _paper(canvas, h, radius: 6, stroke: false);
        _plaid(canvas, Rect.fromLTRB(6, 6, 288, h - 12), variant.plaidStep);
        _strokeRect(canvas, Rect.fromLTRB(6, 6, 288, h - 12), 6,
            variant.paperStroke, 1.5);
        _fillPath(canvas, _cloudFramePath(h), variant.innerFillColor);
        _strokePath(
          canvas,
          _cloudFramePath(h),
          variant.innerStrokeColor,
          2.2,
        );
      case CuteNotepadBackground.wavyFrame:
        _paper(canvas, h, radius: 6, stroke: true);
        _strokePath(
          canvas,
          _wavyRectPath(22, 22, 272, h - 28, 3),
          variant.innerStrokeColor,
          2.4,
        );
      case CuteNotepadBackground.topBinderHoles:
        _paper(canvas, h, radius: 5, stroke: true);
        for (var i = 0; i < 7; i++) {
          _topHole(canvas, 36.0 + i * 37);
        }
    }
  }

  /// 纸面：边影层 + 主纸面（纸面 y 偏移随风格有 6/10/12 三档）
  void _paper(Canvas canvas, double h,
      {required double radius, required bool stroke}) {
    final paperTop = variant.paperTop;
    final paperBottom = paperTop <= 6 ? h - 12 : h - 14;

    _fillRRect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTRB(10, paperTop + 4, 292, paperBottom + 4),
        Radius.circular(radius),
      ),
      variant.shadowColor,
    );
    _fillRRect(
      canvas,
      RRect.fromRectAndRadius(
        Rect.fromLTRB(6, paperTop, 288, paperBottom),
        Radius.circular(radius),
      ),
      variant.paperColor,
    );
    if (stroke && variant.paperStroke != null) {
      _strokeRRect(
        canvas,
        RRect.fromRectAndRadius(
          Rect.fromLTRB(6, paperTop, 288, paperBottom),
          Radius.circular(radius),
        ),
        variant.paperStroke,
        1.5,
      );
    }
  }

  /// 内嵌圆角框（04/14 号便签，两款的内框 y 略有差异）
  void _innerRoundRect(Canvas canvas, double h) {
    final low = variant.paperTop > 6;
    final rect = low
        ? Rect.fromLTRB(18, 22, 276, h - 26)
        : Rect.fromLTRB(18, 18, 276, h - 24);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    _fillRRect(canvas, rrect, variant.innerFillColor);
    _strokeRRect(canvas, rrect, variant.innerStrokeColor, 2.4);
  }

  /// 方格纸
  void _grid(Canvas canvas, {required Rect rect, required double step}) {
    final color = variant.gridColor;
    if (color == null) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var x = rect.left; x <= rect.right + 0.1; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (var y = rect.top; y <= rect.bottom + 0.1; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  /// 格纹纸（纵横半宽色带，叠色与网页版 pattern 一致）
  void _plaid(Canvas canvas, Rect rect, double step) {
    final band = variant.plaidBandColor;
    if (band == null) return;
    final paint = Paint()..color = band.withOpacity(0.55);
    for (var x = rect.left; x < rect.right; x += step) {
      canvas.drawRect(
        Rect.fromLTRB(x, rect.top, math.min(x + step / 2, rect.right),
            rect.bottom),
        paint,
      );
    }
    for (var y = rect.top; y < rect.bottom; y += step) {
      canvas.drawRect(
        Rect.fromLTRB(rect.left, y, rect.right,
            math.min(y + step / 2, rect.bottom)),
        paint,
      );
    }
  }

  /// 波浪顶栏 + 装饰短线（05 号便签）
  void _waveTopHeader(Canvas canvas) {
    final path = Path()
      ..moveTo(6, 12)
      ..quadraticBezierTo(6, 6, 12, 6)
      ..lineTo(282, 6)
      ..quadraticBezierTo(288, 6, 288, 12)
      ..lineTo(288, 32)
      ..quadraticBezierTo(265, 14, 242, 32)
      ..quadraticBezierTo(218, 14, 195, 32)
      ..quadraticBezierTo(172, 14, 148, 32)
      ..quadraticBezierTo(124, 14, 100, 32)
      ..quadraticBezierTo(76, 14, 52, 32)
      ..quadraticBezierTo(28, 14, 6, 32)
      ..close();
    _fillPath(canvas, path, variant.waveHeaderColor);
    _strokePath(canvas, path, variant.waveHeaderStroke, 1.8);

    final paint = Paint()
      ..color = variant.textColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(94, 42), const Offset(100, 38), paint);
    canvas.drawLine(const Offset(97, 50), const Offset(105, 49), paint);
    canvas.drawLine(const Offset(95, 58), const Offset(102, 61), paint);
  }

  /// 标题横幅（08 号便签）
  void _banner(Canvas canvas) {
    final path = Path()
      ..moveTo(56, 20)
      ..quadraticBezierTo(148, 18, 238, 20)
      ..quadraticBezierTo(242, 33, 238, 46)
      ..quadraticBezierTo(148, 48, 56, 46)
      ..quadraticBezierTo(53, 33, 56, 20)
      ..close();
    _fillPath(canvas, path, variant.bannerFillColor);
    _strokePath(canvas, path, variant.bannerStrokeColor, 2);
  }

  /// 左侧活页孔（06 号便签）
  void _leftHole(Canvas canvas, double cy) {
    _fillRect(canvas, Rect.fromLTRB(6, cy - 3.5, 20, cy + 3.5),
        variant.holeBgColor);
    canvas.drawCircle(
      Offset(23, cy),
      6.5,
      Paint()..color = variant.holeBgColor ?? Colors.white,
    );
    canvas.drawCircle(
      Offset(23, cy),
      6.5,
      Paint()
        ..color = variant.holeStrokeColor ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 顶部活页孔（16 号便签）
  void _topHole(Canvas canvas, double cx) {
    _fillRect(canvas, Rect.fromLTRB(cx - 3.5, 12, cx + 3.5, 26),
        variant.holeBgColor);
    canvas.drawCircle(
      Offset(cx, 28),
      6.2,
      Paint()..color = variant.holeBgColor ?? Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, 28),
      6.2,
      Paint()
        ..color = variant.holeStrokeColor ?? Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ---- 待办行（复选框 + 手绘底线） ----

  void _paintItems(Canvas canvas) {
    final linePaint = Paint()
      ..color = variant.lineColor
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lineX1 = layout.hasCheck ? 62.0 : (variant.lineX1 ?? 36.0);
    final lineX2 = variant.lineX2 ?? 252.0;

    for (final il in layout.itemLayouts) {
      // 手绘底线
      for (final uy in il.underlineYs) {
        canvas.drawLine(Offset(lineX1, uy), Offset(lineX2, uy), linePaint);
      }
      // 复选框
      if (layout.hasCheck) {
        _drawCheckbox(canvas, il.checked, il.underlineYs.first);
      }
    }
  }

  /// 复选框（box / heart / star / circle 四种手绘样式）
  void _drawCheckbox(Canvas canvas, bool checked, double y) {
    switch (variant.checkStyle) {
      case CuteNotepadCheckStyle.box:
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTRB(33, y - 13, 49, y + 3),
          const Radius.circular(3.5),
        );
        _fillRRect(canvas, rrect,
            checked ? const Color(0xFFFFD84D) : const Color(0xFFFFFBE8));
        _strokeRRect(canvas, rrect, const Color(0xFF7A5C43), 2.2);
        if (checked) {
          _checkMark(canvas, 36, y - 5, 40, y - 1, 46, y - 9,
              const Color(0xFF5E4227), 2.6);
        }
      case CuteNotepadCheckStyle.heart:
        final path = Path()
          ..moveTo(41, y - 9)
          ..cubicTo(41, y - 15, 32, y - 16, 32, y - 8)
          ..cubicTo(32, y - 2, 41, y + 3, 41, y + 6)
          ..cubicTo(41, y + 3, 50, y - 2, 50, y - 8)
          ..cubicTo(50, y - 16, 41, y - 15, 41, y - 9)
          ..close();
        _fillPath(canvas, path,
            checked ? const Color(0xFF68A83C) : const Color(0xFFA8D170));
        _strokePath(canvas, path, const Color(0xFF486B2B), 2);
        if (checked) {
          _checkMark(
              canvas, 37, y - 5, 40, y - 2, 46, y - 8, Colors.white, 2.2);
        }
      case CuteNotepadCheckStyle.star:
        final path = Path()
          ..moveTo(40, y - 16)
          ..lineTo(43, y - 10)
          ..lineTo(50, y - 9)
          ..lineTo(45, y - 4)
          ..lineTo(46, y + 3)
          ..lineTo(40, y - 1)
          ..lineTo(34, y + 3)
          ..lineTo(35, y - 4)
          ..lineTo(30, y - 9)
          ..lineTo(37, y - 10)
          ..close();
        _fillPath(canvas, path,
            checked ? const Color(0xFF5B8F3D) : const Color(0xFF94C476));
        _strokePath(canvas, path, const Color(0xFF466B30), 1.8);
        if (checked) {
          canvas.drawCircle(
            Offset(40, y - 6),
            2.8,
            Paint()..color = Colors.white,
          );
        }
      case CuteNotepadCheckStyle.circle:
        final center = Offset(41, y - 5);
        final fill = Paint()
          ..color = checked
              ? const Color(0xFFF5C242)
              : const Color(0xFFFFFBE8);
        canvas.drawCircle(center, 8, fill);
        canvas.drawCircle(
          center,
          8,
          Paint()
            ..color = const Color(0xFFDEB249)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        if (checked) {
          _checkMark(canvas, 37, y - 5, 40, y - 2, 46, y - 8,
              const Color(0xFF6B4922), 2.4);
        }
    }
  }

  void _checkMark(Canvas canvas, double x1, double y1, double x2, double y2,
      double x3, double y3, Color color, double width) {
    final path = Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2)
      ..lineTo(x3, y3);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
  }

  // ---- 文字 ----

  void _paintTexts(Canvas canvas) {
    // 标题（可带旋转）
    final titlePainter = layout.titlePainter;
    if (titlePainter != null) {
      canvas.save();
      if (layout.titleRotateRad != 0) {
        canvas.translate(
          layout.titleRotateOrigin.dx,
          layout.titleRotateOrigin.dy,
        );
        canvas.rotate(layout.titleRotateRad);
        canvas.translate(
          -layout.titleRotateOrigin.dx,
          -layout.titleRotateOrigin.dy,
        );
      }
      titlePainter.paint(canvas, layout.titleOffset);
      canvas.restore();
    }

    // 自由文本
    layout.freeformPainter?.paint(canvas, layout.freeformOffset);

    // 待办/横线行文本
    for (final il in layout.itemLayouts) {
      il.painter?.paint(canvas, Offset(il.textLeft + 3, il.top + 3));
    }
  }

  // ---- 基础绘制辅助 ----

  void _fillRRect(Canvas canvas, RRect rrect, Color? color) {
    if (color == null) return;
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  void _strokeRRect(Canvas canvas, RRect rrect, Color? color, double width) {
    if (color == null) return;
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  void _fillRect(Canvas canvas, Rect rect, Color? color) {
    if (color == null) return;
    canvas.drawRect(rect, Paint()..color = color);
  }

  void _strokeRect(Canvas canvas, Rect rect, double radius, Color? color,
      double width) {
    if (color == null) return;
    _strokeRRect(
      canvas,
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      color,
      width,
    );
  }

  void _fillPath(Canvas canvas, Path path, Color? color) {
    if (color == null) return;
    canvas.drawPath(path, Paint()..color = color);
  }

  void _strokePath(Canvas canvas, Path path, Color? color, double width) {
    if (color == null) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _CuteNotepadPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.layout.height != layout.height ||
        oldDelegate.layout != layout;
  }
}

// ---------------------------------------------------------------------------
// 手绘路径生成器（移植网页版 buildWavyRectPath / buildCloudFramePath 等）
// ---------------------------------------------------------------------------

/// 波浪边矩形（Q + T 平滑二次曲线，四边随 H 无缝延展）
Path _wavyRectPath(double x1, double y1, double x2, double y2,
    [double amp = 2.5]) {
  final midX = (x1 + x2) / 2;
  final midY = (y1 + y2) / 2;
  final path = Path()..moveTo(x1, y1);

  var current = Offset(x1, y1);
  Offset prevCtrl = Offset.zero;
  var hasCtrl = false;

  void quad(Offset ctrl, Offset end) {
    path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    prevCtrl = ctrl;
    current = end;
    hasCtrl = true;
  }

  void smooth(Offset end) {
    final ctrl = hasCtrl
        ? Offset(2 * current.dx - prevCtrl.dx, 2 * current.dy - prevCtrl.dy)
        : current;
    quad(ctrl, end);
  }

  quad(Offset((x1 + midX) / 2, y1 - amp), Offset(midX, y1));
  smooth(Offset(x2, y1));
  quad(Offset(x2 + amp, (y1 + midY) / 2), Offset(x2, midY));
  smooth(Offset(x2, y2));
  quad(Offset((x2 + midX) / 2, y2 + amp), Offset(midX, y2));
  smooth(Offset(x1, y2));
  quad(Offset(x1 - amp, (y2 + midY) / 2), Offset(x1, midY));
  smooth(Offset(x1, y1));

  return path..close();
}

/// 云朵波浪内框（13 号便签，随 H 增加侧边波浪弧度）
Path _cloudFramePath(double h) {
  const topY = 36.0, leftX = 34.0, rightX = 258.0;
  final botY = h - 42;
  final path = Path()..moveTo(leftX, topY);
  path.quadraticBezierTo(75, 22, 115, 32);
  path.quadraticBezierTo(150, 20, 185, 32);
  path.quadraticBezierTo(225, 22, rightX, topY);

  final sideSpan = math.max(72.0, botY - topY);
  final steps = math.max(3, (sideSpan / 70).round());
  final stepH = sideSpan / steps;
  for (var i = 0; i < steps; i++) {
    final yMid = topY + (i + 0.5) * stepH;
    final yNext = (topY + (i + 1) * stepH).roundToDouble();
    final bulge = i % 2 == 0 ? rightX + 14 : rightX + 12;
    path.quadraticBezierTo(bulge, yMid, rightX + (i % 2 == 0 ? 4 : 0), yNext);
  }

  path.quadraticBezierTo(220, botY + 14, 182, botY + 4);
  path.quadraticBezierTo(148, botY + 16, 112, botY + 4);
  path.quadraticBezierTo(72, botY + 14, leftX, botY);

  for (var i = steps - 1; i >= 0; i--) {
    final yMid = topY + (i + 0.5) * stepH;
    final yPrev = (topY + i * stepH).roundToDouble();
    final bulge = i % 2 == 0 ? leftX - 12 : leftX - 14;
    path.quadraticBezierTo(bulge, yMid, leftX - (i % 2 == 0 ? 0 : 2), yPrev);
  }

  return path..close();
}

/// 撕边锯齿纸（09 号便签）
Path _tornEdgePath(double h) {
  final path = Path()..moveTo(6, 24);
  for (var x = 6.0; x < 288; x += 8) {
    path.lineTo(x + 4, 19);
    path.lineTo(x + 8, 24);
  }
  path.lineTo(288, h - 14);
  path.quadraticBezierTo(288, h - 10, 284, h - 10);
  path.lineTo(10, h - 10);
  path.quadraticBezierTo(6, h - 10, 6, h - 14);
  return path..close();
}

/// 右侧波浪边纸（12 号便签）
Path _rightWaveEdgePath(double h) {
  final path = Path()
    ..moveTo(10, 10)
    ..lineTo(280, 10);
  for (var y = 10.0; y < h - 18; y += 16) {
    path.quadraticBezierTo(288, y + 4, 282, y + 8);
    path.quadraticBezierTo(276, y + 12, 282, y + 16);
  }
  path.lineTo(10, h - 10);
  path.quadraticBezierTo(6, h - 10, 6, h - 16);
  path.lineTo(6, 14);
  path.quadraticBezierTo(6, 10, 10, 10);
  return path..close();
}
