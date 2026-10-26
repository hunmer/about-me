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
  final String id; // 稳定标识，日记 mood 字段存储此值（见 shared_models 的 kDiaryMoodIds）
  final String nameKey; // 名称翻译 key
  final DiaryMoodFaceKind kind;
  final Color bg;
  final String? asset; // 表情图片，null 时回退显示 emoji 文字
  final String emoji; // 回退与弹窗展示用

  const DiaryMoodSpec(
    this.id,
    this.nameKey,
    this.kind,
    this.bg,
    this.asset,
    this.emoji,
  );
}

/// 心情常量列表（单一数据源：id/名称/分组/配色/表情，顺序即编辑器展示顺序）
const List<DiaryMoodSpec> kDiaryMoods = [
  // 基础十款
  DiaryMoodSpec('happy', 'diary_mood_happy', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/contented.webp', '😊'),
  DiaryMoodSpec('excited', 'diary_mood_excited', DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/glee.webp', '🥳'),
  DiaryMoodSpec('loved', 'diary_mood_loved', DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/heart_eyes.webp', '😍'),
  DiaryMoodSpec('surprised', 'diary_mood_surprised', DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/wow.webp', '😱'),
  DiaryMoodSpec('tired', 'diary_mood_tired', DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/sleepy.webp', '😴'),
  DiaryMoodSpec('sick', 'diary_mood_sick', DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/puke.webp', '🤮'),
  DiaryMoodSpec('thinking', 'diary_mood_thinking', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/puzzled.webp', '🤔'),
  DiaryMoodSpec('cool', 'diary_mood_cool', DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/cool.webp', '😎'),
  DiaryMoodSpec('sad', 'diary_mood_sad', DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/sad.webp', '😢'),
  DiaryMoodSpec('angry', 'diary_mood_angry', DiaryMoodFaceKind.angry, Color(0xFFFCAEAA), 'assets/emoji_faces/furious.webp', '😡'),
  // 开心组
  DiaryMoodSpec('winking', 'diary_mood_winking', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/winking.webp', '😉'),
  DiaryMoodSpec('blushing', 'diary_mood_blushing', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/blushing.webp', '☺️'),
  DiaryMoodSpec('drooly', 'diary_mood_drooly', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/drooly.webp', '🤤'),
  DiaryMoodSpec('tasty', 'diary_mood_tasty', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/tasty.webp', '😋'),
  DiaryMoodSpec('tongueOut', 'diary_mood_tongueOut', DiaryMoodFaceKind.happy, Color(0xFFFEE5A5), 'assets/emoji_faces/tongue_out.webp', '😛'),
  // 兴奋组
  DiaryMoodSpec('starEyes', 'diary_mood_starEyes', DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/star_eyes.webp', '🤩'),
  DiaryMoodSpec('hysterical', 'diary_mood_hysterical', DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/hysterical.webp', '🤣'),
  DiaryMoodSpec('playful', 'diary_mood_playful', DiaryMoodFaceKind.excited, Color(0xFFBACBFC), 'assets/emoji_faces/playful.webp', '😜'),
  // 心动组
  DiaryMoodSpec('blowingKiss', 'diary_mood_blowingKiss', DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/blowing_kiss.webp', '😘'),
  DiaryMoodSpec('kissy', 'diary_mood_kissy', DiaryMoodFaceKind.loved, Color(0xFFF3D2D6), 'assets/emoji_faces/kissy.webp', '😙'),
  // 惊讶组
  DiaryMoodSpec('baffled', 'diary_mood_baffled', DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/baffled.webp', '😯'),
  DiaryMoodSpec('gaping', 'diary_mood_gaping', DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/gaping.webp', '😮'),
  DiaryMoodSpec('flushed', 'diary_mood_flushed', DiaryMoodFaceKind.surprised, Color(0xFFD5CCF5), 'assets/emoji_faces/flushed.webp', '😳'),
  // 难过组
  DiaryMoodSpec('puppyEyes', 'diary_mood_puppyEyes', DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/puppy_eyes.webp', '🥺'),
  DiaryMoodSpec('bawling', 'diary_mood_bawling', DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/bawling.webp', '😭'),
  DiaryMoodSpec('wailing', 'diary_mood_wailing', DiaryMoodFaceKind.sad, Color(0xFF97C3F9), 'assets/emoji_faces/wailing.webp', '😫'),
  // 困倦组
  DiaryMoodSpec('knockedOut', 'diary_mood_knockedOut', DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/knocked_out.webp', '😵'),
  DiaryMoodSpec('sweating', 'diary_mood_sweating', DiaryMoodFaceKind.tired, Color(0xFFC6EAE2), 'assets/emoji_faces/sweating.webp', '😅'),
  // 生气组
  DiaryMoodSpec('mad', 'diary_mood_mad', DiaryMoodFaceKind.angry, Color(0xFFFCAEAA), 'assets/emoji_faces/mad.webp', '😠'),
  // 思考组
  DiaryMoodSpec('skeptical', 'diary_mood_skeptical', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/skeptical.webp', '🤨'),
  DiaryMoodSpec('sly', 'diary_mood_sly', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/sly.webp', '😏'),
  DiaryMoodSpec('annoyed', 'diary_mood_annoyed', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/annoyed.webp', '😒'),
  DiaryMoodSpec('nervous', 'diary_mood_nervous', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/nervous.webp', '😬'),
  DiaryMoodSpec('gritting', 'diary_mood_gritting', DiaryMoodFaceKind.thinking, Color(0xFFD5CCF5), 'assets/emoji_faces/gritting.webp', '😣'),
  // 平静组
  DiaryMoodSpec('unamused', 'diary_mood_unamused', DiaryMoodFaceKind.neutral, Color(0xFFE8E4DE), 'assets/emoji_faces/unamused.webp', '😐'),
  DiaryMoodSpec('deadpan', 'diary_mood_deadpan', DiaryMoodFaceKind.neutral, Color(0xFFE8E4DE), 'assets/emoji_faces/deadpan.webp', '😑'),
];

// 无心情记录时的中性脸
const neutralMoodSpec = DiaryMoodSpec(
  'neutral',
  'diary_noMoodRecord',
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

/// 取心情定义，兼容旧数据的 emoji 值；未知值按哈希落到马卡龙色板
/// （无图片回退 emoji 文字，名称翻译未命中时 .tr 返回原值直接展示）
DiaryMoodSpec diaryMoodSpecOf(String mood) {
  for (final m in kDiaryMoods) {
    if (m.id == mood || m.emoji == mood) return m;
  }
  return DiaryMoodSpec(
    mood,
    mood,
    DiaryMoodFaceKind.happy,
    _fallbackPalette[mood.hashCode % _fallbackPalette.length],
    null,
    mood,
  );
}

/// 心情值归一化：旧 emoji 数据 -> id；未知值原样返回（用于统计分组与写入）
String diaryMoodIdOf(String mood) => diaryMoodSpecOf(mood).id;

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
