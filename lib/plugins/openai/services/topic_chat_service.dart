import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/data/topic_collections.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/topic_collection.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';

/// 话题合集聊天服务
///
/// 职责：
/// - 注册话题合集（内置，后续可扩展自定义合集）
/// - 合集 prompt 自定义：覆盖值持久化，并同步到合集内置 agent
/// - 按（合集 × 话题）创建/查询互相隔离的会话：
///   会话带 `hideInList` 元数据，不进 agent_chat 会话列表，入口只有话题 tab
/// - 新会话写入固定的第一条介绍消息（写入后不再改动，
///   后续改 prompt / 换 agent 均不影响已写入的首条消息）
class TopicChatService {
  TopicChatService._();

  static final TopicChatService instance = TopicChatService._();

  /// 所有可用合集（当前仅内置【探索自己】，结构上可继续追加）
  List<TopicCollection> get collections =>
      List.unmodifiable(builtinTopicCollections);

  TopicCollection? collectionById(String id) {
    for (final collection in builtinTopicCollections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  // ========== prompt 自定义 ==========

  /// prompt 覆盖值持久化文件（openai 插件存储目录）
  Future<Map<String, dynamic>> _readOverrides() async {
    try {
      final data = await AboutmeDataService.instance.readPath(
        '${OpenAIPlugin.instance.storageDir}/topic_collections.json',
      );
      if (data is Map<String, dynamic>) {
        final overrides = data['promptOverrides'];
        if (overrides is Map<String, dynamic>) return overrides;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _writeOverrides(Map<String, dynamic> overrides) async {
    await AboutmeDataService.instance.writePath(
      '${OpenAIPlugin.instance.storageDir}/topic_collections.json',
      {'promptOverrides': overrides},
    );
  }

  /// 合集生效的系统提示词（用户覆盖 > 内置默认）
  Future<String> effectivePrompt(TopicCollection collection) async {
    final overrides = await _readOverrides();
    final override = overrides[collection.id];
    if (override is String && override.trim().isNotEmpty) return override;
    return collection.prompt;
  }

  /// 是否已被用户自定义（用于编辑界面区分默认值）
  Future<String?> promptOverride(TopicCollection collection) async {
    final overrides = await _readOverrides();
    final override = overrides[collection.id];
    return override is String && override.trim().isNotEmpty ? override : null;
  }

  /// 保存 prompt 覆盖并同步到合集内置 agent 的 system 消息
  Future<void> setPromptOverride(
    TopicCollection collection,
    String prompt,
  ) async {
    final overrides = await _readOverrides();
    overrides[collection.id] = prompt;
    await _writeOverrides(overrides);
    await _syncAgentPrompt(collection, prompt);
  }

  // ========== 内置 agent ==========

  /// 合集内置 agent id（各合集一份，可被用户在 agent_chat 里继续编辑）
  String agentIdFor(TopicCollection collection) =>
      'builtin_topic_${collection.id}';

  /// 确保合集内置 agent 存在；返回 agent id
  ///
  /// 已存在时不覆写（用户可能在 agent_chat 里改过该 agent）；
  /// 仅在用户保存 prompt 覆盖时显式同步 system 消息（见 [setPromptOverride]）。
  Future<String> ensureCollectionAgent(TopicCollection collection) async {
    final agentId = agentIdFor(collection);
    final controller = AgentController();
    final agents = await controller.loadAgents();
    for (final agent in agents) {
      if (agent.id == agentId) return agentId;
    }

    // 取第一个服务商的连接配置，保证开箱可用（同 ChatAssistantService）
    String providerId = '';
    String baseUrl = '';
    Map<String, String> headers = {};
    String model = 'gpt-4o-mini';
    String apiFormat = 'openai';
    try {
      final providers = await ProviderController().getProviders();
      if (providers.isNotEmpty) {
        final provider = providers.first;
        providerId = provider.id;
        baseUrl = provider.baseUrl;
        headers = provider.headers;
        apiFormat = provider.apiFormat;
        if (provider.defaultModel != null &&
            provider.defaultModel!.isNotEmpty) {
          model = provider.defaultModel!;
        }
      }
    } catch (_) {
      // 无服务商时仍创建占位配置，用户可稍后编辑
    }

    final agent = AIAgent(
      id: agentId,
      version: 1,
      name: collection.name,
      description: collection.description,
      tags: const ['内置', '话题合集'],
      serviceProviderId: providerId,
      baseUrl: baseUrl,
      headers: headers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: model,
      maxLength: 2048,
      icon: topicCollectionIcon(collection.id),
      messages: [
        Prompt(type: 'system', content: await effectivePrompt(collection)),
      ],
      apiFormat: apiFormat,
    );
    await controller.saveAgent(agent);
    return agentId;
  }

  /// 把 prompt 覆盖同步进内置 agent 的 system 消息（保留非 system 预设）
  Future<void> _syncAgentPrompt(
    TopicCollection collection,
    String prompt,
  ) async {
    final agentId = agentIdFor(collection);
    final controller = AgentController();
    final agents = await controller.loadAgents();
    for (final agent in agents) {
      if (agent.id != agentId) continue;
      await controller.saveAgent(
        agent.copyWith(
          messages: [
            Prompt(type: 'system', content: prompt),
            ...?agent.messages?.where((message) => message.type != 'system'),
          ],
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
  }

  // ========== 话题会话 ==========

  /// 话题会话在 agent_chat 会话列表隐藏（入口只有话题 tab）
  static const String hiddenGroup = '话题';

  Map<String, dynamic> _metadataFor(
    TopicCollection collection,
    TopicNode node,
  ) => {
    'hideInList': true,
    'topicChat': {'collectionId': collection.id, 'topicId': node.id},
  };

  static ({String collectionId, String topicId})? topicInfoOf(
    Conversation conversation,
  ) {
    final info = conversation.metadata?['topicChat'];
    if (info is Map<String, dynamic>) {
      final collectionId = info['collectionId'];
      final topicId = info['topicId'];
      if (collectionId is String && topicId is String) {
        return (collectionId: collectionId, topicId: topicId);
      }
    }
    return null;
  }

  /// 某话题（含子树，供分组节点聚合）的会话
  List<Conversation> conversationsFor(
    TopicCollection collection,
    TopicNode node,
  ) {
    final service = _conversationService;
    if (service == null) return const [];
    final subtreeIds = node.subtree().map((n) => n.id).toSet();
    return service.conversations.where((conversation) {
      final info = topicInfoOf(conversation);
      return info != null &&
          info.collectionId == collection.id &&
          subtreeIds.contains(info.topicId);
    }).toList()
      ..sort(Conversation.compare);
  }

  /// 各话题 id 的会话数（节点角标用）
  Map<String, int> conversationCounts(TopicCollection collection) {
    final service = _conversationService;
    final counts = <String, int>{};
    if (service == null) return counts;
    for (final conversation in service.conversations) {
      final info = topicInfoOf(conversation);
      if (info == null || info.collectionId != collection.id) continue;
      counts[info.topicId] = (counts[info.topicId] ?? 0) + 1;
    }
    return counts;
  }

  ConversationService? get _conversationService =>
      AgentChatPlugin.instance.conversationController?.conversationService;

  /// 新话题会话的固定介绍消息：合集介绍 + 话题脚本（写入后不再改动）
  String introMessageFor(TopicCollection collection, TopicNode topic) {
    final buffer = StringBuffer(collection.intro);
    if (topic.depthLabel != null || topic.lead != null) {
      buffer.write('\n\n');
      buffer.write('【本次话题】${topic.title}');
      if (topic.depthLabel != null) buffer.write('（${topic.depthLabel}）');
      if (topic.lead != null) {
        buffer.write('\n');
        buffer.write(topic.lead);
      }
      if (topic.follow != null) {
        buffer.write('\n');
        buffer.write(topic.follow);
      }
    }
    return buffer.toString();
  }

  /// 创建话题会话并写入固定的第一条介绍消息
  Future<Conversation> createConversation({
    required TopicCollection collection,
    required TopicNode topic,
  }) async {
    final controller = AgentChatPlugin.instance.conversationController;
    final service = _conversationService;
    if (controller == null || service == null) {
      throw Exception('agent_chat 插件未就绪');
    }

    final agentId = await ensureCollectionAgent(collection);
    var conversation = await service.createConversation(
      title: '${collection.name}·${topic.title}',
      agentId: agentId,
      groups: [hiddenGroup],
    );
    conversation = conversation.copyWith(
      metadata: _metadataFor(collection, topic),
    );
    await service.updateConversation(conversation);

    // 固定的第一条介绍消息：仅创建会话时写入一次
    final messageService = MessageService(
      storage: AgentChatPlugin.instance.storage,
    );
    await messageService.addMessage(
      ChatMessage.ai(
        conversationId: conversation.id,
        content: introMessageFor(collection, topic),
        isGenerating: false,
      ),
    );
    return conversation;
  }
}
