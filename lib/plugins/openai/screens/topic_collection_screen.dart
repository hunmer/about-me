import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Node, Value;
import 'package:graphview/graphview.dart';
import 'package:intl/intl.dart';
import 'package:skribble/skribble.dart' show WiredDraw, WiredDrawTransition;

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
import 'package:aboutme/plugins/openai/services/topic_chat_service.dart';
import 'package:aboutme/plugins/openai/widgets/sketch_tree_edge_renderer.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 话题合集 tab：合集选择 + graphview 手绘话题树
///
/// - 话题树无限层级（分组下可以有分组或话题）；
///   分组节点点按展开/收起子树，叶子话题点按弹出该话题的会话列表
/// - 会话经 TopicChatService 创建（hideInList，不进 agent_chat 列表），
///   打开后复用 agent_chat 的 ChatScreen
class TopicCollectionScreen extends StatefulWidget {
  const TopicCollectionScreen({super.key});

  @override
  State<TopicCollectionScreen> createState() => _TopicCollectionScreenState();
}

/// 合集对应的图结构缓存（切换合集保留展开状态）
class _CollectionGraph {
  _CollectionGraph(this.graph, this.controller, this.rootNode);

  final Graph graph;
  final GraphViewController controller;
  final Node rootNode;
}

class _TopicCollectionScreenState extends State<TopicCollectionScreen> {
  TopicCollection? _selected;
  final Map<String, _CollectionGraph> _graphCache = {};
  Map<String, TopicNode> _nodesById = {};

  ConversationService? _conversationService;

  @override
  void initState() {
    super.initState();
    _bindConversationService();
    // agent_chat 若晚于本屏加载，插件就绪后重绑会话服务
    eventManager.subscribe('plugin_loaded', _onPluginLoaded);
    // 首个合集在挂载时初始化（build 内调用 setState 不合法）
    final first = TopicChatService.instance.collections.first;
    _graphCache[first.id] = _buildGraph(first);
    _applyCollection(first);
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

  /// 切换合集并重建节点索引
  void _applyCollection(TopicCollection collection) {
    _selected = collection;
    _nodesById = {
      for (final node in collection.topics)
        for (final candidate in node.subtree()) candidate.id: candidate,
    };
  }

  /// 选择合集（缓存话题图，切换回来保留展开状态）
  void _selectCollection(TopicCollection collection) {
    if (_selected?.id == collection.id) return;
    _graphCache[collection.id] ??= _buildGraph(collection);
    setState(() => _applyCollection(collection));
  }

  /// 顶层分组节点初始收起：首屏只展示 根 + 各阶段，
  /// 点按分组展开子树（graphview 自带展开/收起动画）
  _CollectionGraph _buildGraph(TopicCollection collection) {
    final graph = Graph()..isTree = true;
    final controller = GraphViewController();

    Node addNode(String id) {
      final node = Node.Id(id);
      graph.addNode(node);
      return node;
    }

    final root = addNode(_rootId);
    void addTree(Node parent, TopicNode topic) {
      final node = addNode(topic.id);
      graph.addEdge(parent, node);
      for (final child in topic.children) {
        addTree(node, child);
      }
    }

    final groupNodes = <Node>[];
    for (final topic in collection.topics) {
      final node = addNode(topic.id);
      graph.addEdge(root, node);
      for (final child in topic.children) {
        addTree(node, child);
      }
      if (topic.isGroup) groupNodes.add(node);
    }
    controller.setInitiallyCollapsedNodes(graph, groupNodes);
    return _CollectionGraph(graph, controller, root);
  }

  static const String _rootId = '__topic_root__';

  @override
  Widget build(BuildContext context) {
    final collection = _selected!;
    final bundle = _graphCache[collection.id]!;

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
                  child: WiredDraw(
                    key: ValueKey('topic_graph_${collection.id}'),
                    child: GraphView.builder(
                      graph: bundle.graph,
                      controller: bundle.controller,
                      animated: true,
                      autoZoomToFit: true,
                      paint:
                          Paint()
                            ..color = theme.ink.withValues(alpha: 0.6)
                            ..strokeWidth = 2
                            ..style = PaintingStyle.stroke,
                      algorithm: _buildAlgorithm(theme),
                      builder: (Node node) => _buildNodeWidget(
                        theme,
                        collection,
                        bundle,
                        node,
                      ),
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
                icon: DsIconKind.edit,
                size: 36,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                tooltip: 'openai_topicEditPrompt'.tr,
                onPressed: () => _showPromptEditor(collection),
              );
            },
          ),
        ),
      ],
    );
  }

  BuchheimWalkerAlgorithm _buildAlgorithm(AppThemeData theme) {
    final config =
        BuchheimWalkerConfiguration()
          ..siblingSeparation = 48
          ..subtreeSeparation = 64
          ..levelSeparation = 96
          ..orientation = BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT;
    return BuchheimWalkerAlgorithm(
      config,
      SketchTreeEdgeRenderer(
        config,
        drawConfig: theme.wired.drawConfig,
        color: theme.ink.withValues(alpha: 0.6),
        strokeWidth: 1.8,
      ),
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

  // ========== 节点 ==========

  Widget _buildNodeWidget(
    AppThemeData theme,
    TopicCollection collection,
    _CollectionGraph bundle,
    Node node,
  ) {
    final id = node.key?.value as String;
    if (id == _rootId) {
      return _TopicNodePill(
        collection.name,
        icon: DsIconKind.sparkle,
        fillColor: theme.primary,
        foreground: theme.onPrimary,
        onTap: () {},
      );
    }
    final topic = _nodesById[id];
    if (topic == null) return const SizedBox.shrink();

    if (topic.isGroup) {
      final collapsed = bundle.controller.isNodeCollapsed(node);
      return _TopicNodePill(
        topic.title,
        icon: collapsed ? DsIconKind.chevronRight : DsIconKind.chevronDown,
        fillColor: theme.surface,
        foreground: theme.text,
        badge: _conversationCount(collection, topic),
        onTap: () => bundle.controller.toggleNodeExpanded(
          bundle.graph,
          node,
          animate: true,
        ),
      );
    }

    return _TopicNodePill(
      topic.title,
      sublabel: topic.depthLabel,
      fillColor: theme.surfaceAlt,
      foreground: theme.text,
      badge: _conversationCount(collection, topic),
      onTap: () => _showTopicSheet(collection, topic),
    );
  }

  int? _conversationCount(TopicCollection collection, TopicNode topic) {
    final counts = TopicChatService.instance.conversationCounts(collection);
    final count = collection.conversationCountFor(topic, counts);
    return count > 0 ? count : null;
  }

  // ========== 话题会话 ==========

  Future<void> _showTopicSheet(
    TopicCollection collection,
    TopicNode topic,
  ) async {
    final theme = DSThemeBridge.resolve(context);
    await SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: topic.title,
      child: Builder(
        builder: (sheetContext) {
          final conversations = TopicChatService.instance.conversationsFor(
            collection,
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
                  await _createAndOpen(collection, topic);
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
                    collection,
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
    TopicCollection collection,
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
                    _confirmDeleteConversation(collection, topic, conversation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(
    TopicCollection collection,
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
      // 会话删完后收起话题 sheet，回到话题树
      if (TopicChatService.instance
          .conversationsFor(collection, topic)
          .isEmpty) {
        Navigator.of(context).maybePop();
      }
    }
  }

  Future<void> _createAndOpen(
    TopicCollection collection,
    TopicNode topic,
  ) async {
    try {
      final conversation = await TopicChatService.instance.createConversation(
        collection: collection,
        topic: topic,
      );
      if (!mounted) return;
      _openConversation(conversation);
    } catch (e) {
      if (mounted) toastService.showToast('${'openai_topicCreateFailed'.tr}: $e');
    }
  }

  void _openConversation(Conversation conversation) {
    final controller = AgentChatPlugin.instance.conversationController;
    if (controller == null) {
      toastService.showToast('openai_topicChatUnavailable'.tr);
      return;
    }
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

  // ========== prompt 自定义 ==========

  Future<void> _showPromptEditor(TopicCollection collection) async {
    final controller = TextEditingController(
      text: await TopicChatService.instance.effectivePrompt(collection),
    );
    final theme = DSThemeBridge.resolve(context);
    await SmoothBottomSheet.showForm(
      context: context,
      title: 'openai_topicEditPrompt'.tr,
      onSave: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        Navigator.pop(context);
        await TopicChatService.instance.setPromptOverride(collection, text);
        if (mounted) {
          toastService.showToast('openai_topicPromptSaved'.tr);
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'openai_topicPromptHint'.trParams({'name': collection.name}),
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            const SizedBox(height: 12),
            DSInput(
              controller: controller,
              maxLines: 10,
              minLines: 6,
              maxLength: 8000,
              hint: 'openai_topicPromptPlaceholder'.tr,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// 话题树节点：手绘胶囊（dsSketchDecoration 墨线 + 实底）
class _TopicNodePill extends StatelessWidget {
  const _TopicNodePill(
    this.label, {
    this.sublabel,
    this.icon,
    this.fillColor,
    this.foreground,
    this.badge,
    this.onTap,
  });

  final String label;
  final String? sublabel;
  final DsIconKind? icon;
  final Color? fillColor;
  final Color? foreground;
  final int? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final progress = WiredDrawTransition.progressOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: dsSketchDecoration(
          theme: theme,
          fillColor: fillColor,
          radius: BorderRadius.circular(999),
          progress: progress,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              DsIcon(icon!, size: 14, color: foreground ?? theme.textSub),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DsTypography.caption.copyWith(
                      color: foreground ?? theme.text,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      sublabel!,
                      style: DsTypography.caption.copyWith(
                        fontSize: 10,
                        color: foreground?.withValues(alpha: 0.8) ??
                            theme.textSub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
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
                  '$badge',
                  style: DsTypography.caption.copyWith(
                    fontSize: 10,
                    color: theme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
