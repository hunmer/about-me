import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/topic_collection.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/controllers/provider_controller.dart';

/// 话题合集聊天服务
///
/// 职责：
/// - 话题合集目录：JSON 分发（assets 内置 + 数据目录落地）。
///   [syncBuiltinCollections] 在进入 app（插件初始化）/首次加载时执行，
///   asset 的 version 高于数据目录时覆盖更新（合集 agent 配置与
///   已有会话不随之改动）
/// - 合集的 AI 是一份**完整 agent 配置**（模型/参数/人设等），
///   独立存储在 `openai/topic_agents_<collectionId>.json`
///   （extra storage，与全局 agents.json 互不影响），
///   编辑入口复用 [AgentEditScreen]（onSave 回调模式）
/// - 运行时经 [AgentController.addTemporaryAgent] 注入内存，
///   聊天链路按 agentId 即可解析（getAgent 含临时 agent）
/// - 按（合集 × 话题）创建/查询互相隔离的会话：
///   会话带 `hideInList` 元数据，不进 agent_chat 会话列表，入口只有话题 tab
/// - 新会话写入固定的第一条介绍消息（写入后不再改动，
///   后续改 agent 配置 / 换 agent 均不影响已写入的首条消息）
class TopicChatService {
  TopicChatService._();

  static final TopicChatService instance = TopicChatService._();

  /// 内置合集目录的 assets 目录
  static const String assetDir = 'assets/openai/topic_collections';

  List<TopicCollection>? _cachedCollections;

  /// 已加载的合集（数据目录为准；未加载时为空，先 [loadCollections]）
  List<TopicCollection> get collections =>
      List.unmodifiable(_cachedCollections ?? const []);

  /// 加载合集列表（首次自动执行资产同步）
  Future<List<TopicCollection>> loadCollections() async {
    final cached = _cachedCollections;
    if (cached != null) return cached;

    final syncedIds = await syncBuiltinCollections();
    final stored = <TopicCollection>[];
    for (final id in syncedIds) {
      try {
        final res = await AboutmeDataService.instance.call(
          'openai',
          'getTopicCollection',
          {'id': id},
        );
        final data = res['success'] == true ? res['data'] : null;
        if (data is Map<String, dynamic>) {
          stored.add(TopicCollection.fromJson(data));
        }
      } catch (e) {
        debugPrint('[TopicChat] 读取合集 $id 失败: $e');
      }
    }
    _cachedCollections = stored;
    return stored;
  }

  /// 使缓存失效（目录更新后下次重新加载）
  void invalidateCache() => _cachedCollections = null;

  /// 内置合集目录按 version 同步：asset 高于数据目录（或数据目录缺失）
  /// 时覆盖写入。返回同步后可用的合集 id 集合。
  Future<Set<String>> syncBuiltinCollections() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths =
        manifest
            .listAssets()
            .where(
              (asset) =>
                  asset.startsWith('$assetDir/') &&
                  asset.toLowerCase().endsWith('.json'),
            )
            .toList()
          ..sort();

    final ids = <String>{};
    for (final assetPath in assetPaths) {
      try {
        final json = jsonDecode(await rootBundle.loadString(assetPath));
        if (json is! Map<String, dynamic>) continue;
        final incoming = TopicCollection.fromJson(json);
        ids.add(incoming.id);

        final res = await AboutmeDataService.instance.call(
          'openai',
          'getTopicCollection',
          {'id': incoming.id},
        );
        final existing = res['success'] == true ? res['data'] : null;
        final existingVersion =
            existing is Map<String, dynamic>
                ? (existing['version'] as num?)?.toInt() ?? -1
                : -1;
        if (incoming.version > existingVersion) {
          await AboutmeDataService.instance.call(
            'openai',
            'saveTopicCollection',
            {'id': incoming.id, 'collection': incoming.toJson()},
          );
          debugPrint(
            '[TopicChat] 合集目录更新: ${incoming.id} '
            'v$existingVersion -> v${incoming.version}',
          );
        }
      } catch (e) {
        debugPrint('[TopicChat] 同步合集资产 $assetPath 失败: $e');
      }
    }
    return ids;
  }

  TopicCollection? collectionById(String id) {
    for (final collection in collections) {
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
      // 一次性迁移：旧默认配置无 alivenessConfig（编辑页保存后恒非 null），
      // 说明用户从未改过活人感/记忆设置，按合集默认补开记忆
      if (collection.memoryEnabled && agent.alivenessConfig == null) {
        agent = agent.copyWith(
          alivenessConfig: const AlivenessConfig(memoryEnabled: true),
        );
        await controller.saveAgentToExtraStorage(agent, storageKey);
      }
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
    final res = await AboutmeDataService.instance.call('openai', 'getAgents');
    final data = res['success'] == true ? res['data'] : null;
    if (data is Map<String, dynamic>) {
      final list = data['agents'];
      if (list is List && list.isNotEmpty) {
        final filtered =
            list.where((item) {
              final id = item is Map<String, dynamic> ? item['id'] : null;
              return id is! String || !id.startsWith('builtin_topic_');
            }).toList();
        if (filtered.length != list.length) {
          await AboutmeDataService.instance.call('openai', 'saveAgents', {
            'agents': {'agents': filtered},
          });
        }
      }
    }
    // 旧版遗留 topic_collections.json（合集 prompt 覆盖存储）启动清理
    try {
      await AboutmeDataService.instance.call(
        'openai',
        'deleteLegacyTopicCollections',
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
      icon: Icons.explore_rounded,
      messages: [Prompt(type: 'system', content: collection.prompt)],
      apiFormat: apiFormat,
      alivenessConfig:
          collection.memoryEnabled
              ? const AlivenessConfig(memoryEnabled: true)
              : null,
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
