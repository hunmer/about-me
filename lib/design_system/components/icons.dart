import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 图标种类（自绘矢量图标，避免依赖 Material Icons）
enum DsIconKind {
  check,
  minus,
  plus,
  close,
  heart,
  gear,
  search,
  chevronLeft,
  chevronRight,
  chevronDown,
  chevronUp,
  star,
  bell,
  home,
  chat,
  store,
  user,
  calendar,
  trash,
  share,
  download,
  more,
  moon,
  sun,
  book,
  calendarCheck,
  piggy,
  gift,
  drop,
  clipboard,
  sprout,
  cart,
}

/// 自绘图标组件：24x24 逻辑画布，线条圆头
class DsIcon extends StatelessWidget {
  const DsIcon(
    this.kind, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = false,
  });

  final DsIconKind kind;
  final double size;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? AppTheme.maybeOf(context)?.text ?? const Color(0xFF4C1D95);
    return CustomPaint(
      size: Size.square(size),
      painter: _DsIconPainter(kind, effectiveColor, fill),
    );
  }
}

class _DsIconPainter extends CustomPainter {
  const _DsIconPainter(this.kind, this.color, this.fill);

  final DsIconKind kind;
  final Color color;
  final bool fill;

  static const double _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final solid = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case DsIconKind.check:
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 12.5)
            ..lineTo(9.5, 17.5)
            ..lineTo(19.5, 6.5),
          stroke,
        );
      case DsIconKind.minus:
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), stroke);
      case DsIconKind.plus:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), stroke);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), stroke);
      case DsIconKind.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
      case DsIconKind.heart:
        canvas.drawPath(_heartPath(), fill ? solid : stroke..strokeWidth = 2);
      case DsIconKind.gear:
        _paintGear(canvas);
      case DsIconKind.search:
        canvas.drawCircle(const Offset(11, 11), 5.5, stroke);
        canvas.drawLine(
            const Offset(15.3, 15.3), const Offset(19.8, 19.8), stroke);
      case DsIconKind.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 6)
            ..lineTo(9, 12)
            ..lineTo(14.5, 18),
          stroke,
        );
      case DsIconKind.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 6)
            ..lineTo(15, 12)
            ..lineTo(9.5, 18),
          stroke,
        );
      case DsIconKind.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 9.5)
            ..lineTo(12, 15)
            ..lineTo(17.5, 9.5),
          stroke,
        );
      case DsIconKind.chevronUp:
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 14.5)
            ..lineTo(12, 9)
            ..lineTo(17.5, 14.5),
          stroke,
        );
      case DsIconKind.star:
        canvas.drawPath(_starPath(), solid);
      case DsIconKind.bell:
        canvas.drawPath(_bellPath(), solid);
        canvas.drawPath(
          Path()
            ..moveTo(10.1, 19)
            ..arcToPoint(const Offset(13.9, 19),
                radius: const Radius.circular(1.9)),
          stroke..strokeWidth = 2,
        );
      case DsIconKind.home:
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 11.2)
            ..lineTo(12, 4.2)
            ..lineTo(19.8, 11.2),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 10.4)
            ..lineTo(6.5, 19.6)
            ..lineTo(17.5, 19.6)
            ..lineTo(17.5, 10.4),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(10.3, 19.6)
            ..lineTo(10.3, 14.6)
            ..lineTo(13.7, 14.6)
            ..lineTo(13.7, 19.6),
          stroke,
        );
      case DsIconKind.chat:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3.5, 4.8, 20.5, 16.2),
            const Radius.circular(3.4),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8, 16.4)
            ..lineTo(8, 20.4)
            ..lineTo(12.4, 16.4),
          stroke,
        );
      case DsIconKind.store:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 8.8, 19, 19.8),
            const Radius.circular(2.6),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 8.8)
            ..lineTo(9, 7.2)
            ..arcToPoint(const Offset(15, 7.2),
                radius: const Radius.circular(3))
            ..lineTo(15, 8.8),
          stroke,
        );
      case DsIconKind.user:
        canvas.drawCircle(const Offset(12, 8.4), 3.5, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(5.4, 19.8)
            ..cubicTo(5.4, 16, 8.4, 14.2, 12, 14.2)
            ..cubicTo(15.6, 14.2, 18.6, 16, 18.6, 19.8),
          stroke,
        );
      case DsIconKind.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 5.6, 20, 19.6),
            const Radius.circular(2.8),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(4, 10), const Offset(20, 10), stroke);
        canvas.drawLine(const Offset(8.5, 3.6), const Offset(8.5, 7.2), stroke);
        canvas.drawLine(
            const Offset(15.5, 3.6), const Offset(15.5, 7.2), stroke);
      case DsIconKind.trash:
        canvas.drawLine(
            const Offset(4.6, 6.6), const Offset(19.4, 6.6), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9.8, 6.6)
            ..lineTo(9.8, 5)
            ..arcToPoint(const Offset(14.2, 5),
                radius: const Radius.circular(2.2), clockwise: false)
            ..lineTo(14.2, 6.6),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 6.6)
            ..lineTo(7.7, 18.8)
            ..arcToPoint(const Offset(9.7, 20.6),
                radius: const Radius.circular(2), clockwise: false)
            ..lineTo(14.3, 20.6)
            ..arcToPoint(const Offset(16.3, 18.8),
                radius: const Radius.circular(2), clockwise: false)
            ..lineTo(17, 6.6),
          stroke,
        );
      case DsIconKind.share:
        canvas.drawCircle(const Offset(6.2, 12), 2.4, stroke);
        canvas.drawCircle(const Offset(17.4, 5.8), 2.4, stroke);
        canvas.drawCircle(const Offset(17.4, 18.2), 2.4, stroke);
        canvas.drawLine(
            const Offset(8.4, 10.9), const Offset(15.2, 6.9), stroke);
        canvas.drawLine(
            const Offset(8.4, 13.1), const Offset(15.2, 17.1), stroke);
      case DsIconKind.download:
        canvas.drawLine(const Offset(12, 4.4), const Offset(12, 14), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(7.6, 10)
            ..lineTo(12, 14.4)
            ..lineTo(16.4, 10),
          stroke,
        );
        canvas.drawLine(
            const Offset(4.6, 19.6), const Offset(19.4, 19.6), stroke);
      case DsIconKind.more:
        canvas.drawCircle(const Offset(5, 12), 1.7, solid);
        canvas.drawCircle(const Offset(12, 12), 1.7, solid);
        canvas.drawCircle(const Offset(19, 12), 1.7, solid);
      case DsIconKind.moon:
        canvas.drawPath(_moonPath(), solid);
      case DsIconKind.sun:
        canvas.drawCircle(const Offset(12, 12), 3.7, stroke);
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(12, 12);
          canvas.rotate(i * math.pi / 4);
          canvas.drawLine(
              const Offset(0, -6.2), const Offset(0, -8.6), stroke);
          canvas.restore();
        }
      case DsIconKind.book:
        // 摊开的书：左右两页 + 中缝
        canvas.drawPath(
          Path()
            ..moveTo(12, 6.8)
            ..cubicTo(10.2, 5.0, 7.2, 4.6, 4.2, 5.2)
            ..lineTo(4.2, 18.6)
            ..cubicTo(7.2, 18.0, 10.2, 18.4, 12, 20.0)
            ..cubicTo(13.8, 18.4, 16.8, 18.0, 19.8, 18.6)
            ..lineTo(19.8, 5.2)
            ..cubicTo(16.8, 4.6, 13.8, 5.0, 12, 6.8)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(12, 7.2), const Offset(12, 19.6), stroke);
      case DsIconKind.calendarCheck:
        // 日历 + 对勾（打卡）
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 5.6, 20, 19.6),
            const Radius.circular(2.8),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(8.5, 3.6), const Offset(8.5, 7.2), stroke);
        canvas.drawLine(
            const Offset(15.5, 3.6), const Offset(15.5, 7.2), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(8.4, 12.8)
            ..lineTo(11.2, 15.5)
            ..lineTo(15.9, 10.3),
          stroke,
        );
      case DsIconKind.piggy:
        // 蓄钱罐：椭圆身体 + 左侧猪鼻 + 耳朵 + 硬币口 + 四腿简化为两腿
        canvas.drawOval(const Rect.fromLTRB(4.6, 8.0, 19.8, 18.0), stroke);
        canvas.drawLine(
            const Offset(10.6, 8.0), const Offset(14.0, 8.0), stroke);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(2.2, 11.0, 6.4, 14.8),
            const Radius.circular(1.9),
          ),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14.8, 8.4)
            ..lineTo(16.6, 5.8)
            ..lineTo(18.0, 8.6),
          stroke,
        );
        canvas.drawLine(const Offset(8.6, 18.0), const Offset(8.6, 20.2), stroke);
        canvas.drawLine(
            const Offset(15.8, 18.0), const Offset(15.8, 20.2), stroke);
      case DsIconKind.gift:
        // 礼盒：盒身 + 盖子 + 竖丝带 + 蝴蝶结
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 11, 19, 20.2),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(4, 7.4, 20, 11),
            const Radius.circular(1.8),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(12, 7.4), const Offset(12, 20.2), stroke);
        canvas.drawCircle(const Offset(9.1, 5.2), 2.1, stroke);
        canvas.drawCircle(const Offset(14.9, 5.2), 2.1, stroke);
      case DsIconKind.drop:
        // 水滴
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..cubicTo(9.8, 7.4, 5.5, 11.8, 5.5, 15.0)
            ..arcToPoint(
              const Offset(18.5, 15.0),
              radius: const Radius.circular(6.5),
              largeArc: false,
              clockwise: false,
            )
            ..cubicTo(18.5, 11.8, 14.2, 7.4, 12, 4)
            ..close(),
          stroke,
        );
      case DsIconKind.clipboard:
        // 任务剪贴板：板身 + 顶部夹子 + 两条清单线
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(5, 5.2, 19, 20.4),
            const Radius.circular(2.6),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(9, 3.2, 15, 7.0),
            const Radius.circular(1.5),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(8.6, 11.4), const Offset(15.4, 11.4), stroke);
        canvas.drawLine(const Offset(8.6, 15.2), const Offset(13.4, 15.2), stroke);
      case DsIconKind.sprout:
        // 嫩芽：土壤线 + 茎 + 左右两片叶子
        canvas.drawLine(const Offset(6.2, 20.2), const Offset(17.8, 20.2), stroke);
        canvas.drawLine(const Offset(12, 20.2), const Offset(12, 11.8), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(11.9, 12.4)
            ..cubicTo(11.7, 8.8, 8.8, 6.4, 4.6, 6.7)
            ..cubicTo(4.8, 10.4, 7.7, 12.7, 11.9, 12.4)
            ..close(),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12.1, 10.8)
            ..cubicTo(12.3, 7.5, 14.9, 5.5, 18.7, 5.7)
            ..cubicTo(18.5, 9.1, 15.9, 11.1, 12.1, 10.8)
            ..close(),
          stroke,
        );
      case DsIconKind.cart:
        // 购物车：车斗 + 把手 + 两轮
        canvas.drawPath(
          Path()
            ..moveTo(3.4, 4.8)
            ..lineTo(6.1, 4.8)
            ..lineTo(8.4, 14.4)
            ..lineTo(18.6, 14.4)
            ..lineTo(20.6, 7.4)
            ..lineTo(7.0, 7.4),
          stroke,
        );
        canvas.drawCircle(const Offset(9.6, 18.6), 1.7, stroke);
        canvas.drawCircle(const Offset(16.9, 18.6), 1.7, stroke);
    }
    canvas.restore();
  }

  Path _heartPath() => Path()
    ..moveTo(12, 20.2)
    ..cubicTo(6.2, 15.6, 3.6, 12.4, 3.6, 9.3)
    ..cubicTo(3.6, 6.6, 5.7, 4.6, 8.2, 4.6)
    ..cubicTo(9.8, 4.6, 11.2, 5.4, 12, 6.7)
    ..cubicTo(12.8, 5.4, 14.2, 4.6, 15.8, 4.6)
    ..cubicTo(18.3, 4.6, 20.4, 6.6, 20.4, 9.3)
    ..cubicTo(20.4, 12.4, 17.8, 15.6, 12, 20.2)
    ..close();

  Path _starPath() {
    const center = Offset(12, 12.4);
    const outer = 9.4;
    const inner = 4.2;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _moonPath() => Path()
    ..moveTo(19.6, 14.9)
    ..arcToPoint(
      const Offset(9.1, 4.1),
      radius: const Radius.circular(8.4),
      largeArc: true,
      clockwise: false,
    )
    ..arcToPoint(
      const Offset(19.6, 14.9),
      radius: const Radius.circular(7.0),
      clockwise: true,
    )
    ..close();

  Path _bellPath() => Path()
    ..moveTo(12, 3.8)
    ..cubicTo(8.8, 3.8, 6.6, 6.3, 6.6, 9.6)
    ..lineTo(6.6, 13.2)
    ..cubicTo(6.6, 14.4, 6.2, 15.2, 5.4, 16.2)
    ..lineTo(18.6, 16.2)
    ..cubicTo(17.8, 15.2, 17.4, 14.4, 17.4, 13.2)
    ..lineTo(17.4, 9.6)
    ..cubicTo(17.4, 6.3, 15.2, 3.8, 12, 3.8)
    ..close();

  void _paintGear(Canvas canvas) {
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;
    canvas.drawCircle(const Offset(12, 12), 6.0, ring);
    canvas.drawCircle(
      const Offset(12, 12),
      2.2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final teeth = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(12, 12);
      canvas.rotate(i * _tau / 8);
      canvas.drawLine(const Offset(0, -6.0), const Offset(0, -8.8), teeth);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DsIconPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.fill != fill;
}
