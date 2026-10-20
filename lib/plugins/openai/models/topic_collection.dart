/// 话题合集数据模型
///
/// 「话题」tab 的数据源：合集（[TopicCollection]）内是一棵
/// 无层级限制的话题树（[TopicNode]，分组节点下可以有分组或话题）。
/// 每个叶子话题可挂多份互相隔离的会话（见 TopicChatService）。
///
/// 合集目录以 JSON 分发（assets 内置 + 数据目录按 [version] 更新），
/// 目录内容（标题/提问/追问）属于内置数据，不走 l10n；
/// 页面级 UI 文案仍走 openai 插件翻译键。
class TopicNode {
  const TopicNode({
    required this.id,
    required this.title,
    this.lead,
    this.follow,
    this.depthLabel,
    this.children = const [],
  });

  /// 合集内稳定 id（如 's1.t5'）
  final String id;

  /// 节点标题（分组名或话题名）
  final String title;

  /// 话题的 AI 开场提问（叶子话题）
  final String? lead;

  /// 追问线索（叶子话题，最多两层）
  final String? follow;

  /// 深度标签：轻松 / 中等 / 较深 / 需许可
  final String? depthLabel;

  /// 子节点（非空即分组节点）
  final List<TopicNode> children;

  bool get isGroup => children.isNotEmpty;

  /// 深度优先遍历子树（含自身）
  Iterable<TopicNode> subtree() sync* {
    yield this;
    for (final child in children) {
      yield* child.subtree();
    }
  }

  factory TopicNode.fromJson(Map<String, dynamic> json) {
    return TopicNode(
      id: json['id'] as String,
      title: json['title'] as String,
      lead: json['lead'] as String?,
      follow: json['follow'] as String?,
      depthLabel: json['depthLabel'] as String?,
      children:
          (json['children'] as List<dynamic>? ?? [])
              .map((e) => TopicNode.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (lead != null) 'lead': lead,
    if (follow != null) 'follow': follow,
    if (depthLabel != null) 'depthLabel': depthLabel,
    if (children.isNotEmpty) 'children': children.map((e) => e.toJson()).toList(),
  };
}

/// 话题合集
class TopicCollection {
  const TopicCollection({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.prompt,
    required this.intro,
    required this.topics,
  });

  /// 合集稳定 id（会话元数据与合集 agent 存储均由它派生）
  final String id;

  /// 目录版本号：assets 内置目录高于数据目录时覆盖更新
  final int version;

  /// 合集名（如「探索自己」）
  final String name;

  /// 合集简介
  final String description;

  /// 默认 AI 系统提示词（用于生成合集默认 agent）
  final String prompt;

  /// 新会话固定的第一条介绍消息（话题脚本随后拼入）
  final String intro;

  /// 顶层节点（分组或话题）
  final List<TopicNode> topics;

  /// 全树查找节点
  TopicNode? nodeById(String id) {
    for (final node in topics) {
      for (final candidate in node.subtree()) {
        if (candidate.id == id) return candidate;
      }
    }
    return null;
  }

  /// 汇总各节点（含子孙）的话题会话数
  int conversationCountFor(
    TopicNode node,
    Map<String, int> countsByTopicId,
  ) {
    var count = 0;
    for (final candidate in node.subtree()) {
      count += countsByTopicId[candidate.id] ?? 0;
    }
    return count;
  }

  factory TopicCollection.fromJson(Map<String, dynamic> json) {
    return TopicCollection(
      id: json['id'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      topics:
          (json['topics'] as List<dynamic>? ?? [])
              .map((e) => TopicNode.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'name': name,
    'description': description,
    'prompt': prompt,
    'intro': intro,
    'topics': topics.map((e) => e.toJson()).toList(),
  };
}
