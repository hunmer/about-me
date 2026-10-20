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
/// - 合集的 AI 是一份**完整 agent 配置**（模型/参数/人设等），
///   独立存储在 `openai/topic_agents_<collectionId>.json`
///   （extra storage，与全局 agents.json 互不影响），
///   编辑入口复用 [AgentEditScreen]（传 extraStorageKey）
/// - 运行时经 [AgentController.addTemporaryAgent] 注入内存，
///   聊天链路按 agentId 即可解析（getAgent 含临时 agent）
/// - 按（合集 × 话题）创建/查询互相隔离的会话：
///   会话带 `hideInList` 元数据，不进 agent_chat 会话列表，入口只有话题 tab
/// - 新会话写入固定的第一条介绍消息（写入后不再改动，
///   后续改 agent 配置 / 换 agent 均不影响已写入的首条消息）
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

  // ========== 合集 agent（完整配置，独立存储） ==========

  /// 合集 agent 的 extra storage key（独立于 agents.json 的存储文件）
  static String storageKeyFor(TopicCollection collection) =>
      'topic_agents_${collection.id}';

  /// 合集 agent id（沿用 builtin_ 前缀：即使被误存进 agents.json 也不会出现在可见列表）
  String agentIdFor(TopicCollection collection) =>
      'builtin_topic_${collection.id}';

  /// 确保合集 agent 配置存在并注入运行时（temporary 列表），返回该 agent
  ///
  /// - 独立存储已有配置：读取并刷新到临时列表（编辑保存后重新打开即生效）
  /// - 首次使用：以内置默认（合集 prompt 为 system 消息 + 首个服务商连接配置）
  ///   生成完整配置并写入独立存储
  Future<AIAgent> ensureCollectionAgent(TopicCollection collection) async {
    final controller = AgentController();
    await _cleanupLegacyAgents();
    final storageKey = storageKeyFor(collection);
    final stored = await controller.loadExtraStorageAgents(storageKey);
    AIAgent agent;
    if (stored.isNotEmpty) {
      agent = stored.first;
    } else {
      agent = await _defaultAgentFor(collection);
      await controller.saveAgentToExtraStorage(agent, storageKey);
    }
    controller.addTemporaryAgent(agent);
    return agent;
  }

  /// 旧版本曾把合集 agent 写入全局 agents.json（prompt 覆盖另存
  /// topic_collections.json）：getAgent 优先命中旧数据会让独立存储的
  /// 编辑不生效，启动后清掉（deleteAgent 拦截 builtin_ 前缀，
  /// 这里直接清洗存储文件与遗留文件）
  Future<void> _cleanupLegacyAgents() async {
    final path = '${OpenAIPlugin.instance.storageDir}/agents.json';
    final data = await AboutmeDataService.instance.readPath(path);
    if (data is Map<String, dynamic>) {
      final list = data['agents'];
      if (list is List && list.isNotEmpty) {
        final filtered =
            list.where((item) {
              final id = item is Map<String, dynamic> ? item['id'] : null;
              return id is! String || !id.startsWith('builtin_topic_');
            }).toList();
        if (filtered.length != list.length) {
          await AboutmeDataService.instance.writePath(path, {
            'agents': filtered,
          });
        }
      }
    }
    try {
      await AboutmeDataService.instance.deletePath(
        '${OpenAIPlugin.instance.storageDir}/topic_collections.json',
      );
    } catch (_) {}
  }

  /// 合集默认 agent：完整 AIAgent 配置，取首个服务商连接参数保证开箱可用
  Future<AIAgent> _defaultAgentFor(TopicCollection collection) async {
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
      // 无服务商时仍创建占位配置，用户可稍后在编辑页配置
    }

    return AIAgent(
      id: agentIdFor(collection),
      version: 1,
      name: collection.name,
      description: collection.description,
      tags: const ['话题合集'],
      serviceProviderId: providerId,
      baseUrl: baseUrl,
      headers: headers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      model: model,
      maxLength: 2048,
      icon: topicCollectionIcon(collection.id),
      messages: [Prompt(type: 'system', content: collection.prompt)],
      apiFormat: apiFormat,
    );
  }

  // ========== 话题会话 ==========

  /// 话题会话在 agent_chat 会话列表隐藏（入口只有话题 tab）
  static const String hiddenGroup = '话题';

  Map<String, dynamic> _metadataFor(
    TopicCollection collection,
    TopicNode topic,
  ) => {
    'hideInList': true,
    'topicChat': {'collectionId': collection.id, 'topicId': topic.id},
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
    TopicNode topic,
  ) {
    final service = _conversationService;
    if (service == null) return const [];
    final subtreeIds = topic.subtree().map((n) => n.id).toSet();
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

    final agent = await ensureCollectionAgent(collection);
    var conversation = await service.createConversation(
      title: '${collection.name}·${topic.title}',
      agentId: agent.id,
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
