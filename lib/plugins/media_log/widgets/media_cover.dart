import 'package:flutter/widgets.dart';
import 'package:aboutme/widgets/adaptive_image.dart';

import '../models/media_item.dart';

/// 媒体封面展示：用户上传图片优先，否则程序化手绘封面
///
/// 放入 [AspectRatio] 或任意有界父级中使用，自动铺满。
class MediaCoverView extends StatelessWidget {
  const MediaCoverView({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final image = item.coverImage;
    if (image != null && image.isNotEmpty) {
      return AdaptiveImage(imagePath: image, fit: BoxFit.cover, borderRadius: 0);
    }
    return MediaCover(style: item.cover);
  }
}

/// 程序化媒体封面（替代真实封面图，墨线风格与全局一致）
///
/// 迁移自 ai_picks_demo/book_cover.dart。
class MediaCover extends StatelessWidget {
  const MediaCover({super.key, required this.style});

  final CoverStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MediaCoverPainter(style),
      size: Size.infinite,
    );
  }
}

class _MediaCoverPainter extends CustomPainter {
  _MediaCoverPainter(this.style);

  final CoverStyle style;

  // 封面插画用色（内容配色，同图片资源，不随主题切换）
  static const _ink = Color(0xFF2B2B2B);
  static const _paper = Color(0xFFF7F3EC);

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case CoverStyle.sheep:
        _sheep(canvas, size);
      case CoverStyle.ring:
        _ring(canvas, size);
      case CoverStyle.bellJar:
        _bellJar(canvas, size);
      case CoverStyle.collage:
        _collage(canvas, size);
      case CoverStyle.siddhartha:
        _siddhartha(canvas, size);
      case CoverStyle.beauty:
        _beauty(canvas, size);
      case CoverStyle.norwegianWood:
        _norwegianWood(canvas, size);
      case CoverStyle.kafka:
        _kafka(canvas, size);
      case CoverStyle.tsukuru:
        _tsukuru(canvas, size);
      case CoverStyle.journals:
        _journals(canvas, size);
      case CoverStyle.poems:
        _poems(canvas, size);
      case CoverStyle.pinball:
        _pinball(canvas, size);
      case CoverStyle.filmReel:
        _filmReel(canvas, size);
      case CoverStyle.clapper:
        _clapper(canvas, size);
      case CoverStyle.ticket:
        _ticket(canvas, size);
      case CoverStyle.popcorn:
        _popcorn(canvas, size);
    }
  }

  Rect _r(Size s) => Offset.zero & s;

  void _text(
    Canvas canvas,
    String value,
    Offset offset, {
    double fontSize = 8,
    Color color = _ink,
    bool bold = false,
    double rotation = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    if (rotation != 0) canvas.rotate(rotation);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// A Wild Sheep Chase：天空 + 雪山 + 粉/绿撞色带 + 羊剪影
  void _sheep(Canvas canvas, Size s) {
    final skyH = s.height * 0.58;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, skyH),
      Paint()..color = const Color(0xFFCBE0E4),
    );
    // 雪山
    final mountain = Paint()..color = const Color(0xFFF4F1EA);
    for (final (dx, w, h) in [(0.0, 0.55, 0.34), (0.35, 0.6, 0.4), (0.68, 0.5, 0.3)]) {
      final path = Path()
        ..moveTo(s.width * dx, skyH)
        ..lineTo(s.width * (dx + w / 2), skyH - s.height * h)
        ..lineTo(s.width * (dx + w), skyH)
        ..close();
      canvas.drawPath(path, mountain);
    }
    // 粉带
    canvas.drawRect(
      Rect.fromLTWH(0, skyH, s.width, s.height * 0.16),
      Paint()..color = const Color(0xFFEBA0A6),
    );
    // 绿带
    canvas.drawRect(
      Rect.fromLTWH(0, skyH + s.height * 0.16, s.width, s.height),
      Paint()..color = const Color(0xFF7CAD55),
    );
    // 羊剪影
    final sheep = Paint()..color = const Color(0xFF3E4A5E);
    final cx = s.width * 0.42;
    final cy = skyH + s.height * 0.05;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: s.width * 0.34, height: s.height * 0.09), sheep);
    canvas.drawCircle(Offset(cx + s.width * 0.2, cy - s.height * 0.045), s.width * 0.055, sheep);
    for (final dx in [-0.12, -0.04, 0.06, 0.14]) {
      canvas.drawRect(Rect.fromLTWH(cx + s.width * dx, cy + s.height * 0.035, 2.5, s.height * 0.055), sheep);
    }
    _text(canvas, 'Murakami', Offset(s.width - 11, s.height * 0.62), fontSize: 7, rotation: 1.5708);
    _text(canvas, 'A Wild\nSheep Chase', Offset(8, s.height - 30), fontSize: 7, color: const Color(0xFFF2E9D8));
  }

  /// On the Road：灰底 + 黑圆环 + 中点
  void _ring(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFE6E4DF));
    final c = Offset(s.width * 0.42, s.height * 0.5);
    canvas.drawCircle(c, s.width * 0.3, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.045);
    canvas.drawCircle(c, s.width * 0.02, Paint()..color = _ink);
    _text(canvas, 'On the Road', Offset(s.width - 14, s.height * 0.12), fontSize: 7, rotation: 1.5708);
    _text(canvas, 'Jack Kerouac', Offset(s.width - 13, s.height * 0.6), fontSize: 6, rotation: 1.5708);
  }

  /// The Bell Jar：白底 + 指纹状同心圆 + 顶部标题
  void _bellJar(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = _paper);
    _text(canvas, 'THE BELL JAR', Offset(10, 12), fontSize: 11, color: const Color(0xFF8C8C3A), bold: true);
    final band = Rect.fromLTWH(10, 26, s.width * 0.72, 14);
    canvas.drawRect(band, Paint()..color = _ink);
    _text(canvas, 'SYLVIA PLATH', const Offset(13, 28), fontSize: 8, color: _paper, bold: true);
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final c = Offset(s.width * 0.5, s.height * 0.62);
    for (var i = 0; i < 15; i++) {
      canvas.drawCircle(c, 6.0 + i * s.width * 0.033, stroke);
    }
  }

  /// The Master and Margarita：彩色拼贴小人
  void _collage(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF9CC4BB));
    final fill = Paint()..style = PaintingStyle.fill;
    // 植物
    fill.color = const Color(0xFF4F7D52);
    for (final (dx, h) in [(0.08, 0.3), (0.2, 0.42), (0.82, 0.36)]) {
      final path = Path()
        ..moveTo(s.width * dx, s.height)
        ..quadraticBezierTo(s.width * (dx + 0.12), s.height * (1 - h), s.width * (dx + 0.24), s.height)
        ..close();
      canvas.drawPath(path, fill);
    }
    // 红袍人物
    fill.color = const Color(0xFFC4453C);
    final body = Path()
      ..moveTo(s.width * 0.3, s.height)
      ..lineTo(s.width * 0.42, s.height * 0.4)
      ..lineTo(s.width * 0.56, s.height * 0.4)
      ..lineTo(s.width * 0.68, s.height)
      ..close();
    canvas.drawPath(body, fill);
    // 黄脸 + 帽
    fill.color = const Color(0xFFF2C14E);
    canvas.drawCircle(Offset(s.width * 0.49, s.height * 0.32), s.width * 0.11, fill);
    fill.color = _ink;
    final hat = Path()
      ..moveTo(s.width * 0.36, s.height * 0.28)
      ..lineTo(s.width * 0.49, s.height * 0.16)
      ..lineTo(s.width * 0.62, s.height * 0.28)
      ..close();
    canvas.drawPath(hat, fill);
    // 紫衣小人 + 猫
    fill.color = const Color(0xFF7B5EA7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.62, s.height * 0.6, s.width * 0.26, s.height * 0.4), const Radius.circular(12)),
      fill,
    );
    fill.color = const Color(0xFFF2C14E);
    canvas.drawCircle(Offset(s.width * 0.75, s.height * 0.56), s.width * 0.07, fill);
    fill.color = const Color(0xFFF4F1EA);
    canvas.drawOval(Rect.fromCenter(center: Offset(s.width * 0.2, s.height * 0.72), width: s.width * 0.24, height: s.height * 0.1), fill);
    fill.color = _ink;
    canvas.drawCircle(Offset(s.width * 0.12, s.height * 0.66), s.width * 0.045, fill);
    // 星星点缀
    fill.color = const Color(0xFFF2C14E);
    for (final (dx, dy) in [(0.12, 0.16), (0.82, 0.12), (0.68, 0.3)]) {
      canvas.drawCircle(Offset(s.width * dx, s.height * dy), 2.5, fill);
    }
  }

  /// Siddhartha：橙底 + 拱门
  void _siddhartha(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFE3A94E));
    _text(canvas, 'SIDDHARTHA', Offset(10, 12), fontSize: 10, color: const Color(0xFF6B421C), bold: true);
    _text(canvas, 'Hermann Hesse', Offset(10, 24), fontSize: 6, color: const Color(0xFF6B421C));
    // 拱门
    final arch = Path()
      ..addArc(Rect.fromLTWH(s.width * 0.2, s.height * 0.32, s.width * 0.6, s.width * 0.6), 3.1416, 3.1416)
      ..lineTo(s.width * 0.8, s.height * 0.9)
      ..lineTo(s.width * 0.2, s.height * 0.9)
      ..close();
    canvas.drawPath(arch, Paint()..color = const Color(0xFF3A2A1A));
    // 门内人影
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.6), s.width * 0.06, Paint()..color = const Color(0xFFE3A94E));
  }

  /// History of Beauty：蓝底 + 侧脸
  void _beauty(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF4E7CA1));
    _text(canvas, 'HISTORY\nOF BEAUTY', Offset(10, 12), fontSize: 8, color: _paper, bold: true);
    _text(canvas, 'Umberto Eco', Offset(10, 38), fontSize: 6, color: const Color(0xFFD8E2EA));
    // 侧脸轮廓（浅色）
    final skin = Paint()..color = const Color(0xFFE8C9A8);
    final face = Path()
      ..moveTo(s.width * 0.62, s.height * 0.18)
      ..quadraticBezierTo(s.width * 0.95, s.height * 0.2, s.width * 0.92, s.height * 0.52)
      ..quadraticBezierTo(s.width * 0.9, s.height * 0.62, s.width * 0.8, s.height * 0.66)
      ..quadraticBezierTo(s.width * 0.84, s.height * 0.74, s.width * 0.74, s.height * 0.78)
      ..quadraticBezierTo(s.width * 0.7, s.height * 0.86, s.width * 0.6, s.height * 0.9)
      ..lineTo(s.width * 0.55, s.height * 0.2)
      ..close();
    canvas.drawPath(face, skin);
    // 眼
    canvas.drawCircle(Offset(s.width * 0.74, s.height * 0.42), 2, Paint()..color = _ink);
  }

  /// Norwegian Wood：橙底 + 黑色林线
  void _norwegianWood(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFD96C2C));
    _text(canvas, 'Norwegian Wood', Offset(10, 14), fontSize: 9, color: _paper, bold: true);
    _text(canvas, 'Haruki Murakami', Offset(10, 27), fontSize: 6, color: const Color(0xFFF3D9C2));
    final ink = Paint()..color = const Color(0xFF33241A);
    final base = s.height * 0.78;
    canvas.drawRect(Rect.fromLTWH(0, base, s.width, s.height - base), ink);
    for (final dx in [0.1, 0.3, 0.52, 0.74, 0.9]) {
      final h = s.height * (0.16 + (dx * 10 % 3) * 0.03);
      final path = Path()
        ..moveTo(s.width * dx - 10, base)
        ..lineTo(s.width * dx, base - h)
        ..lineTo(s.width * dx + 10, base)
        ..close();
      canvas.drawPath(path, ink);
    }
  }

  /// Kafka on the Shore：黑底 + 红色大鱼 + 少年
  void _kafka(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF1E1E24));
    _text(canvas, 'Kafka on the Shore', Offset(10, 14), fontSize: 8, color: _paper, bold: true);
    final fish = Paint()..color = const Color(0xFFC4453C);
    canvas.drawOval(Rect.fromCenter(center: Offset(s.width * 0.5, s.height * 0.55), width: s.width * 0.62, height: s.height * 0.16), fish);
    final tail = Path()
      ..moveTo(s.width * 0.78, s.height * 0.55)
      ..lineTo(s.width * 0.94, s.height * 0.46)
      ..lineTo(s.width * 0.94, s.height * 0.64)
      ..close();
    canvas.drawPath(tail, fish);
    fish.color = const Color(0xFFF2C14E);
    canvas.drawCircle(Offset(s.width * 0.28, s.height * 0.52), 2.5, fish);
    // 少年剪影
    final boy = Paint()..color = _paper;
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.8), s.width * 0.05, boy);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.46, s.height * 0.84, s.width * 0.08, s.height * 0.12), boy);
  }

  /// Colorless Tsukuru：黄底 + 彩色斑点
  void _tsukuru(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFF2D54E));
    _text(canvas, 'Colorless\nTsukuru', Offset(10, 14), fontSize: 9, color: _ink, bold: true);
    _text(canvas, 'Murakami', Offset(10, 40), fontSize: 6);
    final blobs = [
      (0.3, 0.62, 0.14, const Color(0xFFC4453C)),
      (0.62, 0.56, 0.1, const Color(0xFF4E7CA1)),
      (0.48, 0.74, 0.12, const Color(0xFF7B5EA7)),
      (0.74, 0.72, 0.08, const Color(0xFF4F7D52)),
    ];
    for (final (dx, dy, r, c) in blobs) {
      canvas.drawCircle(Offset(s.width * dx, s.height * dy), s.width * r, Paint()..color = c);
    }
  }

  /// The Unabridged Journals：深底 + 白色胸像
  void _journals(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF2A2118));
    _text(canvas, 'THE UNABRIDGED\nJOURNALS', Offset(8, 12), fontSize: 7, color: const Color(0xFFCBB26A), bold: true);
    _text(canvas, 'SYLVIA PLATH', Offset(8, 30), fontSize: 6, color: const Color(0xFFCBB26A));
    final ivory = Paint()..color = const Color(0xFFE8E0D0);
    final c = Offset(s.width * 0.5, s.height * 0.68);
    canvas.drawOval(Rect.fromCenter(center: c, width: s.width * 0.5, height: s.height * 0.34), ivory);
    canvas.drawCircle(Offset(c.dx, c.dy - s.height * 0.12), s.width * 0.13, ivory);
    final line = Paint()
      ..color = _ink
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - s.width * 0.06, c.dy - s.height * 0.14), Offset(c.dx + s.width * 0.06, c.dy - s.height * 0.14), line);
    canvas.drawLine(Offset(c.dx, c.dy - s.height * 0.12), Offset(c.dx, c.dy - s.height * 0.04), line);
  }

  /// Selected Poems：金底 + 题字
  void _poems(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFC9A227));
    _text(canvas, 'Sylvia Plath', Offset(12, 16), fontSize: 9, color: const Color(0xFF4A3A12), bold: true);
    _text(canvas, 'Selected\nPoems', Offset(12, s.height * 0.4), fontSize: 15, color: const Color(0xFF4A3A12));
  }

  /// Pinball 1973：黄底红圆
  void _pinball(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFF2C94C));
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.5), s.width * 0.3, Paint()..color = const Color(0xFFC4453C));
    _text(canvas, 'Pinball 1973', Offset(10, 14), fontSize: 9, color: _ink, bold: true);
  }

  /// Film Reel：深底胶片盘 + 齿孔（观影封面）
  void _filmReel(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF23272E));
    // 胶片条（左右两侧齿孔）
    final film = Paint()..color = const Color(0xFF3A4048);
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width * 0.16, s.height), film);
    canvas.drawRect(Rect.fromLTWH(s.width * 0.84, 0, s.width * 0.16, s.height), film);
    final hole = Paint()..color = const Color(0xFFF2E9D8);
    for (var i = 0; i < 7; i++) {
      final dy = s.height * (0.06 + i * 0.145);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.03, dy, s.width * 0.1, s.height * 0.035),
          const Radius.circular(2),
        ),
        hole,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.width * 0.87, dy, s.width * 0.1, s.height * 0.035),
          const Radius.circular(2),
        ),
        hole,
      );
    }
    // 中央胶片盘
    final c = Offset(s.width * 0.5, s.height * 0.52);
    canvas.drawCircle(c, s.width * 0.26, Paint()..color = const Color(0xFF4A5260));
    canvas.drawCircle(c, s.width * 0.24, Paint()
      ..color = const Color(0xFF23272E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    // 四向片孔（右/下/左/上）
    for (final (dx, dy) in [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)]) {
      canvas.drawCircle(
        Offset(c.dx + s.width * 0.14 * dx, c.dy + s.width * 0.14 * dy),
        s.width * 0.06,
        Paint()..color = const Color(0xFF23272E),
      );
    }
    canvas.drawCircle(c, s.width * 0.045, Paint()..color = const Color(0xFFF2C14E));
    _text(canvas, 'NOW SHOWING', Offset(s.width * 0.5 - 26, s.height * 0.9), fontSize: 6, color: const Color(0xFFF2E9D8), bold: true);
  }

  /// Clapperboard：场记板（观影封面）
  void _clapper(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFF2E4A5E));
    // 顶部斜纹板
    final stripe = Paint()..color = const Color(0xFFF2E9D8);
    final ink = Paint()..color = _ink;
    final topH = s.height * 0.2;
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, topH), stripe);
    final stripeW = s.width / 5;
    for (var i = 0; i < 5; i += 2) {
      canvas.drawRect(Rect.fromLTWH(stripeW * i, 0, stripeW, topH), ink);
    }
    // 板体与铰链
    canvas.drawRect(Rect.fromLTWH(0, topH + 4, s.width, s.height * 0.62), Paint()..color = const Color(0xFF1F2A33));
    canvas.drawCircle(Offset(s.width * 0.12, topH + 2), 3, ink);
    canvas.drawCircle(Offset(s.width * 0.88, topH + 2), 3, ink);
    // 场记文字
    _text(canvas, 'SCENE 01', Offset(s.width * 0.14, s.height * 0.34), fontSize: 8, color: const Color(0xFFF2E9D8), bold: true);
    _text(canvas, 'TAKE 03', Offset(s.width * 0.14, s.height * 0.45), fontSize: 6, color: const Color(0xFF9FB3C4));
    // 底部装饰线
    final line = Paint()
      ..color = const Color(0xFFF2C14E)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(s.width * 0.14, s.height * 0.72), Offset(s.width * 0.86, s.height * 0.72), line);
  }

  /// Ticket：电影票根（观影封面）
  void _ticket(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFE8B04B));
    // 票面主体
    final body = Rect.fromLTWH(s.width * 0.06, s.height * 0.16, s.width * 0.88, s.height * 0.68);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(6)), Paint()..color = const Color(0xFFF7F3EC));
    // 撕票虚线
    final dash = Paint()
      ..color = const Color(0xFFC9A227)
      ..strokeWidth = 1.5;
    for (var y = body.top + 4; y < body.bottom - 2; y += 8) {
      canvas.drawLine(Offset(s.width * 0.72, y), Offset(s.width * 0.72, y + 4), dash);
    }
    _text(canvas, 'ADMIT', Offset(s.width * 0.14, s.height * 0.24), fontSize: 9, color: _ink, bold: true);
    _text(canvas, 'ONE', Offset(s.width * 0.14, s.height * 0.33), fontSize: 7, color: const Color(0xFF6B421C));
    // 座位号
    _text(canvas, 'ROW G', Offset(s.width * 0.14, s.height * 0.55), fontSize: 6, color: const Color(0xFF6B421C));
    _text(canvas, 'SEAT 12', Offset(s.width * 0.14, s.height * 0.63), fontSize: 6, color: const Color(0xFF6B421C));
    _text(canvas, '7:30 PM', Offset(s.width * 0.76, s.height * 0.55), fontSize: 6, color: const Color(0xFF6B421C), rotation: 1.5708);
    // 底部星星
    canvas.drawCircle(Offset(s.width * 0.5, s.height * 0.92), 2.5, Paint()..color = _ink);
  }

  /// Popcorn：爆米花桶（观影封面）
  void _popcorn(Canvas canvas, Size s) {
    canvas.drawRect(_r(s), Paint()..color = const Color(0xFFB3513F));
    // 爆米花球
    final corn = Paint()..color = const Color(0xFFF2E9D8);
    final blobs = [
      (0.3, 0.14, 0.11), (0.52, 0.12, 0.10), (0.7, 0.16, 0.09),
      (0.4, 0.26, 0.10), (0.62, 0.27, 0.09),
    ];
    for (final (dx, dy, r) in blobs) {
      canvas.drawCircle(Offset(s.width * dx, s.height * dy), s.width * r, corn);
    }
    // 红白条纹桶身
    final white = Paint()..color = const Color(0xFFF7F3EC);
    final red = Paint()..color = const Color(0xFFC4453C);
    final body = Rect.fromLTWH(s.width * 0.18, s.height * 0.34, s.width * 0.64, s.height * 0.5);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(4)), white);
    final stripeW = s.width * 0.64 / 5;
    for (var i = 0; i < 5; i += 2) {
      canvas.drawRect(Rect.fromLTWH(body.left + stripeW * i, body.top, stripeW, body.height), red);
    }
    // 桶箍
    canvas.drawRect(Rect.fromLTWH(body.left, body.top, body.width, s.height * 0.05), Paint()..color = _ink);
    canvas.drawRect(Rect.fromLTWH(body.left, body.bottom - s.height * 0.04, body.width, s.height * 0.04), Paint()..color = _ink);
    _text(canvas, 'POPCORN', Offset(body.left + 2, body.top + body.height * 0.42), fontSize: 7, color: _ink, bold: true);
  }

  @override
  bool shouldRepaint(_MediaCoverPainter oldDelegate) => oldDelegate.style != style;
}
