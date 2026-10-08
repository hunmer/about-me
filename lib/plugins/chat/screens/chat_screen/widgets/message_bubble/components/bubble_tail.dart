import 'package:flutter/widgets.dart';

/// 消息气泡对话尖角，指向发送方一侧（当前用户朝右，对方朝左）
class BubbleTail extends StatelessWidget {
  final Color color;

  /// true = 指向右侧（当前用户消息），false = 指向左侧
  final bool isOutgoing;
  final double width;
  final double height;

  const BubbleTail({
    super.key,
    required this.color,
    required this.isOutgoing,
    this.width = 8.0,
    this.height = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // 向气泡方向偏移 1px 消除与圆角边缘的缝隙
    return Transform.translate(
      offset: Offset(isOutgoing ? -1.0 : 1.0, 0),
      child: CustomPaint(
        size: Size(width, height),
        painter: _BubbleTailPainter(color: color, isOutgoing: isOutgoing),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool isOutgoing;

  _BubbleTailPainter({required this.color, required this.isOutgoing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
    final path = Path();
    if (isOutgoing) {
      // 右尖角：直角边贴气泡右侧，尖端朝右下
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height * 0.2);
      path.lineTo(0, size.height * 0.75);
    } else {
      // 左尖角：直角边贴气泡左侧，尖端朝左下
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height * 0.2);
      path.lineTo(size.width, size.height * 0.75);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      color != oldDelegate.color || isOutgoing != oldDelegate.isOutgoing;
}
