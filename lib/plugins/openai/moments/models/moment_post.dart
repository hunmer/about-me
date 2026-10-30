import 'dart:convert';

import 'package:shared_models/shared_models.dart';
/// 朋友圈标签分类（UI 筛选 / 用户投稿 / AI 发帖共用一套）
enum MomentPillStyle { purple, orange, blue, pink }

class MomentTag {
  final String key;
  final String emoji;
  final String label;
  final MomentPillStyle style;

  const MomentTag(this.key, this.emoji, this.label, this.style);
}

/// 标签注册表：key 必须与 moments.json 工具描述中的枚举保持一致
class MomentTags {
  static const life = MomentTag('life', '✨', '生活', MomentPillStyle.blue);
  static const foodie = MomentTag('foodie', '🌶️', '美食', MomentPillStyle.orange);
  static const design = MomentTag('design', '💎', '设计', MomentPillStyle.purple);
  static const pets = MomentTag('pets', '🐾', '萌宠', MomentPillStyle.pink);
  static const mood = MomentTag('mood', '💭', '心情', MomentPillStyle.purple);
  static const travel = MomentTag('travel', '✈️', '旅行', MomentPillStyle.blue);

  static const List<MomentTag> all = [
    life,
    foodie,
    design,
    pets,
    mood,
    travel,
  ];

  static const defaultKey = 'life';

  static MomentTag byKey(String? key) {
    for (final t in all) {
      if (t.key == key) return t;
    }
    return life;
  }

  /// 宽松匹配：'标签：foodie' / 'Foodie' 等都能命中
  static String? matchKey(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    for (final t in all) {
      if (t.key == cleaned) return t.key;
    }
    return null;
  }
}

/// 朋友圈评论
class MomentComment {
  final String id;
  final String text;

  /// true = agent 回复，false = 用户评论
  final bool isAgent;
  final DateTime createdAt;

  MomentComment({
    required this.id,
    required this.text,
    required this.isAgent,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isAgent': isAgent,
    'createdAt': createdAt.toIso8601String(),
  };

  static MomentComment fromJson(Map<String, dynamic> json) => MomentComment(
    id: json['id'] as String,
    text: (json['text'] as String?) ?? '',
    isAgent: json['isAgent'] == true,
    createdAt:
        tryParseIsoDateTime(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

/// 朋友圈动态帖子
class MomentPost {
  /// 用户（我）投稿时使用的伪 agentId
  static const userAuthorId = '__user__';

  final String id;
  final String agentId;
  final String text;
  final List<String> images; // 相对路径（./openai/moments/...）
  final DateTime createdAt;

  /// 'agent' = agent 自主发布，'manual' = 用户手动替 agent 发布，'user' = 用户自己投稿
  final String source;

  /// 标签分类（MomentTags.key），AI 发帖必填，历史数据缺省为 'life'
  final String tag;

  /// 用户是否已点赞（单用户应用）
  final bool liked;

  final List<MomentComment> comments;

  MomentPost({
    required this.id,
    required this.agentId,
    required this.text,
    required this.images,
    required this.createdAt,
    this.source = 'agent',
    this.tag = MomentTags.defaultKey,
    this.liked = false,
    this.comments = const [],
  });

  bool get isUserPost => agentId == userAuthorId || source == 'user';

  Map<String, dynamic> toJson() => {
    'id': id,
    'agentId': agentId,
    'text': text,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
    'source': source,
    'tag': tag,
    'liked': liked,
    'comments': comments.map((c) => c.toJson()).toList(),
  };

  static MomentPost fromJson(Map<String, dynamic> json) => MomentPost(
    id: json['id'] as String,
    agentId: json['agentId'] as String,
    text: (json['text'] as String?) ?? '',
    images:
        (json['images'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
    createdAt:
        tryParseIsoDateTime(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    source: (json['source'] as String?) ?? 'agent',
    tag:
        MomentTags.matchKey(json['tag'] as String?) ??
        MomentTags.defaultKey,
    liked: json['liked'] == true,
    comments:
        (json['comments'] as List<dynamic>? ?? [])
            .map(
              (e) => MomentComment.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
  );

  /// 工具返回给 LLM 时的紧凑 JSON
  String toToolJson() => jsonEncode({
    'id': id,
    'agentId': agentId,
    'text': text,
    'imageCount': images.length,
    'tag': tag,
    'createdAt': createdAt.toIso8601String(),
  });
}
