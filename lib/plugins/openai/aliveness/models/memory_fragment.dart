import 'dart:math';

/// 记忆碎片（PRD 5.3.1）：最小记忆单元，按 agentId 独立存储。
/// 通过 tags 子串匹配实现"聊到才想起"的联想激活，不依赖向量库。
class MemoryFragment {
  final String id;
  final String content; // 一句话事实，如"用户最近在准备面试"
  final List<String> tags; // 激活关键词（2~4 个）
  final String? emotionTag; // 情绪标签
  final bool isSelf; // true = 关于 AI 自己的记忆（自我碎片）；false = 关于用户的
  final String category; // 分类索引；旧记忆归入 other
  double importance; // 0~1
  bool userMarked; // 用户手动标记（不参与遗忘），管理页可切换
  bool archived; // 遗忘后归档，不再激活
  final DateTime createdAt;
  DateTime? lastActivatedAt;
  int activateCount;

  MemoryFragment({
    required this.id,
    required this.content,
    required this.tags,
    this.emotionTag,
    this.isSelf = false,
    this.category = 'other',
    this.importance = 0.5,
    this.userMarked = false,
    this.archived = false,
    DateTime? createdAt,
    this.lastActivatedAt,
    this.activateCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 当前权重：重要性 × 遗忘曲线（半衰期可配），低于阈值的由服务层归档
  double weight({int halfLifeDays = 14}) {
    if (userMarked) return 1.0;
    final days = DateTime.now().difference(createdAt).inMinutes / 1440.0;
    return importance * pow(0.5, days / halfLifeDays);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'tags': tags,
    'category': category,
    'emotionTag': emotionTag,
    if (isSelf) 'isSelf': true,
    'importance': importance,
    'userMarked': userMarked,
    'archived': archived,
    'createdAt': createdAt.toIso8601String(),
    'lastActivatedAt': lastActivatedAt?.toIso8601String(),
    'activateCount': activateCount,
  };

  factory MemoryFragment.fromJson(Map<String, dynamic> json) =>
      MemoryFragment(
        id: json['id'] as String,
        content: json['content'] as String,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
        emotionTag: json['emotionTag'] as String?,
        isSelf: json['isSelf'] as bool? ?? false,
        category: json['category'] as String? ?? 'other',
        importance:
            ((json['importance'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0),
        userMarked: json['userMarked'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        createdAt:
            json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now(),
        lastActivatedAt:
            json['lastActivatedAt'] != null
                ? DateTime.parse(json['lastActivatedAt'] as String)
                : null,
        activateCount: json['activateCount'] as int? ?? 0,
      );
}

/// 开环事件（PRD 5.1.2 / Phase 4）：未关闭的"待跟进"事件，
/// 是主动消息的一类触发源（如"用户明天有面试"）。
class OpenLoop {
  final String id;
  final String description;
  final DateTime createdAt;
  final DateTime? followUpBy; // 建议跟进时间（到期可主动问候）
  bool closed;

  OpenLoop({
    required this.id,
    required this.description,
    DateTime? createdAt,
    this.followUpBy,
    this.closed = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否已过期应关闭（默认 7 天）
  bool get isStale =>
      DateTime.now().difference(createdAt).inDays >= 7 || closed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'followUpBy': followUpBy?.toIso8601String(),
    'closed': closed,
  };

  factory OpenLoop.fromJson(Map<String, dynamic> json) => OpenLoop(
    id: json['id'] as String,
    description: json['description'] as String,
    createdAt:
        json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
    followUpBy:
        json['followUpBy'] != null
            ? DateTime.parse(json['followUpBy'] as String)
            : null,
    closed: json['closed'] as bool? ?? false,
  );
}
