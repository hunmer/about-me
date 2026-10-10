import 'package:flutter/material.dart';

/// 心情表情类型（对应设计稿中手绘表情）
enum DiaryMoodFaceKind {
  happy,
  excited,
  loved,
  surprised,
  tired,
  sad,
  angry,
  thinking,
  neutral,
}

/// 心情外观定义：底色 + 线稿色 + 点缀色（爱心/泪滴）
class DiaryMoodSpec {
  final DiaryMoodFaceKind kind;
  final Color bg;
  final Color stroke;
  final Color? accent;

  const DiaryMoodSpec(this.kind, this.bg, this.stroke, {this.accent});
}

// 编辑器心情 emoji -> 设计稿表情/配色 映射
const Map<String, DiaryMoodSpec> _moodSpecs = {
  '😊': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), Color(0xFF504229)),
  '🥳': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), Color(0xFF2E3C64)),
  '😍': DiaryMoodSpec(DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), Color(0xFF5C4247), accent: Color(0xFFE2657A)),
  '😱': DiaryMoodSpec(DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), Color(0xFF4B4365)),
  '😴': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), Color(0xFF3D524C)),
  '🤮': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), Color(0xFF3D524C)),
  '🤔': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), Color(0xFF4B4365)),
  '😎': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), Color(0xFF2E3C64)),
  '😢': DiaryMoodSpec(DiaryMoodFaceKind.sad, Color(0xFF97C3F9), Color(0xFF1E4472), accent: Color(0xFF60A5FA)),
  '😡': DiaryMoodSpec(DiaryMoodFaceKind.angry, Color(0xFFFCAEAA), Color(0xFF682A27)),
};

// 心情 emoji -> 翻译 key（未命中时直接显示 emoji）
const Map<String, String> diaryMoodNameKeys = {
  '😊': 'diary_mood_happy',
  '🥳': 'diary_mood_excited',
  '😍': 'diary_mood_loved',
  '😱': 'diary_mood_surprised',
  '😴': 'diary_mood_tired',
  '🤮': 'diary_mood_sick',
  '🤔': 'diary_mood_thinking',
  '😎': 'diary_mood_cool',
  '😢': 'diary_mood_sad',
  '😡': 'diary_mood_angry',
};

// 无心情记录时的中性脸
const DiaryMoodSpec neutralMoodSpec = DiaryMoodSpec(
  DiaryMoodFaceKind.neutral,
  Color(0x66FFFFFF),
  Color(0x802D282A),
);

const List<Color> _fallbackPalette = [
  Color(0xFFFEE5A5),
  Color(0xFFC6EAE2),
  Color(0xFFBACBFC),
  Color(0xFFF3D2D6),
  Color(0xFF97C3F9),
  Color(0xFFFCAEAA),
  Color(0xFFD5CCF5),
];

// 兜底线稿色（暖黑）
const Color _darkWarm = Color(0xFF2D282A);

/// 取心情外观，未知 emoji 时按哈希落到马卡龙色板
DiaryMoodSpec diaryMoodSpecOf(String mood) {
  return _moodSpecs[mood] ??
      DiaryMoodSpec(
        DiaryMoodFaceKind.happy,
        _fallbackPalette[mood.hashCode % _fallbackPalette.length],
        _darkWarm,
      );
}

/// 马卡龙色圆形 + 手绘心情表情
class DiaryMoodFaceCircle extends StatelessWidget {
  final DiaryMoodSpec spec;
  final double size;

  const DiaryMoodFaceCircle({super.key, required this.spec, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: spec.bg, shape: BoxShape.circle),
      child: Center(
        child: CustomPaint(
          size: Size.square(size * 0.62),
          painter: _MoodFacePainter(
            kind: spec.kind,
            color: spec.stroke,
            accent: spec.accent,
          ),
        ),
      ),
    );
  }
}

/// 手绘风格心情表情，在 24x24 逻辑坐标系中绘制
class _MoodFacePainter extends CustomPainter {
  final DiaryMoodFaceKind kind;
  final Color color;
  final Color? accent;

  const _MoodFacePainter({
    required this.kind,
    required this.color,
    this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
    final fillPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), strokePaint);

    // 两点间弧线，cy 为控制点纵坐标（小于端点为向上鼓，大于为向下鼓）
    void arc(double x1, double y1, double x2, double y2, double cy) {
      final p =
          Path()
            ..moveTo(x1, y1)
            ..quadraticBezierTo((x1 + x2) / 2, cy, x2, y2);
      canvas.drawPath(p, strokePaint);
    }

    void dot(double cx, double cy, [double r = 1.3]) =>
        canvas.drawCircle(Offset(cx, cy), r, fillPaint);

    // 下半圆张嘴
    void bowl(double cx, double cy, double r) {
      final p =
          Path()
            ..moveTo(cx - r, cy)
            ..arcToPoint(
              Offset(cx + r, cy),
              radius: Radius.circular(r),
              clockwise: false,
            )
            ..close();
      canvas.drawPath(p, fillPaint);
    }

    switch (kind) {
      case DiaryMoodFaceKind.happy:
        arc(6, 10, 10.5, 10, 7); // 左眼 ∩
        arc(13.5, 10, 18, 10, 7); // 右眼 ∩
        arc(9, 14.8, 15, 14.8, 17.4); // 微笑
      case DiaryMoodFaceKind.excited:
        dot(8, 10); // 左眼
        line(13.2, 10.6, 16.8, 9); // 右眼眨眼
        bowl(12, 14.2, 2.2); // 张嘴笑
      case DiaryMoodFaceKind.loved:
        final heartPaint =
            Paint()
              ..color = accent ?? color
              ..style = PaintingStyle.fill;
        canvas.drawPath(_heart(7.6, 10, 1.8), heartPaint);
        canvas.drawPath(_heart(16.4, 10, 1.8), heartPaint);
        arc(10.6, 14.4, 13.4, 14.4, 16); // 小微笑
      case DiaryMoodFaceKind.surprised:
        dot(8, 10);
        dot(16, 10);
        canvas.drawOval(const Rect.fromLTRB(10.6, 13.2, 13.4, 17.6), fillPaint);
      case DiaryMoodFaceKind.tired:
        line(6.2, 8.9, 9.2, 11.3); // 左眼 X
        line(9.2, 8.9, 6.2, 11.3);
        line(14.8, 8.9, 17.8, 11.3); // 右眼 X
        line(17.8, 8.9, 14.8, 11.3);
        line(10, 15.6, 14, 15.6); // 嘴巴一条线
      case DiaryMoodFaceKind.sad:
        arc(7, 9.6, 10.6, 9.6, 11.4); // 左眼 ∪
        arc(13.4, 9.6, 17, 9.6, 11.4); // 右眼 ∪
        bowl(12, 15.6, 2); // 张嘴
        if (accent != null) {
          final tearPaint =
              Paint()
                ..color = accent!
                ..style = PaintingStyle.fill;
          canvas.drawOval(const Rect.fromLTRB(6.2, 12, 7.8, 15.6), tearPaint);
          canvas.drawOval(const Rect.fromLTRB(16.2, 12, 17.8, 15.6), tearPaint);
        }
      case DiaryMoodFaceKind.angry:
        line(6.4, 8.2, 9.6, 10); // 左眉
        line(17.6, 8.2, 14.4, 10); // 右眉
        dot(9, 11.6);
        dot(15, 11.6);
        arc(10, 16.6, 14, 16.6, 14.9); // 撇嘴
      case DiaryMoodFaceKind.thinking:
        line(6.2, 7.9, 9.4, 8.9); // 挑眉
        dot(8, 10.4);
        dot(16, 10.4);
        line(10.4, 15.9, 13.6, 15.2); // 歪嘴
      case DiaryMoodFaceKind.neutral:
        dot(8, 10);
        dot(16, 10);
        line(10, 15.4, 14, 15.4);
    }
  }

  /// 以 (cx, cy) 为中心的心形路径
  Path _heart(double cx, double cy, double s) {
    return Path()
      ..moveTo(cx, cy + s * 0.9)
      ..cubicTo(cx - s * 1.15, cy + s * 0.05, cx - s * 0.6, cy - s * 0.9, cx, cy - s * 0.32)
      ..cubicTo(cx + s * 0.6, cy - s * 0.9, cx + s * 1.15, cy + s * 0.05, cx, cy + s * 0.9)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _MoodFacePainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}
