import 'package:flutter/material.dart';

/// 心情表情类型（用于心情筛选分组）
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

/// 心情外观定义：底色 + 表情图片资源（assets/emoji_faces）
class DiaryMoodSpec {
  final DiaryMoodFaceKind kind;
  final Color bg;
  final String? asset; // 表情图片，null 时回退显示 emoji 文字
  final String emoji; // 回退与弹窗展示用

  const DiaryMoodSpec(this.kind, this.bg, this.asset, this.emoji);
}

// 编辑器心情 emoji -> 表情图片/配色 映射
const Map<String, DiaryMoodSpec> _moodSpecs = {
  '😊': DiaryMoodSpec(
    DiaryMoodFaceKind.happy,
    Color(0xFFFEE5A5),
    'assets/emoji_faces/contented.webp',
    '😊',
  ),
  '🥳': DiaryMoodSpec(
    DiaryMoodFaceKind.excited,
    Color(0xFFBACBFC),
    'assets/emoji_faces/glee.webp',
    '🥳',
  ),
  '😍': DiaryMoodSpec(
    DiaryMoodFaceKind.loved,
    Color(0xFFF3D2D6),
    'assets/emoji_faces/heart_eyes.webp',
    '😍',
  ),
  '😱': DiaryMoodSpec(
    DiaryMoodFaceKind.surprised,
    Color(0xFFD5CCF5),
    'assets/emoji_faces/wow.webp',
    '😱',
  ),
  '😴': DiaryMoodSpec(
    DiaryMoodFaceKind.tired,
    Color(0xFFC6EAE2),
    'assets/emoji_faces/sleepy.webp',
    '😴',
  ),
  '🤮': DiaryMoodSpec(
    DiaryMoodFaceKind.tired,
    Color(0xFFC6EAE2),
    'assets/emoji_faces/puke.webp',
    '🤮',
  ),
  '🤔': DiaryMoodSpec(
    DiaryMoodFaceKind.thinking,
    Color(0xFFD5CCF5),
    'assets/emoji_faces/puzzled.webp',
    '🤔',
  ),
  '😎': DiaryMoodSpec(
    DiaryMoodFaceKind.excited,
    Color(0xFFBACBFC),
    'assets/emoji_faces/cool.webp',
    '😎',
  ),
  '😢': DiaryMoodSpec(
    DiaryMoodFaceKind.sad,
    Color(0xFF97C3F9),
    'assets/emoji_faces/sad.webp',
    '😢',
  ),
  '😡': DiaryMoodSpec(
    DiaryMoodFaceKind.angry,
    Color(0xFFFCAEAA),
    'assets/emoji_faces/furious.webp',
    '😡',
  ),
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
  'assets/emoji_faces/deadpan.webp',
  '🙂',
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

/// 取心情外观，未知 emoji 时按哈希落到马卡龙色板（无图片，回退 emoji 文字）
DiaryMoodSpec diaryMoodSpecOf(String mood) {
  return _moodSpecs[mood] ??
      DiaryMoodSpec(
        DiaryMoodFaceKind.happy,
        _fallbackPalette[mood.hashCode % _fallbackPalette.length],
        null,
        mood,
      );
}

/// 马卡龙色圆形 + 表情图片（assets/emoji_faces，缺图时回退 emoji 文字）
class DiaryMoodFaceCircle extends StatelessWidget {
  final DiaryMoodSpec spec;
  final double size;

  const DiaryMoodFaceCircle({
    super.key,
    required this.spec,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final faceSize = size * 0.62;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: spec.bg, shape: BoxShape.circle),
      child: Center(
        child: SizedBox(
          width: faceSize,
          height: faceSize,
          child: spec.asset != null
              ? Image.asset(
                  spec.asset!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => _fallbackEmoji(faceSize),
                )
              : _fallbackEmoji(faceSize),
        ),
      ),
    );
  }

  Widget _fallbackEmoji(double faceSize) {
    return Center(
      child: Text(spec.emoji, style: TextStyle(fontSize: faceSize * 0.55)),
    );
  }
}
