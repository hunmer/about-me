/// 手绘风格共享层：skribble rough 引擎的统一封装
///
/// 全部组件的手绘墨线都从这一个文件出去，保证：
/// - 墨色/纸色/笔宽与 [AppThemeData] 语义色一致（深浅模式自动适配）
/// - 粗糙度、笔刷走同一套 DrawConfig（与 Wired* 组件同源）
/// - 固定 seed：rebuild 时墨迹不抖变
///
/// 填充分档（项目约定）：
/// - 小控件（按钮/输入框/勾选框）：纯色实底 + 墨线描边
/// - 大容器（卡片/对话框/面板）：纸底 + 淡排线（hachure）
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import 'typography.dart';

/// 全局墨线风格（skribble 三档粗糙度 + 笔宽）
///
/// 由 `core/services/ds_ink_style_controller.dart` 在加载/切换时写入；
/// 切换后经 DSThemeBridge 重建主题树全局生效。
/// 字体不受档位影响（wired 显式覆盖为 TegakiZatsu）。
class DsInkStyle {
  DsInkStyle._();

  static WiredRoughness level = WiredRoughness.playful;

  /// 墨线笔宽（Wired* 组件描边粗细，随主题预设变化）
  static double strokeWidth = 2.2;

  /// 档位标签（设置页与持久化用，顺序与 WiredRoughness.values 一致）
  static const List<String> labels = ['Gentle', 'Playful', 'Expressive'];

  static WiredRoughness byIndex(int index) => WiredRoughness.values[index];

  /// 当前档位下标（与 labels 对应）
  static int get index => level.index;
}

/// 手绘主题派生：从语义主题取墨/纸/笔参数
extension DsSketchTheme on AppThemeData {
  /// 墨线色：手绘描边与手绘图标的主色
  Color get ink => isDark ? text : DsColors.text;

  /// 纸色：手绘件填充底色
  Color get paper => surface;

  /// 排线色：大容器的淡彩涂色（主色调淡）
  Color get hatch => primary.withValues(alpha: isDark ? 0.30 : 0.22);

  /// 对应的 skribble 主题：Wired* 组件经 WiredTheme.of 取色的数据源
  WiredThemeData get wired =>
      _wiredCache[_wiredCacheKey(this)] ??= WiredThemeData(
        borderColor: isDark ? text : DsColors.text,
        textColor: text,
        disabledTextColor: textSub,
        fillColor: surface,
        markerColor: primary,
        strokeWidth: DsInkStyle.strokeWidth,
        roughnessLevel: DsInkStyle.level,
        // Wired* 组件文字与 DsTypography 同字体（851 手写杂书体，
        // app 内注册，覆盖中/英/日；覆盖默认的 skribble bundled 字体，
        // 且不随粗糙度档位切换字体）
        fontFamily: DsTypography.sketchFamily,
      );
}

/// [AppThemeData] 实例 × 墨线风格（档位 + 笔宽）→ WiredThemeData 缓存
/// （AppThemeData 是 const 构造，实例在主题切换间稳定；
/// 档位或笔宽变化换 key 取新缓存，避免旧数据残留）
final Map<int, WiredThemeData> _wiredCache = {};

int _wiredCacheKey(AppThemeData theme) =>
    identityHashCode(theme) * 1000 +
    DsInkStyle.index * 100 +
    (DsInkStyle.strokeWidth * 10).round();

/// 手绘填充预设（卡片/面板背景风格切换）
enum DsSketchFill {
  /// 单向排线（默认手绘排线）
  hachure,

  /// 交叉排线（两遍垂直排线）
  crossHatch,

  /// 点画
  dots,

  /// 之字形连线
  zigzag,

  /// 笔记本水平横线（hachureAngle 0 的水平排线）
  ruled,

  /// 纯色实底
  solid,
}

/// 统一手绘装饰构造器
///
/// 返回 [RoughBoxDecoration]（Decoration 子类，直接给 Container.decoration）。
///
/// - [fillColor] 非空时按 [hachure]/[fillStyle] 决定填充：排线类或纯色实底
/// - [stroke] 默认墨线；pill 圆角（999）会被 rough 引擎自动钳制成胶囊
/// - [fillStyle] 显式填充预设，优先于 [hachure]；排线类风格下
///   [fillColor] 为 null/透明时取 [hachureColor]
/// - [seed] 保持稳定默认值即可；列表项可传唯一值增加墨迹变化
RoughBoxDecoration dsSketchDecoration({
  required AppThemeData theme,
  Color? fillColor,
  Color? stroke,
  double strokeWidth = 1.8,
  BorderRadius? radius,
  bool circle = false,
  bool hachure = false,
  DsSketchFill? fillStyle,
  Color? hachureColor,
  double hachureGap = 8,
  int seed = 1,
  Animation<double>? progress,
}) {
  final DsSketchFill? style =
      fillStyle ??
      (fillColor == null
          ? null
          : (hachure ? DsSketchFill.hachure : DsSketchFill.solid));

  final Filler? filler;
  Color? resolvedFillColor;
  switch (style) {
    case null:
      filler = null;
    case DsSketchFill.solid:
      filler = SolidFiller();
      resolvedFillColor = fillColor;
    case DsSketchFill.hachure || DsSketchFill.crossHatch ||
          DsSketchFill.dots || DsSketchFill.zigzag || DsSketchFill.ruled:
      // 点画的点径/密度需要更大参数才可见
      filler = switch (style) {
        DsSketchFill.crossHatch => HatchFiller(
          FillerConfig.build(
            drawConfig: theme.wired.drawConfig,
            hachureGap: hachureGap,
            fillWeight: 1.4,
          ),
        ),
        DsSketchFill.dots => DotFiller(
          FillerConfig.build(
            drawConfig: theme.wired.drawConfig,
            hachureGap: 6,
            fillWeight: 2.4,
          ),
        ),
        DsSketchFill.zigzag => ZigZagFiller(
          FillerConfig.build(
            drawConfig: theme.wired.drawConfig,
            hachureGap: hachureGap,
            fillWeight: 1.4,
          ),
        ),
        DsSketchFill.ruled => HachureFiller(
          FillerConfig.build(
            drawConfig: theme.wired.drawConfig,
            // buildFillLines 以 hachureAngle+90 旋转后画水平扫描线再转回，
            // 故 -90 才是水平线；行距模拟笔记本行高
            hachureAngle: -90,
            hachureGap: 12,
            fillWeight: 1.2,
          ),
        ),
        _ => HachureFiller(
          FillerConfig.build(
            drawConfig: theme.wired.drawConfig,
            hachureGap: hachureGap,
            fillWeight: 1.4,
          ),
        ),
      };
      resolvedFillColor =
          (fillColor == null || fillColor == DsColors.transparent)
          ? (hachureColor ?? theme.hatch)
          : fillColor;
  }

  return _DsRoughBoxDecoration(
    shape: circle
        ? RoughBoxShape.circle
        : (radius == null
            ? RoughBoxShape.rectangle
            : RoughBoxShape.roundedRectangle),
    borderRadius: circle ? null : (radius ?? BorderRadius.zero),
    borderStyle: RoughDrawingStyle(
      width: strokeWidth,
      color: stroke ?? theme.ink,
    ),
    fillStyle: resolvedFillColor == null
        ? null
        : RoughDrawingStyle(color: resolvedFillColor),
    filler: filler,
    drawConfig: theme.wired.drawConfig,
    seed: seed,
    progress: progress,
  );
}

/// [RoughBoxDecoration] 的项目内定制：描边贴边 + 内容不加出血
///
/// skribble 原版有两处「内缩」：
/// 1. `padding` 预留墨迹出血（约 2~5px），叠加在组件显式 padding 上，
///    会让「边框到内容」的间距莫名变大 → 本类覆盖为零；
/// 2. painter 把形状整体 deflate 出血量，描边线条离容器真实边缘
///    仍有数像素空隙 → 自定义 painter 仅内缩半个线宽（线完全在
///    界内且贴边），padding 只作用于内容，不作用于描边线条。
class _DsRoughBoxDecoration extends RoughBoxDecoration {
  const _DsRoughBoxDecoration({
    required super.shape,
    required super.borderStyle,
    required super.fillStyle,
    required super.filler,
    required super.drawConfig,
    required super.borderRadius,
    required super.seed,
    super.progress,
  });

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DsRoughBoxPainter(this, onChanged);

  /// 裁剪几何路径（RoughBoxDecoration 未实现，默认抛 UnsupportedError）。
  /// 手绘墨迹本身不参与裁剪，按形状返回标准几何路径。
  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => switch (shape) {
        RoughBoxShape.rectangle => Path()..addRect(rect),
        RoughBoxShape.roundedRectangle => Path()
          ..addRRect((borderRadius ?? BorderRadius.zero).toRRect(rect)),
        RoughBoxShape.circle || RoughBoxShape.ellipse =>
          Path()..addOval(rect),
      };
}

class _DsRoughBoxPainter extends BoxPainter {
  _DsRoughBoxPainter(this.decoration, [VoidCallback? onChanged])
      : super(onChanged) {
    // 跟随环境描画动画（WiredDraw/WiredDrawTransition）逐帧重绘墨线
    final progress = decoration.progress;
    if (onChanged != null && progress != null) {
      progress.addListener(onChanged);
    }
  }

  final _DsRoughBoxDecoration decoration;

  Size? _size;
  late RoughDrawing _drawing;

  @override
  void dispose() {
    final progress = decoration.progress;
    final callback = onChanged;
    if (progress != null && callback != null) {
      progress.removeListener(callback);
    }
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    if (_size != size) {
      _drawing = _prepare(size);
      _size = size;
    }
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _drawing.paint(
      canvas,
      progress: decoration.progress?.value ?? 1,
      pressure: 0,
    );
    canvas.restore();
  }

  RoughDrawing _prepare(Size size) {
    final half = (decoration.borderStyle?.width ?? 0) / 2;
    final rect = (Offset.zero & size).deflate(
      math.min(half, size.shortestSide / 2),
    );

    final drawConfig =
        decoration.drawConfig ?? DrawConfig.build(seed: decoration.seed);
    drawConfig.randomizer.reset();
    final filler = decoration.filler ?? NoFiller();
    final generator = Generator(drawConfig, filler);

    final borderPaint = _buildPaint(
      decoration.borderStyle ?? const RoughDrawingStyle(),
      rect,
    );
    final fillPaint = decoration.fillStyle == null
        ? borderPaint
        : _buildPaint(decoration.fillStyle!, rect);

    final Drawable drawable;
    switch (decoration.shape) {
      case RoughBoxShape.rectangle:
        drawable = generator.rectangle(
          rect.left,
          rect.top,
          rect.width,
          rect.height,
        );
      case RoughBoxShape.roundedRectangle:
        final br = decoration.borderRadius ?? BorderRadius.zero;
        drawable = generator.roundedRectangle(
          rect.left,
          rect.top,
          rect.width,
          rect.height,
          br.topLeft.x,
          br.topRight.x,
          br.bottomRight.x,
          br.bottomLeft.x,
        );
      case RoughBoxShape.circle:
        drawable = generator.circle(
          rect.center.dx,
          rect.center.dy,
          rect.shortestSide,
        );
      case RoughBoxShape.ellipse:
        drawable = generator.ellipse(
          rect.center.dx,
          rect.center.dy,
          rect.width,
          rect.height,
        );
    }
    return RoughDrawing(drawable, borderPaint, fillPaint);
  }

  Paint _buildPaint(RoughDrawingStyle style, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = style.width ?? 0.1
      ..color = style.color ?? const Color(0x00000000)
      ..shader = style.gradient?.createShader(rect);
    if (style.blendMode != null) {
      paint.blendMode = style.blendMode!;
    }
    return paint;
  }
}

/// 大容器手绘面板：纸底 + 淡排线 + 墨线框（内容层在排线之上）
///
/// 大面积容器（卡片/对话框/浮层面板）的标准组合。
class DsSketchPanel extends StatelessWidget {
  const DsSketchPanel({
    super.key,
    this.child,
    required this.theme,
    this.fillColor,
    this.radius,
    this.padding,
    this.width,
    this.height,
    this.stroke,
    this.hachureColor,
    this.alignment,
    this.hachure = true,
    this.fillStyle,
    this.seed = 1,
    this.progress,
  });

  final Widget? child;
  final AppThemeData theme;

  /// 纸底色（默认主题 surface）
  final Color? fillColor;
  final BorderRadius? radius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? stroke;
  final Color? hachureColor;
  final AlignmentGeometry? alignment;

  /// 关闭后不画排线（纯纸底 + 描边）
  final bool hachure;

  /// 显式填充预设（排线/交叉/点/之字/实底）；null 时按 [hachure] 走默认排线
  final DsSketchFill? fillStyle;
  final int seed;

  /// 环境描画动画（外层 WiredDraw 注入）；null = 已画完
  final Animation<double>? progress;

  @override
  Widget build(BuildContext context) {
    // 结构：底色铺满容器 → 描边/排线铺满容器 → padding 只包裹内容。
    // （不能把 padding 放在外层 Container 上——那会把整个描边层
    // 一起内缩，墨线画到 padding 里侧，边距「挤走」描边。）
    Widget? content = child;
    if (content != null && padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        color: fillColor ?? theme.surface,
        borderRadius: radius,
      ),
      child: _RoughUnderlay(
        decoration: dsSketchDecoration(
          theme: theme,
          radius: radius,
          stroke: stroke,
          fillColor: fillStyle == DsSketchFill.solid
              ? (hachureColor ?? theme.hatch)
              : (hachure || fillStyle != null
                    ? DsColors.transparent
                    : null),
          fillStyle: fillStyle ??
              (hachure ? DsSketchFill.hachure : null) ??
              (fillColor != null ? DsSketchFill.solid : null),
          hachureColor: hachureColor,
          hachureGap: 10,
          seed: seed,
          progress: progress,
        ),
        child: content,
      ),
    );
  }
}

/// 排线/描边衬层：铺满所在容器（与内容同尺寸），
/// 墨线画在容器真实边界上
class _RoughUnderlay extends StatelessWidget {
  const _RoughUnderlay({required this.decoration, this.child});

  final RoughBoxDecoration decoration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (content == null) {
      // 无内容时仅描边层（尺寸由外部约束决定）
      return CustomPaint(
        painter: _BoxPainterProxy(decoration),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _BoxPainterProxy(decoration)),
          ),
        ),
        content,
      ],
    );
  }
}

/// 把 [RoughBoxDecoration] 的 BoxPainter 适配成 CustomPainter
class _BoxPainterProxy extends CustomPainter {
  _BoxPainterProxy(this.decoration)
      : _painter = decoration.createBoxPainter(),
        super(repaint: decoration.progress);

  final RoughBoxDecoration decoration;
  final BoxPainter _painter;

  @override
  void paint(Canvas canvas, Size size) {
    _painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
  }

  @override
  bool shouldRepaint(_BoxPainterProxy oldDelegate) =>
      !identical(oldDelegate.decoration, decoration);
}

/// 局部墨色作用域：让某个 Wired*/自绘组件用指定描边色/标记色
///
/// Wired* 组件从 `WiredTheme.of(context)` 取色，嵌套本作用域即可
/// 实现「危险按钮红墨、主按钮紫墨」的组件级变色，不影响外层主题。
class DsInkScope extends StatelessWidget {
  const DsInkScope({
    super.key,
    required this.child,
    this.border,
    this.text,
    this.fill,
    this.marker,
  });

  final Widget child;
  final Color? border;
  final Color? text;
  final Color? fill;
  final Color? marker;

  @override
  Widget build(BuildContext context) {
    final data = WiredTheme.of(context).copyWith(
      borderColor: border,
      textColor: text,
      fillColor: fill,
      markerColor: marker,
    );
    return WiredThemeScope(data: data, child: child);
  }
}
