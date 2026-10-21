import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 手绘燕尾旗标：区块标题（矩形右端切 V 形凹口的旗帜形）
///
/// 旗形用 skribble `Generator.polygon` 画 rough 实底
/// （[color].mixWhite(0.2)）+ 墨线描边；宽随文字自适应
/// （横向内边距默认左 [DsSpacing.xl]、右 [DsSpacing.xxxl]，右侧多留以避开
/// V 形凹口）。文字反色居中。
///
/// ```dart
/// DsTitleBanner(text: '今日手帐')
/// DsTitleBanner(text: '相册', color: theme.secondary)
/// ```
class DsTitleBanner extends StatelessWidget {
  const DsTitleBanner({
    super.key,
    required this.text,
    this.color,
    this.fontSize = 18,
    this.padding,
  });

  final String text;

  /// 旗面颜色（默认主题主色）
  final Color? color;

  /// 文字字号
  final double fontSize;

  /// 旗面内边距（默认横向 20、纵向 sm）
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final bg = color ?? theme.primary;
    // 反色文字：浅旗面用墨色、深旗面用白（默认色直接用主题 onPrimary）
    final foreground =
        color == null
        ? theme.onPrimary
        : (bg.computeLuminance() > 0.6 ? theme.ink : DsColors.white);

    final content = Padding(
      padding:
          padding ??
          EdgeInsets.only(
            left: theme.spacing.xl,
            // 右侧多留：V 形凹口最深点在 0.72w，预留不足会侵入文字
            right: theme.spacing.xxxl,
            top: theme.spacing.sm,
            bottom: theme.spacing.sm,
          ),
      child: Text(
        text,
        style: DsTypography.heading.copyWith(
          fontSize: fontSize,
          color: foreground,
        ),
      ),
    );

    return CustomPaint(
      painter: _SwallowTailPainter(
        fill: bg.mixWhite(0.2),
        stroke: theme.ink,
        strokeWidth: theme.wired.strokeWidth,
        drawConfig: theme.wired.drawConfig,
      ),
      child: content,
    );
  }
}

/// 燕尾旗面：右端 V 形凹口的凹多边形，rough 实底 + 墨线描边
///
/// 固定 seed + randomizer.reset() 保证 rebuild 墨迹稳定；
/// 尺寸变化才重新生成。
class _SwallowTailPainter extends CustomPainter {
  _SwallowTailPainter({
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
    required this.drawConfig,
  });

  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final DrawConfig drawConfig;

  Size? _size;
  RoughDrawing? _drawing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size || _drawing == null) {
      final w = size.width;
      final h = size.height;
      // 右端 V 形燕尾凹口：右上(0.88w,0) → 中(0.72w,0.5h) → 右下(0.88w,h)
      drawConfig.randomizer.reset();
      final generator = Generator(drawConfig, SolidFiller());
      final drawable = generator.polygon([
        PointD(0, 0),
        PointD(w * 0.88, 0),
        PointD(w * 0.72, h / 2),
        PointD(w * 0.88, h),
        PointD(0, h),
      ]);
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = stroke;
      final fillPaint = Paint()
        ..isAntiAlias = true
        ..color = fill;
      _drawing = RoughDrawing(drawable, borderPaint, fillPaint);
      _size = size;
    }
    _drawing!.paint(canvas);
  }

  @override
  bool shouldRepaint(_SwallowTailPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.drawConfig != drawConfig;
}
