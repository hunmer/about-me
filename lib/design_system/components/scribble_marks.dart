import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';

/// 手绘文本标记：skribble 墨线装饰（下划线 / 圈选）
///
/// 供标题类文字叠加纸墨风标记：墨线粗细/粗糙度/seed 由
/// [theme.wired.drawConfig] 驱动，与全局 Ink style 档位联动。

/// 倾斜手绘下划线：画在 [child] 正下方，与文字同宽
///
/// [angle] 为倾斜弧度（正 = 左低右高）；颜色默认主题主色。
class DsScribbleUnderline extends StatelessWidget {
  const DsScribbleUnderline({
    super.key,
    required this.child,
    this.color,
    this.strokeWidth = 2.4,
    this.angle = 0.08,
    this.seed = 3,
    this.spacing = 4,
  });

  final Widget child;

  /// 墨线颜色（默认 theme.primary）
  final Color? color;
  final double strokeWidth;

  /// 倾斜弧度：线两端的高度差 = width * angle
  final double angle;

  /// 墨迹 seed（固定值保证 rebuild 墨迹不抖变）
  final int seed;

  /// 文字与下划线的间距
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final lineColor = color ?? theme.primary;

    // IntrinsicWidth + stretch 让下划线宽度跟随文字实际宽度
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          SizedBox(
            height: strokeWidth + 5,
            child: CustomPaint(
              painter: _UnderlinePainter(
                color: lineColor,
                strokeWidth: strokeWidth,
                angle: angle,
                seed: seed,
                drawConfig: theme.wired.drawConfig,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  const _UnderlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.angle,
    required this.seed,
    required this.drawConfig,
  });

  final Color color;
  final double strokeWidth;
  final double angle;
  final int seed;
  final DrawConfig drawConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final half = strokeWidth / 2;
    final baseY = half + 1;
    final rise = size.width * angle;

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;

    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final generator = Generator(config, NoFiller());
    canvas.drawRough(
      generator.line(half, baseY, size.width - half, baseY + rise),
      ink,
      ink,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.angle != angle ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig;
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
    final inkColor = color ?? theme.danger;

    // CustomPaint 以 child 尺寸为画布；椭圆向外扩 bleed，墨线压住文字边缘
    return CustomPaint(
      painter: _CirclePainter(
        color: inkColor,
        strokeWidth: strokeWidth,
        seed: seed,
        drawConfig: theme.wired.drawConfig,
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
  });

  final Color color;
  final double strokeWidth;
  final int seed;
  final DrawConfig drawConfig;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bleed = 3.0;
    final w = size.width + bleed * 2;
    final h = size.height + bleed * 2;

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;

    final config = drawConfig.copyWith(seed: seed);
    config.randomizer.reset();
    final generator = Generator(config, NoFiller());
    // 画布平移 bleed 后以中心画椭圆（CustomPainter 不裁切，可溢出边界）
    canvas.translate(bleed, bleed);
    canvas.drawRough(
      generator.ellipse(size.width / 2, size.height / 2, w - strokeWidth, h - strokeWidth),
      ink,
      ink,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.seed != seed ||
      oldDelegate.drawConfig != drawConfig;
}
