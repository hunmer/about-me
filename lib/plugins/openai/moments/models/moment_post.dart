import 'dart:convert';

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
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

/// 朋友圈动态帖子
class MomentPost {
  final String id;
  final String agentId;
  final String text;
  final List<String> images; // 相对路径（./openai/moments/...）
  final DateTime createdAt;

  /// 'agent' = agent 自主发布，'manual' = 用户手动发布
  final String source;

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
    this.liked = false,
    this.comments = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'agentId': agentId,
    'text': text,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
    'source': source,
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
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    source: (json['source'] as String?) ?? 'agent',
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
    'createdAt': createdAt.toIso8601String(),
  });
}
