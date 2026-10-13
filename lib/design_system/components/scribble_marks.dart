import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';

/// 手绘文本标记：skribble 墨线装饰
///
/// 供标题类文字叠加纸墨风标记：下划线 / 圈选 / 删除线 / 荧光涂抹。
/// 墨线粗细/粗糙度/seed 由 [theme.wired.drawConfig] 驱动，与全局
/// Ink style 档位联动；外层有 [WiredDraw] 时自动播放入场描画动画，
/// 无动画环境（progressOf 为 null）立即全画，天然兼容。

/// 倾斜手绘下划线：画在 [child] 正下方，与文字同宽
///
/// 双重线风格（两条平行墨线）；[angle] 为倾斜弧度（正 = 左高右低）；
/// 颜色默认主题主色。
class DsScribbleUnderline extends StatelessWidget {
  const DsScribbleUnderline({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 2,
    this.angle = 0.025,
    this.seed = 3,
    this.spacing = 4,
  });

  final Widget child;

  /// 墨线颜色（默认 theme.primary）
  final Color? color;
  final double strokeWidth;

  /// 倾斜弧度：线两端的高度差 = width * angle（正 = 左高右低）
  final double angle;

  /// 墨迹 seed（固定值保证 rebuild 墨迹不抖变；第二条线自动 +1）
  final int seed;

  /// 文字与下划线的间距
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);

    // 两条墨线 + 行间距的总高度
    final lineHeight = strokeWidth * 2 + 4;

    // IntrinsicWidth + stretch 让下划线宽度跟随文字实际宽度
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          SizedBox(height: spacing),
          SizedBox(
            height: lineHeight,
            child: CustomPaint(
              painter: _ScribbleLinePainter(
                color: color ?? theme.primary,
                strokeWidth: strokeWidth,
                seed: seed,
                drawConfig: theme.wired.drawConfig,
                progress: progress,
                angle: angle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手绘删除线：墨线穿过 [child] 中部（两端出头）
class DsScribbleStrike extends StatelessWidget {
  const DsScribbleStrike({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 1.8,
    this.seed = 7,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  });

  final Widget child;

  /// 墨线颜色（默认 theme.danger）
  final Color? color;
  final double strokeWidth;
  final int seed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);

    return CustomPaint(
      painter: _StrikePainter(
        color: color ?? theme.danger,
        strokeWidth: strokeWidth,
        seed: seed,
        drawConfig: theme.wired.drawConfig,
        progress: progress,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter({
    required this.color,
    required this.strokeWidth,
    required this.seed,
    required this.drawConfig,
    required this.progress,
  }) : super(repaint: progress);

  final Color color;
  final double strokeWidth;
  final int seed;
  final DrawConfig drawConfig;
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final overscan = 3.0;
    final y = size.height / 2 + 1;

    final ink = _inkPaint(color, strokeWidth);
    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final generator = Generator(config, NoFiller());
    RoughDrawing(
      generator.line(-overscan, y, size.width + overscan, y - 1.5),
      ink,
      ink,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig ||
      oldDelegate.progress != progress;
}

/// 手绘椭圆圈选：墨线椭圆环绕 [child]（默认红色，标记重点）
class DsScribbleCircle extends StatelessWidget {
  const DsScribbleCircle({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 1.8,
    this.seed = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  });

  final Widget child;

  /// 墨线颜色（默认 theme.danger 红色）
  final Color? color;
  final double strokeWidth;
  final int seed;

  /// 圈内边距（文字与墨线的呼吸空间）
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);

    // CustomPaint 以 child 尺寸为画布；椭圆向外扩 bleed，墨线压住文字边缘
    return CustomPaint(
      painter: _CirclePainter(
        color: color ?? theme.danger,
        strokeWidth: strokeWidth,
        seed: seed,
        drawConfig: theme.wired.drawConfig,
        progress: progress,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.seed,
    required this.drawConfig,
    required this.progress,
  }) : super(repaint: progress);

  final Color color;
  final double strokeWidth;
  final int seed;
  final DrawConfig drawConfig;
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bleed = 3.0;
    final w = size.width + bleed * 2;
    final h = size.height + bleed * 2;

    final ink = _inkPaint(color, strokeWidth);
    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final generator = Generator(config, NoFiller());
    // 画布平移 bleed 后以中心画椭圆（CustomPainter 不裁切，可溢出边界）
    canvas.translate(bleed, bleed);
    RoughDrawing(
      generator.ellipse(
        size.width / 2,
        size.height / 2,
        w - strokeWidth,
        h - strokeWidth,
      ),
      ink,
      ink,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig ||
      oldDelegate.progress != progress;
}

/// 手绘荧光涂抹：斜排线覆盖 [child] 全高（画在文字上层，半透明可透出字）
class DsScribbleHighlight extends StatelessWidget {
  const DsScribbleHighlight({
    super.key,
    required this.child,
    this.color,
    this.seed = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
  });

  final Widget child;

  /// 涂抹颜色（默认 theme.warning，自动降低透明度）
  final Color? color;
  final int seed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);

    return CustomPaint(
      // foregroundPainter 画在文字上层，模拟荧光笔压在字面
      foregroundPainter: _HighlightPainter(
        color: (color ?? theme.warning).withValues(alpha: 0.45),
        seed: seed,
        drawConfig: theme.wired.drawConfig,
        progress: progress,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter({
    required this.color,
    required this.seed,
    required this.drawConfig,
    required this.progress,
  }) : super(repaint: progress);

  final Color color;
  final int seed;
  final DrawConfig drawConfig;
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bleed = 2.0;
    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final filler = HachureFiller(
      FillerConfig.build(
        drawConfig: config,
        hachureGap: 5,
        fillWeight: 1.8,
      ),
    );
    final generator = Generator(config, filler);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // 描边完全透明：只保留排线填充（荧光笔无描边），须与 fill 独立
    final invisible = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..color = const Color(0x00000000);

    canvas.translate(-bleed, -bleed);
    RoughDrawing(
      generator.rectangle(0, 0, size.width + bleed * 2, size.height + bleed * 2),
      invisible,
      fill,
    ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
  }

  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig ||
      oldDelegate.progress != progress;
}

/// 下划线画笔：双重倾斜 rough 线（正 angle = 左高右低）
class _ScribbleLinePainter extends CustomPainter {
  const _ScribbleLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.seed,
    required this.drawConfig,
    required this.progress,
    required this.angle,
  }) : super(repaint: progress);

  final Color color;
  final double strokeWidth;
  final int seed;
  final DrawConfig drawConfig;
  final Animation<double>? progress;

  /// 倾斜弧度：线两端的高度差 = width * angle（正 = 左高右低）
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final half = strokeWidth / 2;
    final baseY = half + 1;
    // 正 angle = 左高右低（终点上抬）
    final rise = -size.width * angle;

    final ink = _inkPaint(color, strokeWidth);

    // 双重线：两条平行墨线，第二条角度/墨迹略异，更接近手绘重复描画
    final lineGap = strokeWidth + 3;
    for (var i = 0; i < 2; i++) {
      final config = drawConfig.copyWith(seed: seed + i);
      config.randomizer.reset();
      final generator = Generator(config, NoFiller());
      final y = baseY + lineGap * i;
      final thisRise = rise * (i == 0 ? 1 : 1.15);
      RoughDrawing(
        generator.line(half, y, size.width - half, y + thisRise),
        ink,
        ink,
      ).paint(canvas, progress: progress?.value ?? 1, pressure: 0);
    }
  }

  @override
  bool shouldRepaint(_ScribbleLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig ||
      oldDelegate.progress != progress ||
      oldDelegate.angle != angle;
}

Paint _inkPaint(Color color, double strokeWidth) {
  return Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = strokeWidth
    ..color = color;
}
