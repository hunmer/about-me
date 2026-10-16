import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'scrapbook_item_models.dart';

/// 网格背景绘制器（视口坐标系，随 pan/zoom 同步）
class ScrapGridPainter extends CustomPainter {
  final double panX;
  final double panY;
  final double zoom;
  final double gridSize;
  final Color color;

  ScrapGridPainter({
    required this.panX,
    required this.panY,
    required this.zoom,
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final g = gridSize * zoom;
    if (g < 4) return;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;
    final startX = panX % g;
    for (double x = startX; x <= size.width; x += g) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final startY = panY % g;
    for (double y = startY; y <= size.height; y += g) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScrapGridPainter oldDelegate) =>
      oldDelegate.panX != panX ||
      oldDelegate.panY != panY ||
      oldDelegate.zoom != zoom ||
      oldDelegate.color != color;
}

/// 静态手绘装饰：蓝色飞机弯箭头 + 黑色铁路轨道（画布平面坐标系）
class ScrapDoodleDecorPainter extends CustomPainter {
  final Color railColor;
  final Color railFillColor;

  ScrapDoodleDecorPainter({required this.railColor, required this.railFillColor});

  @override
  void paint(Canvas canvas, Size size) {
    const blue = Color(0xFF56A8E8);
    final bluePaint =
        Paint()
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // 1. 蓝色手绘弯箭头
    final arrow =
        Path()
          ..moveTo(122, 252)
          ..cubicTo(138, 230, 152, 232, 150, 247)
          ..cubicTo(148, 262, 134, 256, 141, 236)
          ..cubicTo(147, 219, 156, 212, 162, 206);
    canvas.drawPath(arrow, bluePaint);

    // 箭头末端的小飞机（translate(157,191) rotate(-32°)）
    canvas.save();
    canvas.translate(157, 191);
    canvas.rotate(-32 * math.pi / 180);
    final plane =
        Path()
          ..moveTo(2, 7)
          ..lineTo(13, 7)
          ..moveTo(7.5, 1.5)
          ..lineTo(9.5, 7)
          ..lineTo(7.5, 12.5)
          ..moveTo(3.5, 4.5)
          ..lineTo(5.5, 7)
          ..lineTo(3.5, 9.5);
    canvas.drawPath(plane, bluePaint);
    canvas.restore();

    // 2. 蜿蜒铁路轨道
    final fillPath =
        Path()
          ..moveTo(110, 662)
          ..cubicTo(104, 686, 86, 715, 92, 746)
          ..cubicTo(97, 772, 132, 786, 174, 756)
          ..cubicTo(188, 746, 200, 738, 208, 733)
          ..lineTo(208, 712)
          ..cubicTo(194, 720, 178, 734, 162, 742)
          ..cubicTo(138, 754, 120, 742, 124, 716)
          ..cubicTo(128, 692, 132, 676, 127, 662)
          ..close();
    canvas.drawPath(fillPath, Paint()..color = railFillColor);

    final railPaint =
        Paint()
          ..color = railColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round;
    final outerRail =
        Path()
          ..moveTo(110, 661)
          ..cubicTo(103, 688, 86, 716, 92, 747)
          ..cubicTo(97, 774, 134, 786, 176, 755)
          ..cubicTo(190, 745, 201, 738, 209, 733);
    canvas.drawPath(outerRail, railPaint);
    final innerRail =
        Path()
          ..moveTo(127, 661)
          ..cubicTo(132, 680, 127, 696, 124, 718)
          ..cubicTo(120, 742, 139, 753, 163, 741)
          ..cubicTo(179, 733, 193, 720, 208, 712);
    canvas.drawPath(innerRail, railPaint);

    // 枕木
    final sleeperPaint =
        Paint()
          ..color = railColor
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
    const sleepers = [
      [108.0, 671.0, 128.0, 672.0],
      [104.0, 683.0, 128.0, 686.0],
      [99.0, 696.0, 126.0, 700.0],
      [94.0, 710.0, 124.0, 714.0],
      [91.0, 725.0, 123.0, 726.0],
      [91.0, 740.0, 124.0, 736.0],
      [96.0, 756.0, 128.0, 743.0],
      [107.0, 769.0, 134.0, 747.0],
      [124.0, 775.0, 142.0, 749.0],
      [143.0, 773.0, 152.0, 746.0],
      [161.0, 765.0, 163.0, 741.0],
      [176.0, 755.0, 174.0, 734.0],
      [189.0, 746.0, 186.0, 726.0],
      [201.0, 738.0, 198.0, 718.0],
    ];
    for (final s in sleepers) {
      canvas.drawLine(Offset(s[0], s[1]), Offset(s[2], s[3]), sleeperPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ScrapDoodleDecorPainter oldDelegate) =>
      oldDelegate.railColor != railColor ||
      oldDelegate.railFillColor != railFillColor;
}

/// 用户涂鸦笔画绘制器（画布平面坐标系，圆头线帽 2.2px）
class ScrapStrokesPainter extends CustomPainter {
  final List<ScrapStroke> strokes;

  ScrapStrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      final paint =
          Paint()
            ..color = stroke.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final p in stroke.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScrapStrokesPainter oldDelegate) => true;
}

/// 选中虚线框
class ScrapDashedRectPainter extends CustomPainter {
  final Color color;
  final double inset;

  ScrapDashedRectPainter({required this.color, this.inset = -6});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    const dash = 4.0;
    const gap = 3.0;

    void drawDashedLine(Offset a, Offset b) {
      final total = (b - a).distance;
      if (total == 0) return;
      final dir = (b - a) / total;
      double d = 0;
      while (d < total) {
        final end = math.min(d + dash, total);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d = end + gap;
      }
    }

    drawDashedLine(rect.topLeft, rect.topRight);
    drawDashedLine(rect.topRight, rect.bottomRight);
    drawDashedLine(rect.bottomRight, rect.bottomLeft);
    drawDashedLine(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(covariant ScrapDashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 标题红色波浪下划线
class ScrapSquigglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36;
    final sy = size.height / 10;
    canvas.scale(sx, sy);
    final paint =
        Paint()
          ..color = const Color(0xFFE44C39)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 / ((sx + sy) / 2)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final path =
        Path()
          ..moveTo(3, 3.5)
          ..lineTo(29, 2.2)
          ..lineTo(9, 6.5)
          ..lineTo(31, 6.2)
          ..lineTo(16, 8.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 飞机窗：黎明天空渐变 + 云海
class ScrapAirplaneWindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF6B7A99),
        Color(0xFF9A8FA6),
        Color(0xFFD49B94),
        Color(0xFFE59872),
        Color(0xFF3E323B),
        Color(0xFF221C24),
      ],
      stops: const [0.0, 0.35, 0.62, 0.78, 0.9, 1.0],
    );
    canvas.drawRect(
      Offset.zero & Size(w, h),
      Paint()..shader = gradient.createShader(Offset.zero & Size(w, h)),
    );
    // 地平线光带
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.73),
        width: w * 1.3,
        height: h * 0.125,
      ),
      Paint()..color = const Color(0xA6FFAE78),
    );
    // 云海与机翼剪影
    final cloud1 =
        Path()
          ..moveTo(0, h * 0.78)
          ..quadraticBezierTo(w * 0.32, h * 0.72, w * 0.68, h * 0.76)
          ..quadraticBezierTo(w * 0.85, h * 0.78, w, h * 0.74)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(cloud1, Paint()..color = const Color(0xFF2A2229));
    final cloud2 =
        Path()
          ..moveTo(0, h * 0.83)
          ..quadraticBezierTo(w * 0.44, h * 0.79, w, h * 0.82)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    canvas.drawPath(cloud2, Paint()..color = const Color(0xFF1A151B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 拱形裁剪（富士山照片）
class ScrapArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.88, h * 0.28)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(w * 0.12, h * 0.28)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 富士山 + 雪顶 + 秋叶 + 轨道
class ScrapFujiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 44;
    final sy = size.height / 48;
    canvas.scale(sx, sy);

    canvas.drawRect(const Rect.fromLTWH(0, 0, 44, 48), Paint()..color = const Color(0xFFCFE2F3));
    // 山体
    final mountain =
        Path()
          ..moveTo(4, 34)
          ..lineTo(17, 11)
          ..lineTo(27, 11)
          ..lineTo(40, 34)
          ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF4A6984));
    // 雪顶
    final snow =
        Path()
          ..moveTo(17, 11)
          ..lineTo(27, 11)
          ..lineTo(31, 19)
          ..lineTo(26, 17)
          ..lineTo(22, 20)
          ..lineTo(18, 17)
          ..lineTo(13, 19)
          ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
    // 两侧秋叶
    canvas.drawCircle(const Offset(6, 28), 9, Paint()..color = const Color(0xFFC84B31));
    canvas.drawCircle(const Offset(38, 28), 9, Paint()..color = const Color(0xFFD96B27));
    canvas.drawCircle(const Offset(4, 36), 8, Paint()..color = const Color(0xFF5C8244));
    canvas.drawCircle(const Offset(40, 36), 8, Paint()..color = const Color(0xFF4E7338));
    // 前景轨道
    final track =
        Path()
          ..moveTo(18, 32)
          ..lineTo(11, 48)
          ..lineTo(33, 48)
          ..lineTo(26, 32)
          ..close();
    canvas.drawPath(track, Paint()..color = const Color(0xFFD9D2C5));
    final railPaint =
        Paint()
          ..color = const Color(0xFF333333)
          ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(19, 32), const Offset(14, 48), railPaint);
    canvas.drawLine(const Offset(25, 32), const Offset(30, 48), railPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 新干线站台 + 红白列车
class ScrapShinkansenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 90;
    final sy = size.height / 134;
    canvas.scale(sx, sy);

    // 站台顶棚
    canvas.drawRect(const Rect.fromLTWH(0, 0, 90, 54), Paint()..color = const Color(0xFF4B473E));
    final roofLine =
        Paint()
          ..color = const Color(0xFF38342C)
          ..strokeWidth = 2;
    canvas.drawLine(const Offset(0, 18), const Offset(90, 18), roofLine);
    canvas.drawLine(const Offset(0, 36), const Offset(90, 36), roofLine);
    // 天空与山丘
    canvas.drawRect(const Rect.fromLTWH(0, 54, 90, 38), Paint()..color = const Color(0xFFDCE7EB));
    final hills =
        Path()
          ..moveTo(0, 78)
          ..quadraticBezierTo(25, 62, 55, 72)
          ..quadraticBezierTo(75, 77, 90, 66)
          ..lineTo(90, 92)
          ..lineTo(0, 92)
          ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF4F6F46));
    // 列车车身
    final body =
        Path()
          ..moveTo(18, 96)
          ..cubicTo(22, 76, 48, 68, 90, 66)
          ..lineTo(90, 108)
          ..lineTo(18, 108)
          ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFF7F7F7));
    // 车窗
    final windshield =
        Path()
          ..moveTo(26, 88)
          ..cubicTo(34, 78, 52, 74, 68, 74)
          ..lineTo(68, 85)
          ..lineTo(26, 88)
          ..close();
    canvas.drawPath(windshield, Paint()..color = const Color(0xFF1E242B));
    // 红色腰线
    final stripe =
        Path()
          ..moveTo(18, 96)
          ..cubicTo(26, 92, 55, 90, 90, 90)
          ..lineTo(90, 102)
          ..lineTo(18, 102)
          ..close();
    canvas.drawPath(stripe, Paint()..color = const Color(0xFFC92424));
    // 底部轨道
    canvas.drawRect(const Rect.fromLTWH(0, 108, 90, 26), Paint()..color = const Color(0xFF18181A));
    canvas.drawLine(
      const Offset(0, 115),
      const Offset(90, 115),
      Paint()
        ..color = const Color(0xFF555555)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 黄色毛绒玩具店
class ScrapPlushiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 92;
    final sy = size.height / 130;
    canvas.scale(sx, sy);

    canvas.drawRect(const Rect.fromLTWH(0, 0, 92, 130), Paint()..color = const Color(0xFFD8E2DC));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 92, 44), Paint()..color = const Color(0xFF5A8F48));
    canvas.drawCircle(const Offset(14, 24), 12, Paint()..color = const Color(0xFF76AA5E));
    canvas.drawCircle(const Offset(38, 18), 14, Paint()..color = const Color(0xFF467836));
    canvas.drawCircle(const Offset(66, 24), 13, Paint()..color = const Color(0xFF689F52));
    canvas.drawCircle(const Offset(22, 14), 4, Paint()..color = const Color(0xFFFF9EBB));
    canvas.drawCircle(const Offset(52, 22), 4.5, Paint()..color = const Color(0xFFFFD166));
    // 毛绒玩具
    canvas.drawOval(const Rect.fromLTWH(0, 66, 56, 60), Paint()..color = const Color(0xFFF5CC27));
    canvas.drawOval(const Rect.fromLTWH(46, 70, 52, 56), Paint()..color = const Color(0xFFEBBF1E));
    // 表情
    final dark = Paint()..color = const Color(0xFF2B1E16);
    canvas.drawCircle(const Offset(15, 86), 2.8, dark);
    canvas.drawCircle(const Offset(32, 87), 2.8, dark);
    canvas.drawOval(const Rect.fromLTWH(21, 88, 4, 2.4), dark);
    canvas.drawCircle(const Offset(9, 92), 4, Paint()..color = const Color(0xB3E85D56));
    canvas.drawCircle(const Offset(38, 93), 4, Paint()..color = const Color(0xB3E85D56));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 鱼板 swirl 边框（一排鸣人卷）
class ScrapNarutomakiRowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final count = (size.width / 16).floor().clamp(1, 12);
    final swirlPaint =
        Paint()
          ..color = const Color(0xFFE86F88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final center = Offset(8.0 + i * 16, size.height / 2);
      canvas.drawCircle(
        center,
        7.5,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        center,
        7.5,
        Paint()
          ..color = const Color(0xFFE5E0D5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      // 粉色旋涡：两段螺旋弧
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 4),
        0,
        math.pi * 1.7,
        false,
        swirlPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 1.8),
        math.pi * 0.8,
        math.pi * 1.7,
        false,
        swirlPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 红色四角星 sparkles
class ScrapSparklesPainter extends CustomPainter {
  const ScrapSparklesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 36;
    final sy = size.height / 34;
    canvas.scale(sx, sy);
    final paint =
        Paint()
          ..color = const Color(0xFFD93829)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeJoin = StrokeJoin.round;
    final big =
        Path()
          ..moveTo(18, 2)
          ..cubicTo(19, 10, 21, 12, 29, 13)
          ..cubicTo(21, 14, 19, 16, 18, 24)
          ..cubicTo(17, 16, 15, 14, 7, 13)
          ..cubicTo(15, 12, 17, 10, 18, 2)
          ..close();
    canvas.drawPath(big, paint);
    final small =
        Path()
          ..moveTo(9, 17)
          ..cubicTo(9.6, 22, 11, 23, 16, 23.5)
          ..cubicTo(11, 24, 9.6, 25, 9, 30)
          ..cubicTo(8.4, 25, 7, 24, 2, 23.5)
          ..cubicTo(7, 23, 8.4, 22, 9, 17)
          ..close();
    canvas.drawPath(small, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 云朵思考气泡
class ScrapCloudBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64;
    final sy = size.height / 50;
    canvas.scale(sx, sy);
    final fillPaint = Paint()..color = Colors.white;
    final strokePaint =
        Paint()
          ..color = const Color(0xFFD4D0C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    final cloud =
        Path()
          ..moveTo(16, 34)
          ..cubicTo(9, 34, 6, 28, 9, 23)
          ..cubicTo(6, 17, 11, 11, 18, 12)
          ..cubicTo(21, 6, 31, 5, 36, 10)
          ..cubicTo(43, 6, 52, 10, 52, 17)
          ..cubicTo(58, 19, 59, 27, 54, 31)
          ..cubicTo(55, 36, 48, 40, 42, 38)
          ..cubicTo(38, 42, 28, 42, 25, 38)
          ..cubicTo(21, 40, 16, 38, 16, 34)
          ..close();
    canvas.drawPath(cloud, fillPaint);
    canvas.drawPath(cloud, strokePaint);
    // 思考小圆点
    canvas.drawCircle(const Offset(14, 42), 2.6, fillPaint);
    canvas.drawCircle(const Offset(14, 42), 2.6, strokePaint..strokeWidth = 1.2);
    canvas.drawCircle(const Offset(9, 46), 1.6, fillPaint);
    canvas.drawCircle(const Offset(9, 46), 1.6, strokePaint..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
