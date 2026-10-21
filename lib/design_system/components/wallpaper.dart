import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 壁纸底纹图案
enum DsWallpaperPattern {
  /// 双层规则波点（手账贴纸底纹，复用 [DsPolkaPatternPainter]）
  polka,

  /// 糖霜彩粒：固定 seed 撒粉彩小圆点与短线
  sprinkles,

  /// 横竖细网格线
  grid,
}

/// 手绘壁纸：铺在内容之下的整片底纹（CustomPainter，零交互）
///
/// ```dart
/// DsWallpaper(
///   pattern: DsWallpaperPattern.sprinkles,
///   child: pageContent,
/// )
/// ```
///
/// [color] 覆写底纹颜色；sprinkles 默认取 [DsAccentColors]
/// 全 12 粉彩随机（传 [color] 则单色糖霜）。
class DsWallpaper extends StatelessWidget {
  const DsWallpaper({
    super.key,
    this.pattern = DsWallpaperPattern.polka,
    this.color,
    this.child,
    this.ignorePointer = true,
  });

  final DsWallpaperPattern pattern;

  /// 底纹颜色覆写（null = 各图案的主题默认色）
  final Color? color;

  /// 铺在底纹之上的内容
  final Widget? child;

  /// 底纹层是否忽略指针（默认 true，不挡内容交互）
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final painter = switch (pattern) {
      DsWallpaperPattern.polka => DsPolkaPatternPainter(
        color:
            color ?? theme.ink.withValues(alpha: theme.isDark ? 0.20 : 0.13),
      ),
      DsWallpaperPattern.grid => _GridPatternPainter(
        color: color ?? theme.ink.withValues(alpha: 0.08),
      ),
      DsWallpaperPattern.sprinkles => _SprinklesPatternPainter(color: color),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: ignorePointer,
            child: CustomPaint(painter: painter),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// 细网格：横竖细线，间隔 24、淡墨色
class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter({required this.color});

  final Color color;

  static const double _step = 24;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = color;
    for (var x = _step; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = _step; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 糖霜彩粒：固定 seed（Random(7)）撒粉彩小元素
///
/// 每 90x90 约一枚：小圆（r 2~4）或短线（4~8px，随机角度），
/// 色板取 [DsAccentColors] 全 12 色随机；seed 固定，
/// 同尺寸 rebuild 不抖变。
class _SprinklesPatternPainter extends CustomPainter {
  const _SprinklesPatternPainter({this.color});

  /// 单色覆写（null = 粉彩随机）
  final Color? color;

  static const double _densityCell = 90;

  static const List<Color> _palette = [
    DsAccentColors.pink,
    DsAccentColors.red,
    DsAccentColors.orange,
    DsAccentColors.amber,
    DsAccentColors.sky,
    DsAccentColors.blue,
    DsAccentColors.cyan,
    DsAccentColors.teal,
    DsAccentColors.emerald,
    DsAccentColors.indigo,
    DsAccentColors.violet,
    DsAccentColors.slate,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(7);
    final count =
        (size.width / _densityCell * size.height / _densityCell).round();
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    for (var i = 0; i < count; i++) {
      final c = color ?? _palette[random.nextInt(_palette.length)];
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      if (random.nextBool()) {
        // 小圆：r 2~4
        fill.color = c;
        canvas.drawCircle(center, 2 + random.nextDouble() * 2, fill);
      } else {
        // 短线：长 4~8，随机角度
        final angle = random.nextDouble() * math.pi * 2;
        final half = (2 + random.nextDouble() * 2);
        final delta = Offset(math.cos(angle), math.sin(angle)) * half;
        stroke.color = c;
        canvas.drawLine(center - delta, center + delta, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_SprinklesPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
