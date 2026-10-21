import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 手绘燕尾旗标：区块标题（矩形右端切 V 形凹口的旗帜形）
///
/// 旗形用 skribble `Generator.polygon` 画 rough 实底
/// （[color].mixWhite(0.2)）+ 墨线描边；宽随文字自适应，
/// 右侧内边距按凹口深度反解预留（默认情况下文字与凹口尖
/// 保持 [DsSpacing.sm] 间隙）。文字反色居中。
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

  /// 燕尾凹口尖端的横向位置（旗宽比例），painter 与右侧内边距计算共用
  static const double _notchTipX = 0.72;

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

    final style = DsTypography.heading.copyWith(
      fontSize: fontSize,
      color: foreground,
    );

    // 凹口尖在 _notchTipX*w、深度随旗宽增长，固定右边距对长标题不够：
    // 由 w = 文字宽 + left + right 且 right ≥ (1-_notchTipX)*w + gap
    // 反解 right，保证文字右缘与凹口尖恒有 gap 间隙
    final left = theme.spacing.xl;
    final gap = theme.spacing.sm;
    final minRight = theme.spacing.xxxl;
    var right = minRight;
    if (padding == null) {
      final textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
      )..layout();
      final required =
          ((1 - _notchTipX) * (textPainter.width + left) + gap) /
          _notchTipX;
      if (required > right) right = required;
    }

    final content = Padding(
      padding:
          padding ??
          EdgeInsets.only(
            left: left,
            right: right,
            top: theme.spacing.sm,
            bottom: theme.spacing.sm,
          ),
      child: Text(text, style: style),
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
      // 右端 V 形燕尾凹口：右上(0.88w,0) → 尖(_notchTipX*w,0.5h) → 右下(0.88w,h)
      drawConfig.randomizer.reset();
      final generator = Generator(drawConfig, SolidFiller());
      final drawable = generator.polygon([
        PointD(0, 0),
        PointD(w * 0.88, 0),
        PointD(w * DsTitleBanner._notchTipX, h / 2),
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
