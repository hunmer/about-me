/// 话题合集数据模型
///
/// 「话题」tab 的数据源：合集（[TopicCollection]）内是一棵
/// 无层级限制的话题树（[TopicNode]，分组节点下可以有分组或话题）。
/// 每个叶子话题可挂多份互相隔离的会话（见 TopicChatService）。
///
/// 目录内容（标题/提问/追问）属于用户提供的内置数据，不走 l10n；
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
}

/// 话题合集
class TopicCollection {
  const TopicCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.prompt,
    required this.intro,
    required this.topics,
  });

  /// 合集稳定 id（会话元数据与内置 agent id 均由它派生）
  final String id;

  /// 合集名（如「探索自己」）
  final String name;

  /// 合集简介
  final String description;

  /// 默认 AI 系统提示词（可被用户的自定义覆盖）
  final String prompt;

  /// 新会话固定的第一条介绍消息（{@link TopicNode} 的话题脚本随后拼入）
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
}
