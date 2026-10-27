import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node, Value;
import 'package:intl/intl.dart';

import 'package:aboutme/core/event/event.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/services/conversation_service.dart';
import 'package:aboutme/plugins/openai/models/topic_collection.dart';
import 'package:aboutme/plugins/openai/controllers/agent_controller.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/topic_chat_service.dart';
import 'package:aboutme/widgets/newspaper_sheet.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 话题合集 tab：合集选择 + 报刊架（分类报纸）
///
/// - 每个顶层分类渲染为一张报纸卡片（见 NewspaperSheet）：
///   报头（分类标题）+ 问题/已回答统计 + 进入详情按钮
/// - 详情页列出分类（含子分组）下的叶子话题，
///   点按弹出该话题的会话列表
/// - 会话经 TopicChatService 创建（hideInList，不进 agent_chat 列表），
///   打开后复用 agent_chat 的 ChatScreen
class TopicCollectionScreen extends StatefulWidget {
  const TopicCollectionScreen({super.key});

  @override
  State<TopicCollectionScreen> createState() => _TopicCollectionScreenState();
}

class _TopicCollectionScreenState extends State<TopicCollectionScreen> {
  TopicCollection? _selected;

  ConversationService? _conversationService;

  @override
  void initState() {
    super.initState();
    _bindConversationService();
    // agent_chat 若晚于本屏加载，插件就绪后重绑会话服务
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
    // 合集目录为 JSON 数据（首次自动从 assets 按 version 同步）
    TopicChatService.instance.loadCollections().then((collections) {
      if (!mounted || collections.isEmpty) return;
      _selectCollection(collections.first);
    });
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    _bindConversationService();
    // 合集列表加载是异步的：agent_chat 就绪前加载失败过的话重试
    if (TopicChatService.instance.collections.isEmpty) {
      TopicChatService.instance.loadCollections().then((collections) {
        if (!mounted || collections.isEmpty) return;
        _selectCollection(collections.first);
      });
      return;
    }
    setState(() {});
  }

  void _bindConversationService() {
    _conversationService?.removeListener(_onConversationsChanged);
    _conversationService =
        AgentChatPlugin.instance.conversationController?.conversationService;
    _conversationService?.addListener(_onConversationsChanged);
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _conversationService?.removeListener(_onConversationsChanged);
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  void _selectCollection(TopicCollection collection) {
    if (_selected?.id == collection.id) return;
    setState(() => _selected = collection);
  }

  @override
  Widget build(BuildContext context) {
    final collection = _selected;
    if (collection == null) {
      // 合集目录异步加载中（或为空）：空占位保持布局稳定
      return SuperCupertinoNavigationWrapper(
        title: Text('openai_topicsTab'.tr),
        largeTitle: 'openai_topicsTab'.tr,
        enableLargeTitle: false,
        body: const SizedBox.expand(),
      );
    }

    return SuperCupertinoNavigationWrapper(
      title: Text('openai_topicsTab'.tr),
      largeTitle: 'openai_topicsTab'.tr,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return Column(
              children: [
                _buildCollectionBar(theme),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      theme.spacing.lg,
                      theme.spacing.xs,
                      theme.spacing.lg,
                      theme.spacing.xl,
                    ),
                    itemCount: collection.topics.length,
                    itemBuilder: (context, index) => _buildTopicNewspaper(
                      theme,
                      collection,
                      collection.topics[index],
                      index,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.bot,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'openai_topicEditAgent'.tr,
                onPressed: () => _editCollectionAgent(collection),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 合集选择条（当前仅一份合集，后续可继续追加）
  Widget _buildCollectionBar(AppThemeData theme) {
    final collections = TopicChatService.instance.collections;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.lg,
        theme.spacing.sm,
        theme.spacing.lg,
        theme.spacing.xs,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: collections.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return DSChip(
              label: collection.name,
              icon: DsIconKind.category,
              selected: collection.id == _selected?.id,
              onSelected: (_) => _selectCollection(collection),
            );
          },
        ),
      ),
    );
  }

  // ========== 报刊架 ==========

  /// 分类统计：子树内叶子话题数 = 问题数，挂有会话的叶子数 = 已回答数
  Widget _buildTopicNewspaper(
    AppThemeData theme,
    TopicCollection collection,
    TopicNode topic,
    int index,
  ) {
    final counts = TopicChatService.instance.conversationCounts(collection);
    final leaves = topic.subtree().where((node) => !node.isGroup).toList();
    final answered = leaves
        .where((node) => (counts[node.id] ?? 0) > 0)
        .length;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.lg),
      child: Center(
        // 报刊架错落感：奇偶交替微微倾斜
        child: Transform.rotate(
          angle: (index.isEven ? -1.1 : 1.0) * math.pi / 180,
          child: _TopicNewspaper(
            title: topic.title,
            total: leaves.length,
            answered: answered,
            onTap: () => NavigationHelper.push(
              context,
              _TopicGroupDetailScreen(collection: collection, group: topic),
            ),
          ),
        ),
      ),
    );
  }

  // ========== 合集 agent 配置 ==========

  /// 打开 agent 编辑页：合集的 AI 是一份完整 agent 配置，
  /// 独立存储（extra storage），经 AgentEditScreen 编辑。
  /// 走 onSave 回调模式：保存由回调写独立存储，
  /// 编辑页的分享/克隆/删除入口（面向全局 agent 列表）不出现
  Future<void> _editCollectionAgent(TopicCollection collection) async {
    final agent = await TopicChatService.instance.ensureCollectionAgent(
      collection,
    );
    if (!mounted) return;
    await NavigationHelper.push(
      context,
      AgentEditScreen(
        agent: agent,
        onSave: (edited) async {
          await AgentController().saveAgentToExtraStorage(
            edited,
            TopicChatService.storageKeyFor(collection),
          );
          return edited;
        },
      ),
    );
    // 编辑保存写入了独立存储，重新注入临时表让新对话立即生效
    await TopicChatService.instance.ensureCollectionAgent(collection);
  }
}

/// 分类报纸卡片：报头（分类标题）+ 问题/已回答统计 + 进入详情按钮
class _TopicNewspaper extends StatelessWidget {
  const _TopicNewspaper({
    required this.title,
    required this.total,
    required this.answered,
    this.onTap,
  });

  final String title;
  final int total;
  final int answered;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(336.0, size.width - 40);
    final date = DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
    return GestureDetector(
      onTap: onTap,
      child: NewspaperSheet(
        width: width,
        height: 192,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部信息行（报纸日期栏风格）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOPIC EDITION',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6B6B6B),
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  date.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6B6B6B),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            // 报头：分类标题
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF141413),
                  fontFamilyFallback: ['serif'],
                ),
              ),
            ),
            // 报纸双线分隔
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Column(
                children: [
                  ColoredBox(
                    color: Color(0xFF262626),
                    child: SizedBox(width: double.infinity, height: 1.5),
                  ),
                  SizedBox(height: 1.5),
                  ColoredBox(
                    color: Color(0xFF262626),
                    child: SizedBox(width: double.infinity, height: 0.7),
                  ),
                ],
              ),
            ),
            // 统计与按钮
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statNumber(
                            '$total',
                            'openai_topicQuestions'.tr,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 42,
                          color: const Color(0x33262626),
                        ),
                        Expanded(
                          child: _statNumber(
                            '$answered',
                            'openai_topicAnswered'.tr,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$answered / $total',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A8A),
                            letterSpacing: 1,
                          ),
                        ),
                        _buildOpenButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statNumber(String number, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w800,
            color: Color(0xFF141413),
            fontFamilyFallback: ['serif'],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B6B6B),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF141413),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'openai_topicOpenDetail'.tr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// 分类详情页：列出分类（含子分组）下的叶子话题，点按弹出会话列表
class _TopicGroupDetailScreen extends StatefulWidget {
  const _TopicGroupDetailScreen({
    required this.collection,
    required this.group,
  });

  final TopicCollection collection;
  final TopicNode group;

  @override
  State<_TopicGroupDetailScreen> createState() =>
      _TopicGroupDetailScreenState();
}

class _TopicGroupDetailScreenState extends State<_TopicGroupDetailScreen> {
  ConversationService? _conversationService;

  List<TopicNode> get _leaves =>
      widget.group.subtree().where((node) => !node.isGroup).toList();

  @override
  void initState() {
    super.initState();
    _bindConversationService();
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
  }

  void _onPluginLoaded(EventArgs args) {
    if (args is! Value<String> || args.value != 'agent_chat' || !mounted) {
      return;
    }
    _bindConversationService();
    setState(() {});
  }

  void _bindConversationService() {
    _conversationService?.removeListener(_onConversationsChanged);
    _conversationService =
        AgentChatPlugin.instance.conversationController?.conversationService;
    _conversationService?.addListener(_onConversationsChanged);
  }

  @override
  void dispose() {
    eventManager.unsubscribe('plugin_loaded', _onPluginLoaded);
    _conversationService?.removeListener(_onConversationsChanged);
    super.dispose();
  }

  void _onConversationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      title: Text(widget.group.title),
      largeTitle: widget.group.title,
      enableLargeTitle: false,
      body: DSThemeBridge(
        child: Builder(
          builder: (context) {
            final theme = DSThemeBridge.resolve(context);
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.lg,
                theme.spacing.md,
                theme.spacing.lg,
                theme.spacing.xl,
              ),
              itemCount: _leaves.length,
              separatorBuilder: (_, __) => SizedBox(height: theme.spacing.md),
              itemBuilder: (context, index) =>
                  _buildTopicTile(theme, _leaves[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopicTile(AppThemeData theme, TopicNode topic) {
    final count = _conversationCount(topic);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showTopicSheet(topic),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm + 2,
        ),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    topic.title,
                    style: DsTypography.body.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topic.depthLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      topic.depthLabel!,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: dsSketchDecoration(
                  theme: theme,
                  fillColor: theme.primary,
                  circle: true,
                ),
                child: Text(
                  '$count',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.onPrimary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            DsIcon(DsIconKind.chevronRight, size: 16, color: theme.textSub),
          ],
        ),
      ),
    );
  }

  int? _conversationCount(TopicNode topic) {
    final counts = TopicChatService.instance.conversationCounts(
      widget.collection,
    );
    final count = widget.collection.conversationCountFor(topic, counts);
    return count > 0 ? count : null;
  }

  // ========== 话题会话 ==========

  Future<void> _showTopicSheet(TopicNode topic) async {
    final theme = DSThemeBridge.resolve(context);
    await SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: topic.title,
      child: Builder(
        builder: (sheetContext) {
          final conversations = TopicChatService.instance.conversationsFor(
            widget.collection,
            topic,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmoothSheetAction(
                icon: DsIconKind.plus,
                label: 'openai_topicNewConversation'.tr,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _createAndOpen(topic);
                },
              ),
              if (conversations.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    theme.spacing.lg,
                    theme.spacing.md,
                    theme.spacing.lg,
                    theme.spacing.xs,
                  ),
                  child: Text(
                    'openai_topicConversations'.tr,
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                    ),
                  ),
                ),
                ...conversations.asMap().entries.map(
                  (entry) => _buildConversationTile(
                    theme,
                    topic,
                    entry.key + 1,
                    entry.value,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(
    AppThemeData theme,
    TopicNode topic,
    int index,
    Conversation conversation,
  ) {
    final time = DateFormat('MM-dd HH:mm').format(conversation.lastMessageAt);
    return Padding(
      padding: EdgeInsets.only(
        left: theme.spacing.md,
        right: theme.spacing.md,
        bottom: theme.spacing.sm,
      ),
      child: Container(
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: theme.surface,
          radius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openConversation(conversation),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.spacing.md,
                    vertical: theme.spacing.sm + 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'openai_topicConversationLabel'.trParams({
                              'index': '$index',
                            }),
                            style: DsTypography.body.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            time,
                            style: DsTypography.caption.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                      if (conversation.lastMessagePreview?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 2),
                        Text(
                          conversation.lastMessagePreview!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: theme.spacing.sm),
              child: DSIconButton(
                icon: DsIconKind.trash,
                size: 32,
                color: Colors.transparent,
                iconColor: theme.textSub,
                tooltip: 'openai_topicDeleteConversation'.tr,
                onPressed: () =>
                    _confirmDeleteConversation(topic, conversation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    TopicNode topic,
    Conversation conversation,
  ) async {
    final theme = DSThemeBridge.resolve(context);
    final confirm = await showDSDialog<bool>(
      context: context,
      theme: theme,
      builder: (dialogContext) => DSDialog(
        title: 'openai_topicDeleteConversation'.tr,
        message: 'openai_topicDeleteConfirm'.tr,
        cancelText: 'app_cancel'.tr,
        confirmText: 'openai_topicDeleteConversation'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(dialogContext, true),
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
    if (confirm != true) return;
    await _conversationService?.deleteConversation(conversation.id);
    if (mounted) {
      toastService.showToast('openai_topicConversationDeleted'.tr);
      // 会话删完后收起话题 sheet，回到话题列表
      if (TopicChatService.instance
          .conversationsFor(widget.collection, topic)
          .isEmpty) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _createAndOpen(TopicNode topic) async {
    try {
      final conversation = await TopicChatService.instance.createConversation(
        collection: widget.collection,
        topic: topic,
      );
      if (!mounted) return;
      _openConversation(conversation);
    } catch (e) {
      if (mounted) {
        toastService.showToast('${'openai_topicCreateFailed'.tr}: $e');
      }
    }
  }

  void _openConversation(Conversation conversation) async {
    final controller = AgentChatPlugin.instance.conversationController;
    if (controller == null) {
      toastService.showToast('openai_topicChatUnavailable'.tr);
      return;
    }
    // 合集 agent 存在独立存储（extra storage），会话按 agentId 解析前
    // 需注入临时列表（app 重启后临时表为空）
    final collection = TopicChatService.instance.collectionById(
      TopicChatService.topicInfoOf(conversation)?.collectionId ?? '',
    );
    if (collection != null) {
      await TopicChatService.instance.ensureCollectionAgent(collection);
    }
    if (!mounted) return;
    NavigationHelper.push(
      context,
      ChatScreen(
        conversation: conversation,
        storage: AgentChatPlugin.instance.storage,
        conversationService: controller.conversationService,
        getSettings: () => AgentChatPlugin.instance.settings,
      ),
    );
  }
}
