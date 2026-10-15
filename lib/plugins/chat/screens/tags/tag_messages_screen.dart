import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/screens/timeline/controllers/timeline_controller/base_controller.dart';
import 'package:aboutme/plugins/chat/screens/timeline/controllers/timeline_controller/message_handler.dart';
import 'package:aboutme/plugins/chat/screens/timeline/models/timeline_filter.dart';
import 'package:aboutme/plugins/chat/screens/timeline/widgets/timeline_message_card.dart';
import 'package:aboutme/plugins/chat/utils/message_operations.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 标签消息页的轻量控制器：
/// 只驱动当前标签的消息列表，不加载全量消息、不持久化时间线状态
class _TagMessagesController extends BaseTimelineController
    with MessageHandlerMixin
    implements MessageActionsController {
  _TagMessagesController(
    ChatPlugin chatPlugin, {
    super.onMessageEdit,
    super.onMessageDelete,
    super.onMessageCopy,
    super.onSetFixedSymbol,
    super.onSetBubbleColor,
    super.onToggleFavorite,
  }) : super(
         chatPlugin: chatPlugin,
         searchController: TextEditingController(),
         scrollController: ScrollController(),
         filter: TimelineFilter(
           type: TimelineFilterType.all,
           title: 'All Messages',
           icon: Icons.all_inbox,
         ),
       );

  @override
  Future<void> saveTimelineState() async {}

  @override
  Future<void> refreshTimeline() async {}
}

/// 标签消息列表页面
/// 以瀑布流卡片展示某个标签的所有关联消息，复用时间线卡片
class TagMessagesScreen extends StatefulWidget {
  final String tagName;
  final List<Message> messages;
  final ChatPlugin chatPlugin;

  const TagMessagesScreen({
    super.key,
    required this.tagName,
    required this.messages,
    required this.chatPlugin,
  });

  @override
  State<TagMessagesScreen> createState() => _TagMessagesScreenState();
}

class _TagMessagesScreenState extends State<TagMessagesScreen> {
  late final _TagMessagesController _controller;
  late final MessageOperations _messageOperations;

  @override
  void initState() {
    super.initState();
    _messageOperations = MessageOperations(context);
    _controller = _TagMessagesController(
      widget.chatPlugin,
      onMessageEdit: (message) async {
        // 导航到消息所在的频道并开始编辑
        final channel = _controller.getMessageChannel(message);
        if (channel != null) {
          final result = await Navigator.pushNamed(
            context,
            '/channel/${channel.id}',
            arguments: {
              'channel': channel,
              'initialMessage': message,
              'startEditing': true,
            },
          );

          // 如果消息被编辑，刷新标签消息
          if (result == true) {
            await _reloadTagMessages();
          }
        }
      },
      onMessageDelete: (message) async {
        await _messageOperations.deleteMessage(message);
        // 删除消息后直接从列表中移除
        _controller.removeMessage(message);
      },
      onMessageCopy: (message) {
        _messageOperations.copyMessage(message);
      },
      onSetFixedSymbol: (message, symbol) async {
        await _messageOperations.setFixedSymbol(message, symbol);
        _controller.updateMessage(message);
      },
      onSetBubbleColor: (message, color) async {
        await _messageOperations.setBubbleColor(message, color);
        _controller.updateMessage(message);
      },
      onToggleFavorite: (message) async {
        await _messageOperations.toggleFavorite(message);
        _controller.updateMessage(message);
      },
    );

    _controller.allMessages = widget.messages;
    _controller.filterMessages();

    // 聊天数据变化时刷新标签消息
    widget.chatPlugin.addListener(_onChatDataChanged);
  }

  void _onChatDataChanged() {
    _reloadTagMessages();
  }

  /// 重新加载当前标签的消息
  Future<void> _reloadTagMessages() async {
    final messages = await widget.chatPlugin.tagService.getMessagesByTag(
      widget.tagName,
    );
    if (!mounted) return;
    _controller.allMessages = messages;
    _controller.filterMessages();
  }

  @override
  void dispose() {
    widget.chatPlugin.removeListener(_onChatDataChanged);
    _controller.dispose();
    super.dispose();
  }

  /// 构建瀑布流视图（复用时间线卡片列表）
  Widget _buildGridView() {
    const padding = 8.0;
    // 行间距 ≥ 贴条出血(12px),避免上一行贴条压盖
    const spacing = 16.0;

    return CustomScrollView(
      controller: _controller.scrollController,
      slivers: [
        SliverPadding(
          // 顶部加出血量,避免首行贴条被视口裁剪
          padding: EdgeInsets.fromLTRB(
            padding,
            padding + 12,
            padding,
            padding + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverMasonryGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridCard(index),
              childCount: _controller.displayMessages.length,
            ),
            gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
        ),
      ],
    );
  }

  /// 构建瀑布流卡片：手绘便签 + 时间线卡片
  Widget _buildGridCard(int index) {
    final message = _controller.displayMessages[index];
    final channel = _controller.getMessageChannel(message);
    if (channel == null) return const SizedBox.shrink();

    // 限制动画延迟，避免列表过长时延迟过大（最多延迟 500ms）
    final animationDelay = ((index * 50).clamp(0, 500)).ms;

    return HandDrawnStickyItem(
      tiltKey: message.id,
      child: Animate(
        key: ValueKey(message.id),
        effects: [
          FadeEffect(duration: 300.ms, delay: animationDelay),
          SlideEffect(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
            duration: 400.ms,
            delay: animationDelay,
            curve: Curves.easeOut,
          ),
        ],
        child: TimelineMessageCard(
          message: message,
          channel: channel,
          controller: _controller,
          isGridView: true,
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        emoji: _controller.searchQuery.isEmpty ? '🏷️' : '🔍',
        title:
            _controller.searchQuery.isEmpty
                ? 'chat_noMessagesYet'.tr
                : 'chat_noMatchingMessages'.tr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('#${widget.tagName}'),
        enableSearchBar: true,
        searchPlaceholder: 'chat_searchMessages'.tr,
        onSearchChanged: _onSearchChanged,
        onSearchSubmitted: _onSearchChanged,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.displayMessages.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: _reloadTagMessages,
              child: _buildGridView(),
            );
          },
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _controller.searchQuery = query;
    _controller.filterMessages();
  }
}
