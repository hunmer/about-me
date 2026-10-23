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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import 'typography.dart';

/// 描边线风格：粗糙度档位 × 笔宽 × 可选笔型覆盖的命名组合
///
/// 供主题设置页独立选择；应用后写入 [DsInkStyle] 全局生效。
class DsStrokeStyle {
  const DsStrokeStyle({
    required this.id,
    required this.labelKey,
    required this.level,
    required this.strokeWidth,
    this.pen,
  });

  /// 稳定标识（持久化用）
  final String id;

  /// 展示文案的翻译键
  final String labelKey;

  /// 粗糙度档位
  final WiredRoughness level;

  /// 笔宽
  final double strokeWidth;

  /// 笔型覆盖（null = 用档位自带笔型）
  final RoughPen? pen;

  /// 本风格的绘制配置（主题设置页的预览块用）
  DrawConfig get drawConfig => DrawConfig.build(
    roughness: level.roughness,
    maxRandomnessOffset: level.maxRandomnessOffset,
    lineWobble: level.lineWobble,
    pen: pen ?? level.pen,
  );
}

/// 描边线风格集合
///
/// 前 3 项与各主题预设的默认墨线一一对应（档位 + 笔宽完全一致），
/// 供「跟随主题」回落取值；其后为可选的自定义风格。
abstract final class DsStrokeStyles {
  /// 柔和（细笔）
  static const DsStrokeStyle gentle = DsStrokeStyle(
    id: 'gentle',
    labelKey: 'screens_inkStyleGentle',
    level: WiredRoughness.gentle,
    strokeWidth: 1.8,
  );

  /// 俏皮（标准墨线，默认）
  static const DsStrokeStyle playful = DsStrokeStyle(
    id: 'playful',
    labelKey: 'screens_inkStylePlayful',
    level: WiredRoughness.playful,
    strokeWidth: 2.2,
  );

  /// 狂放（粗笔）
  static const DsStrokeStyle expressive = DsStrokeStyle(
    id: 'expressive',
    labelKey: 'screens_inkStyleExpressive',
    level: WiredRoughness.expressive,
    strokeWidth: 2.6,
  );

  /// 针笔：柔和几何 + 细腻针管笔
  static const DsStrokeStyle needle = DsStrokeStyle(
    id: 'needle',
    labelKey: 'screens_strokeNeedle',
    level: WiredRoughness.gentle,
    strokeWidth: 1.2,
    pen: RoughPen.fineliner,
  );

  /// 马克笔：恒宽粗线
  static const DsStrokeStyle marker = DsStrokeStyle(
    id: 'marker',
    labelKey: 'screens_strokeMarker',
    level: WiredRoughness.playful,
    strokeWidth: 3.2,
    pen: RoughPen.uniform,
  );

  /// 秀丽笔：狂放几何 + 钢笔笔锋
  static const DsStrokeStyle fountain = DsStrokeStyle(
    id: 'fountain',
    labelKey: 'screens_strokeFountain',
    level: WiredRoughness.expressive,
    strokeWidth: 2.0,
    pen: RoughPen.ink,
  );

  /// 基础三档（下标与 WiredRoughness 档位对应，主题预设默认值）
  static const List<DsStrokeStyle> base = [gentle, playful, expressive];

  static const List<DsStrokeStyle> all = [
    gentle,
    playful,
    expressive,
    needle,
    marker,
    fountain,
  ];

  /// 按 id 查找，未知 id 返回 null
  static DsStrokeStyle? byId(String? id) {
    if (id == null) return null;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// 按档位 + 笔宽精确匹配（旧配置迁移用），未命中回落该档位基础风格
  static DsStrokeStyle match(WiredRoughness level, double strokeWidth) {
    for (final s in all) {
      if (s.level == level && s.strokeWidth == strokeWidth) return s;
    }
    return base[level.index];
  }
}

/// 全局墨线风格（skribble 三档粗糙度 + 笔宽 + 可选笔型覆盖）
///
/// 由 `core/services/ds_ink_style_controller.dart` 在加载/切换时写入；
/// 切换后经 DSThemeBridge 重建主题树全局生效。
/// 字体不受档位影响（wired 显式覆盖为 TegakiZatsu）。
class DsInkStyle {
  DsInkStyle._();

  static WiredRoughness level = WiredRoughness.playful;

  /// 墨线笔宽（Wired* 组件描边粗细）
  static double strokeWidth = 2.2;

  /// 笔型覆盖（null = 用档位自带笔型；自定义描边风格会写入）
  static RoughPen? pen;

  /// 档位标签（设置页与持久化用，顺序与 WiredRoughness.values 一致）
  static const List<String> labels = ['Gentle', 'Playful', 'Expressive'];

  static WiredRoughness byIndex(int index) => WiredRoughness.values[index];

  /// 当前档位下标（与 labels 对应）
  static int get index => level.index;

  /// 应用一套命名描边风格（全局生效）
  static void apply(DsStrokeStyle style) {
    level = style.level;
    strokeWidth = style.strokeWidth;
    pen = style.pen;
  }

  /// 当前生效的命名风格（按档位+笔宽+笔型匹配，未命中回落俏皮档）
  static DsStrokeStyle get current => DsStrokeStyles.match(level, strokeWidth);
}

/// 手绘主题派生：从语义主题取墨/纸/笔参数
extension DsSketchTheme on AppThemeData {
  /// 纸色：手绘件填充底色
  Color get paper => surface;

  /// 排线色：大容器的淡彩涂色（主色调淡）
  Color get hatch => primary.withValues(alpha: isDark ? 0.30 : 0.22);

  /// 对应的 skribble 主题：Wired* 组件经 WiredTheme.of 取色的数据源
  WiredThemeData get wired =>
      _wiredCache[_wiredCacheKey(this)] ??= WiredThemeData(
        borderColor: ink,
        textColor: text,
        disabledTextColor: textSub,
        fillColor: surface,
        markerColor: primary,
        strokeWidth: DsInkStyle.strokeWidth,
        roughnessLevel: DsInkStyle.level,
        // null = 用档位自带笔型（自定义描边风格会覆盖）
        pen: DsInkStyle.pen,
        // Wired* 组件文字与 DsTypography 同字体（851 手写杂书体，
        // app 内注册，覆盖中/英/日；覆盖默认的 skribble bundled 字体，
        // 且不随粗糙度档位切换字体）
        fontFamily: DsTypography.sketchFamily,
      );
}

/// [AppThemeData] 实例 × 墨线风格（档位 + 笔宽 + 笔型）→ WiredThemeData 缓存
/// （AppThemeData 是 const 构造，实例在主题切换间稳定；
/// 档位/笔宽/笔型变化换 key 取新缓存，避免旧数据残留）
final Map<int, WiredThemeData> _wiredCache = {};

int _wiredCacheKey(AppThemeData theme) =>
    identityHashCode(theme) * 100000 +
    DsInkStyle.index * 1000 +
    (DsInkStyle.strokeWidth * 10).round() * 10 +
    (DsInkStyle.pen?.hashCode ?? 0) % 997;

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
/// - [drawConfig] 覆盖绘制配置（默认取当前墨线风格；风格预览块
///   传入目标风格的配置以演示其笔触）
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
  DrawConfig? drawConfig,
}) {
  final dc = drawConfig ?? theme.wired.drawConfig;
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
    case DsSketchFill.hachure ||
        DsSketchFill.crossHatch ||
        DsSketchFill.dots ||
        DsSketchFill.zigzag ||
        DsSketchFill.ruled:
      // 点画的点径/密度需要更大参数才可见
      filler = switch (style) {
        DsSketchFill.crossHatch => HatchFiller(
          FillerConfig.build(
            drawConfig: dc,
            hachureGap: hachureGap,
            fillWeight: 1.4,
          ),
        ),
        DsSketchFill.dots => DotFiller(
          FillerConfig.build(
            drawConfig: dc,
            // 点画间距跟随调用方（小控件默认更密，全屏背景传大间距，
            // 避免整屏生成数万个点导致卡顿）
            hachureGap: hachureGap,
            fillWeight: 2.4,
          ),
        ),
        DsSketchFill.zigzag => ZigZagFiller(
          FillerConfig.build(
            drawConfig: dc,
            hachureGap: hachureGap,
            fillWeight: 1.4,
          ),
        ),
        DsSketchFill.ruled => HachureFiller(
          FillerConfig.build(
            drawConfig: dc,
            // buildFillLines 以 hachureAngle+90 旋转后画水平扫描线再转回，
            // 故 -90 才是水平线；行距模拟笔记本行高
            hachureAngle: -90,
            hachureGap: 12,
            fillWeight: 1.2,
          ),
        ),
        _ => HachureFiller(
          FillerConfig.build(
            drawConfig: dc,
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
    drawConfig: dc,
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
    RoughBoxShape.roundedRectangle =>
      Path()..addRRect((borderRadius ?? BorderRadius.zero).toRRect(rect)),
    RoughBoxShape.circle || RoughBoxShape.ellipse => Path()..addOval(rect),
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

/// 手绘贴纸：贴在 [DsSketchPanel] 边框内/外侧的装饰元素
///
/// 三选一的内容源：[svg]（asset 路径）/ [asset]（位图 asset 路径）/ [text]。
/// 定位方式：先按 [alignment] 锚定到面板某角（贴纸边界贴齐边框内侧），
/// 再用 [offset] 平移（负 dy 向边框外、正 dx 向右侧边框外），
/// 最后绕贴纸中心旋转 [rotation] 弧度。多个贴纸即可拼出贴纸堆。
class DsSketchSticker {
  const DsSketchSticker({
    required this.alignment,
    this.offset = Offset.zero,
    this.size = 36,
    this.rotation = 0,
    this.svg,
    this.asset,
    this.text,
    this.color,
  }) : assert(
         svg != null || asset != null || text != null,
         'svg / asset / text 三者必须提供一个',
       );

  /// 锚点（如 [Alignment.topRight]）
  final AlignmentGeometry alignment;

  /// 相对锚点的平移（正值向右下；负 dy = 顶出边框外）
  final Offset offset;

  /// 贴纸边长；text 贴纸当字号用
  final double size;

  /// 绕中心的旋转角（弧度，手账感的小倾斜如 0.12）
  final double rotation;

  /// SVG asset 路径
  final String? svg;

  /// 位图 asset 路径
  final String? asset;

  /// 文字贴纸内容（默认手写字体）
  final String? text;

  /// text 贴纸颜色；svg 贴纸单色化滤镜（null = 保持 SVG 原色）
  final Color? color;
}

/// 单枚贴纸的渲染层：锚定 → 平移 → 旋转，IgnorePointer 不挡内容交互。
/// 有描画动画时在进度后段（描完排线时）缩放弹入 + 淡入
class _DsSketchStickerLayer extends StatelessWidget {
  const _DsSketchStickerLayer({
    required this.sticker,
    this.color,
    this.progress,
  });

  final DsSketchSticker sticker;
  final Color? color;

  /// 环境描画动画（null = 已画完，贴纸直接显示）
  final Animation<double>? progress;

  /// 贴纸入场占描画进度的后段比例
  static const double _enterWindow = 0.28;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: sticker.alignment,
          child: Transform.translate(
            offset: sticker.offset,
            child: Transform.rotate(
              angle: sticker.rotation,
              child: _buildAnimated(_buildContent()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimated(Widget content) {
    final animation = progress;
    if (animation == null) return content;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = ((animation.value - (1 - _enterWindow)) / _enterWindow).clamp(
          0.0,
          1.0,
        );
        if (t >= 1) return content;
        // easeOutBack 让 scale 越过 1 再回落，模拟「啪地贴上」
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.scale(
            scale: Curves.easeOutBack.transform(t),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final s = sticker;
    if (s.svg != null) {
      return SvgPicture.asset(
        s.svg!,
        width: s.size,
        height: s.size,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      );
    }
    if (s.asset != null) {
      return Image.asset(s.asset!, width: s.size, height: s.size);
    }
    return Text(
      s.text ?? '',
      style: TextStyle(
        fontSize: s.size,
        color: color,
        fontFamily: DsTypography.sketchFamily,
      ),
    );
  }
}

/// 波点壁纸 painter：双层规则圆点纹理（「手账贴纸」底纹）
///
/// 大点半径 [bigRadius]、步长 [bigStep]；小点半径 [smallRadius]、
/// 步长 [smallStep]，相对大点网格错位 [shift]，两层叠出细密波点。
/// 画在纸底之上、排线/内容之下（[DsSketchPanel.polka]）。
class DsPolkaPatternPainter extends CustomPainter {
  const DsPolkaPatternPainter({
    required this.color,
    this.bigRadius = 1.4,
    this.bigStep = 28,
    this.smallRadius = 1.0,
    this.smallStep = 14,
    this.shift = const Offset(7, 7),
  });

  /// 点色（透明度由调用方烘焙：浅色墨线约 0.13，深色约 0.20）
  final Color color;

  final double bigRadius;
  final double bigStep;
  final double smallRadius;
  final double smallStep;
  final Offset shift;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final big = Paint()..color = color;
    final small = Paint()
      ..color = color.withValues(alpha: color.a * 0.7);

    for (var x = 0.0; x <= size.width; x += bigStep) {
      for (var y = 0.0; y <= size.height; y += bigStep) {
        canvas.drawCircle(Offset(x, y), bigRadius, big);
      }
    }
    for (var x = shift.dx; x <= size.width; x += smallStep) {
      for (var y = shift.dy; y <= size.height; y += smallStep) {
        canvas.drawCircle(Offset(x, y), smallRadius, small);
      }
    }
  }

  @override
  bool shouldRepaint(DsPolkaPatternPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bigRadius != bigRadius ||
      oldDelegate.bigStep != bigStep ||
      oldDelegate.smallRadius != smallRadius ||
      oldDelegate.smallStep != smallStep ||
      oldDelegate.shift != shift;
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
    this.dashedStroke = false,
    this.fillStyle,
    this.seed = 1,
    this.progress,
    this.stickers = const [],
    this.polka = false,
    this.polkaColor,
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

  /// 虚线描边：替代 rough 实线墨线框（rough 引擎不支持 dash stroke，
  /// 以路径匀速虚线近似手绘虚框）
  final bool dashedStroke;

  /// 显式填充预设（排线/交叉/点/之字/实底）；null 时按 [hachure] 走默认排线
  final DsSketchFill? fillStyle;
  final int seed;

  /// 环境描画动画（外层 WiredDraw 注入）；null = 已画完
  final Animation<double>? progress;

  /// 贴纸堆：贴在边框内/外侧的装饰（图片/SVG/文字），见 [DsSketchSticker]
  final List<DsSketchSticker> stickers;

  /// 波点壁纸：纸底上叠双层规则圆点（手账贴纸底纹），画在排线之下
  final bool polka;

  /// 波点颜色（null = 主题墨线低透明度，深浅模式自适应）
  final Color? polkaColor;

  @override
  Widget build(BuildContext context) {
    // 结构：底色铺满容器 → 描边/排线铺满容器 → padding 只包裹内容。
    // （不能把 padding 放在外层 Container 上——那会把整个描边层
    // 一起内缩，墨线画到 padding 里侧，边距「挤走」描边。）
    Widget? content = child;
    if (content != null && padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    Widget panel = Container(
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
          // 虚线模式下 rough 实线描边隐藏，改由上层虚线画笔画边框
          stroke: dashedStroke ? DsColors.transparent : stroke,
          fillColor: fillStyle == DsSketchFill.solid
              ? (hachureColor ?? theme.hatch)
              : (hachure || fillStyle != null ? DsColors.transparent : null),
          // 纸底已由外层 Container 绘制；关闭排线时不再追加实色填充。
          fillStyle: fillStyle ?? (hachure ? DsSketchFill.hachure : null),
          hachureColor: hachureColor,
          hachureGap: 10,
          seed: seed,
          progress: progress,
        ),
        dashedBorder: dashedStroke
            ? _DashedBorder(color: stroke ?? theme.ink, radius: radius)
            : null,
        pattern: polka
            ? DsPolkaPatternPainter(
                color:
                    polkaColor ??
                    theme.ink.withValues(alpha: theme.isDark ? 0.20 : 0.13),
              )
            : null,
        child: content,
      ),
    );
    if (stickers.isEmpty) return panel;
    // 贴纸层包在 Stack 上（不裁剪），可溢出边框外显示；
    // text 贴纸未显式给色时回落主题墨色
    return Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        for (final s in stickers)
          _DsSketchStickerLayer(
            sticker: s,
            color: s.color ?? (s.text != null ? theme.ink : null),
            progress: progress,
          ),
      ],
    );
  }
}

/// 排线/描边衬层：铺满所在容器（与内容同尺寸），
/// 墨线画在容器真实边界上
class _RoughUnderlay extends StatelessWidget {
  const _RoughUnderlay({
    required this.decoration,
    this.dashedBorder,
    this.pattern,
    this.child,
  });

  final RoughBoxDecoration decoration;

  /// 可选虚线边框（画在 rough 层之上、内容之下）
  final _DashedBorder? dashedBorder;

  /// 可选底纹层（波点等，画在 rough 层之下、底色之上）
  final CustomPainter? pattern;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (content == null) {
      // 无内容时仅描边层（尺寸由外部约束决定）
      return CustomPaint(
        painter: _UnderPatternPainter(pattern, _BoxPainterProxy(decoration)),
        foregroundPainter: dashedBorder == null
            ? null
            : _DashedBorderPainter(border: dashedBorder!),
      );
    }
    return Stack(
      children: [
        if (pattern != null)
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: pattern!))),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BoxPainterProxy(decoration),
              foregroundPainter: dashedBorder == null
                  ? null
                  : _DashedBorderPainter(border: dashedBorder!),
            ),
          ),
        ),
        content,
      ],
    );
  }
}

/// 虚线边框规格（颜色 / 圆角）
class _DashedBorder {
  const _DashedBorder({required this.color, this.radius});

  final Color color;
  final BorderRadius? radius;
}

/// 沿容器边界画虚线边框：圆角/直角路径按「画 7 空 5」取段
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.border});

  final _DashedBorder border;

  static const double _strokeWidth = 1.6;
  static const double _dashLength = 7;
  static const double _gapLength = 5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = _strokeWidth / 2;
    final rect = Offset.zero & size;
    final rrect = border.radius?.toRRect(rect.deflate(half));
    final path = rrect == null
        ? (Path()..addRect(rect.deflate(half)))
        : (Path()..addRRect(rrect));

    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var drawing = true;
      while (distance < metric.length) {
        final segment = drawing ? _dashLength : _gapLength;
        final next = math.min(distance + segment, metric.length);
        if (drawing) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        drawing = !drawing;
      }
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _strokeWidth
      ..color = border.color;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.border.color != border.color ||
      oldDelegate.border.radius != border.radius;
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

/// 底纹叠画：先 [pattern] 后主体（波点在墨线之下）
class _UnderPatternPainter extends CustomPainter {
  const _UnderPatternPainter(this.pattern, this.main);

  final CustomPainter? pattern;
  final CustomPainter main;

  @override
  void paint(Canvas canvas, Size size) {
    pattern?.paint(canvas, size);
    main.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_UnderPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || !identical(oldDelegate.main, main);
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
