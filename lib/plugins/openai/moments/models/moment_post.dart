import 'dart:convert';

/// 朋友圈动态帖子
class MomentPost {
  final String id;
  final String agentId;
  final String text;
  final List<String> images; // 相对路径（./openai/moments/...）
  final DateTime createdAt;

  /// 'agent' = agent 自主发布，'manual' = 用户手动发布
  final String source;

  MomentPost({
    required this.id,
    required this.agentId,
    required this.text,
    required this.images,
    required this.createdAt,
    this.source = 'agent',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'agentId': agentId,
    'text': text,
    'images': images,
    'createdAt': createdAt.toIso8601String(),
    'source': source,
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
