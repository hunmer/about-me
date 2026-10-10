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

// 编辑器心情 emoji -> 表情图片/配色 映射（kind 决定筛选分组，底色随分组色系）
const Map<String, DiaryMoodSpec> _moodSpecs = {
  // 基础十款
  '😊': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/contented.webp', '😊'),
  '🥳': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/glee.webp', '🥳'),
  '😍': DiaryMoodSpec(DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/heart_eyes.webp', '😍'),
  '😱': DiaryMoodSpec(DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/wow.webp', '😱'),
  '😴': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/sleepy.webp', '😴'),
  '🤮': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/puke.webp', '🤮'),
  '🤔': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/puzzled.webp', '🤔'),
  '😎': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/cool.webp', '😎'),
  '😢': DiaryMoodSpec(DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/sad.webp', '😢'),
  '😡': DiaryMoodSpec(DiaryMoodFaceKind.angry, Color(0xFFFCAEAA), 'assets/emoji_faces/furious.webp', '😡'),
  // 开心组
  '😉': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/winking.webp', '😉'),
  '☺️': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/blushing.webp', '☺️'),
  '🤤': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/drooly.webp', '🤤'),
  '😋': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/tasty.webp', '😋'),
  '😛': DiaryMoodSpec(DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/tongue_out.webp', '😛'),
  // 兴奋组
  '🤩': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/star_eyes.webp', '🤩'),
  '🤣': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/hysterical.webp', '🤣'),
  '😜': DiaryMoodSpec(DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/playful.webp', '😜'),
  // 心动组
  '😘': DiaryMoodSpec(DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/blowing_kiss.webp', '😘'),
  '😙': DiaryMoodSpec(DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/kissy.webp', '😙'),
  // 惊讶组
  '😯': DiaryMoodSpec(DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/baffled.webp', '😯'),
  '😮': DiaryMoodSpec(DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/gaping.webp', '😮'),
  '😳': DiaryMoodSpec(DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/flushed.webp', '😳'),
  // 难过组
  '🥺': DiaryMoodSpec(DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/puppy_eyes.webp', '🥺'),
  '😭': DiaryMoodSpec(DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/bawling.webp', '😭'),
  '😫': DiaryMoodSpec(DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/wailing.webp', '😫'),
  // 困倦组
  '😵': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/knocked_out.webp', '😵'),
  '😅': DiaryMoodSpec(DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/sweating.webp', '😅'),
  // 生气组
  '😠': DiaryMoodSpec(DiaryMoodFaceKind.angry, Color(0xFFFCAEAA), 'assets/emoji_faces/mad.webp', '😠'),
  // 思考组
  '🤨': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/skeptical.webp', '🤨'),
  '😏': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/sly.webp', '😏'),
  '😒': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/annoyed.webp', '😒'),
  '😬': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/nervous.webp', '😬'),
  '😣': DiaryMoodSpec(DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/gritting.webp', '😣'),
  // 平静组
  '😐': DiaryMoodSpec(DiaryMoodFaceKind.neutral, Color(0xFFE8E4DE), 'assets/emoji_faces/unamused.webp', '😐'),
  '😑': DiaryMoodSpec(DiaryMoodFaceKind.neutral, Color(0xFFE8E4DE), 'assets/emoji_faces/deadpan.webp', '😑'),
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
  '😉': 'diary_mood_winking',
  '☺️': 'diary_mood_blushing',
  '🤤': 'diary_mood_drooly',
  '😋': 'diary_mood_tasty',
  '😛': 'diary_mood_tongueOut',
  '🤩': 'diary_mood_starEyes',
  '🤣': 'diary_mood_hysterical',
  '😜': 'diary_mood_playful',
  '😘': 'diary_mood_blowingKiss',
  '😙': 'diary_mood_kissy',
  '😯': 'diary_mood_baffled',
  '😮': 'diary_mood_gaping',
  '😳': 'diary_mood_flushed',
  '🥺': 'diary_mood_puppyEyes',
  '😭': 'diary_mood_bawling',
  '😫': 'diary_mood_wailing',
  '😵': 'diary_mood_knockedOut',
  '😅': 'diary_mood_sweating',
  '😠': 'diary_mood_mad',
  '🤨': 'diary_mood_skeptical',
  '😏': 'diary_mood_sly',
  '😒': 'diary_mood_annoyed',
  '😬': 'diary_mood_nervous',
  '😣': 'diary_mood_gritting',
  '😐': 'diary_mood_unamused',
  '😑': 'diary_mood_deadpan',
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

/// 可选心情 emoji 列表（映射表顺序即编辑器展示顺序，单一数据源）
List<String> get diaryMoodEmojis => _moodSpecs.keys.toList();

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
