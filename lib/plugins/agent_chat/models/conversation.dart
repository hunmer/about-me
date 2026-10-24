import 'package:uuid/uuid.dart';

import 'agent_chain_node.dart';
import 'voice_call_config.dart';

const _uuid = Uuid();

/// 工具调用 Agent 配置
class ToolAgentConfig {
  /// 服务商ID
  final String providerId;

  /// 模型ID
  final String modelId;

  /// 模型名称（用于显示）
  final String? modelName;

  const ToolAgentConfig({
    required this.providerId,
    required this.modelId,
    this.modelName,
  });

  factory ToolAgentConfig.fromJson(Map<String, dynamic> json) {
    return ToolAgentConfig(
      providerId: json['providerId'] as String,
      modelId: json['modelId'] as String,
      modelName: json['modelName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'modelId': modelId,
      if (modelName != null) 'modelName': modelName,
    };
  }

  ToolAgentConfig copyWith({
    String? providerId,
    String? modelId,
    String? modelName,
  }) {
    return ToolAgentConfig(
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolAgentConfig &&
        other.providerId == providerId &&
        other.modelId == modelId;
  }

  @override
  int get hashCode => Object.hash(providerId, modelId);
}

/// 会话模型
///
/// 代表一个与特定Agent的聊天会话
class Conversation {
  /// 会话ID
  final String id;

  /// 会话标题
  String title;

  /// 绑定的Agent ID（可选，单 agent 模式）
  /// 向后兼容：如果 agentChain 为空，则使用此字段
  final String? agentId;

  /// Agent 链配置（多 agent 链式调用模式）
  /// 如果非空，则忽略 agentId 字段
  final List<AgentChainNode>? agentChain;

  /// 工具调用专用 Agent 配置（工具识别与工具执行两个阶段共用）
  /// 如果未配置，则使用默认 prompt 替换当前 agent 的 system prompt
  final ToolAgentConfig? toolAgentConfig;

  /// 所属分组（支持多个分组）
  List<String> groups;

  /// 会话级上下文消息数量设置
  /// null表示使用全局设置
  int? contextMessageCount;

  /// 创建时间
  final DateTime createdAt;

  /// 最后一条消息的时间
  DateTime lastMessageAt;

  /// 是否置顶
  bool isPinned;

  /// 最后一条消息预览（用于列表显示）
  String? lastMessagePreview;

  /// 未读消息数
  int unreadCount;

  /// 元数据（扩展字段）
  Map<String, dynamic>? metadata;

  /// TTS 自动朗读配置
  TTSConfig? ttsConfig;

  /// 语音通话配置
  VoiceCallConfig? voiceCallConfig;

  Conversation({
    required this.id,
    required this.title,
    this.agentId,
    this.agentChain,
    this.toolAgentConfig,
    this.groups = const [],
    this.contextMessageCount,
    required this.createdAt,
    required this.lastMessageAt,
    this.isPinned = false,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.metadata,
    this.ttsConfig,
    this.voiceCallConfig,
  });

  /// 判断是否为链式模式
  bool get isChainMode => agentChain != null && agentChain!.isNotEmpty;

  /// 获取有效的 agent 列表（兼容单 agent 和链式模式）
  List<String> get effectiveAgentIds {
    if (isChainMode) {
      return agentChain!.map((node) => node.agentId).toList();
    } else if (agentId != null) {
      return [agentId!];
    }
    return [];
  }

  /// 创建新会话的工厂方法
  factory Conversation.create({
    required String title,
    String? agentId,
    List<AgentChainNode>? agentChain,
    ToolAgentConfig? toolAgentConfig,
    List<String>? groups,
    int? contextMessageCount,
  }) {
    final now = DateTime.now();
    return Conversation(
      id: _uuid.v4(),
      title: title,
      agentId: agentId,
      agentChain: agentChain,
      toolAgentConfig: toolAgentConfig,
      groups: groups ?? [],
      contextMessageCount: contextMessageCount,
      createdAt: now,
      lastMessageAt: now,
    );
  }

  /// 从JSON反序列化
  factory Conversation.fromJson(Map<String, dynamic> json) {
    // 兼容旧版本：优先读取新字段 toolAgentConfig，
    // 旧的两阶段独立配置取识别阶段的值；更早的 agentId 形式仅提示重新配置
    ToolAgentConfig? toolAgentConfig;

    if (json.containsKey('toolDetectionAgentId') ||
        json.containsKey('toolExecutionAgentId')) {
      print('⚠️ 检测到旧版本工具 Agent 配置，建议重新配置工具调用设置');
    } else if (json.containsKey('toolAgentConfig')) {
      toolAgentConfig = ToolAgentConfig.fromJson(
        json['toolAgentConfig'] as Map<String, dynamic>,
      );
    } else if (json.containsKey('toolDetectionConfig')) {
      toolAgentConfig = ToolAgentConfig.fromJson(
        json['toolDetectionConfig'] as Map<String, dynamic>,
      );
    } else if (json.containsKey('toolExecutionConfig')) {
      toolAgentConfig = ToolAgentConfig.fromJson(
        json['toolExecutionConfig'] as Map<String, dynamic>,
      );
    }

    final now = DateTime.now();
    final createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now;
    final lastMessageAt =
        DateTime.tryParse(json['lastMessageAt'] as String? ?? '') ?? createdAt;

    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      agentId: json['agentId'] as String?,
      agentChain: (json['agentChain'] as List<dynamic>?)
          ?.map((e) => AgentChainNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolAgentConfig: toolAgentConfig,
      groups:
          (json['groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      contextMessageCount: json['contextMessageCount'] as int?,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
      isPinned: json['isPinned'] as bool? ?? false,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      unreadCount: json['unreadCount'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
      ttsConfig: json['ttsConfig'] != null
          ? TTSConfig.fromJson(json['ttsConfig'] as Map<String, dynamic>)
          : null,
      voiceCallConfig: json['voiceCallConfig'] != null
          ? VoiceCallConfig.fromJson(
              json['voiceCallConfig'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// 序列化为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'agentId': agentId,
      if (agentChain != null && agentChain!.isNotEmpty)
        'agentChain': agentChain!.map((node) => node.toJson()).toList(),
      if (toolAgentConfig != null) 'toolAgentConfig': toolAgentConfig!.toJson(),
      'groups': groups,
      'contextMessageCount': contextMessageCount,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'isPinned': isPinned,
      'lastMessagePreview': lastMessagePreview,
      'unreadCount': unreadCount,
      'metadata': metadata,
      if (ttsConfig != null) 'ttsConfig': ttsConfig!.toJson(),
      if (voiceCallConfig != null) 'voiceCallConfig': voiceCallConfig!.toJson(),
    };
  }

  /// 复制会话（用于修改）
  Conversation copyWith({
    String? title,
    String? agentId,
    List<AgentChainNode>? agentChain,
    bool clearAgentChain = false, // 用于清除链配置
    ToolAgentConfig? toolAgentConfig,
    bool clearToolAgents = false, // 用于清除工具 Agent 配置
    List<String>? groups,
    int? contextMessageCount,
    DateTime? lastMessageAt,
    bool? isPinned,
    String? lastMessagePreview,
    int? unreadCount,
    Map<String, dynamic>? metadata,
    TTSConfig? ttsConfig,
    VoiceCallConfig? voiceCallConfig,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      agentId: agentId ?? this.agentId,
      agentChain: clearAgentChain ? null : (agentChain ?? this.agentChain),
      toolAgentConfig: clearToolAgents
          ? null
          : (toolAgentConfig ?? this.toolAgentConfig),
      groups: groups ?? this.groups,
      contextMessageCount: contextMessageCount ?? this.contextMessageCount,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isPinned: isPinned ?? this.isPinned,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      metadata: metadata ?? this.metadata,
      ttsConfig: ttsConfig ?? this.ttsConfig,
      voiceCallConfig: voiceCallConfig ?? this.voiceCallConfig,
    );
  }

  /// 比较函数（用于排序）
  /// 置顶的在前，然后按最后消息时间降序
  static int compare(Conversation a, Conversation b) {
    // 置顶优先
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;

    // 按最后消息时间降序
    return b.lastMessageAt.compareTo(a.lastMessageAt);
  }
}
