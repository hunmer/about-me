import 'package:aboutme/core/plugin_manager.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/event.dart' as aboutme_event;
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/utils/image_utils.dart';
import 'package:aboutme/plugins/openai/handlers/chat_event_handler.dart'; // 导入ValuesEventArgs
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // 添加File类支持
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/screens/profile_edit_dialog.dart';
import 'package:aboutme/plugins/chat/utils/message_operations.dart';
import 'package:aboutme/plugins/chat/services/ai_thread_service.dart';
// 移除未使用的导入
import 'controllers/chat_screen_controller.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input/index.dart';
import 'widgets/chat_screen_scaffold.dart';
import 'dialogs/clear_messages_dialog.dart';
import 'utils/message_list_builder.dart';
// SuperCupertino 导航包装器
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'widgets/auto_reply_settings_sheet.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final Channel channel;
  final Message? initialMessage;
  final Message? highlightMessage;
  final bool autoScroll;

  const ChatScreen({
    super.key,
    required this.channel,
    this.initialMessage,
    this.highlightMessage,
    this.autoScroll = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatScreenController _controller;
  late MessageOperations _messageOperations;
  Message? _replyToMessage; // 添加回复消息引用
  String? _backgroundPath; // 存储背景图片的绝对路径
  bool _isLoadingBackground = true; // 标记背景图片是否正在加载
  final eventManager = EventManager.instance; // 获取事件管理器实例

  // 搜索和过滤状态
  String _searchQuery = '';
  final MultiFilterState _filterState = MultiFilterState();
  List<Message> _filteredMessages = [];

  // 上一次 FutureBuilder 成功返回的消息项：每次通知都会生成新 Future，
  // waiting 窗口内沿用旧数据，避免列表被清空重建导致气泡入场动画重播
  List<dynamic>? _lastMessageItems;

  @override
  void initState() {
    super.initState();
    _controller = ChatScreenController(
      channel: widget.channel,
      chatPlugin: ChatPlugin.instance,
      initialMessage: widget.initialMessage,
      highlightMessage: widget.highlightMessage,
      autoScroll: widget.autoScroll,
    );
    // 添加监听器，当 ChatPlugin 发生变化时重新加载背景
    ChatPlugin.instance.addListener(_handleChatPluginUpdate);
    // 订阅消息更新事件
    eventManager.subscribe('chat_message_updated', _handleMessageUpdated);
    // 订阅同步刷新事件（用于同步后的全量刷新）
    eventManager.subscribe('chat_refresh', _handleSyncRefresh);
    _loadBackgroundPath();
    _loadChannelDraft();
    unawaited(AiThreadService.instance.loadChannel(widget.channel.id));

    // 初始化时设置路由上下文
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRouteContext();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初始化消息操作工具类，在didChangeDependencies中初始化以安全地使用context
    _messageOperations = MessageOperations(context);
  }

  Future<void> _loadChannelDraft() async {
    final chatPlugin = ChatPlugin.instance;

    if (!mounted) return;

    // 检查插件是否已初始化
    try {
      final draft = await chatPlugin.channelService.loadDraft(
        widget.channel.id,
      );
      if (draft != null && draft.isNotEmpty && mounted) {
        setState(() {
          // 检查控制器是否可用
          if (_controller.draftController.text != draft) {
            _controller.draftController.text = draft;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
      // 可以在这里添加用户提示
    }
  }

  @override
  void dispose() {
    // 移除监听器
    ChatPlugin.instance.removeListener(_handleChatPluginUpdate);
    // 取消订阅消息更新事件
    eventManager.unsubscribe('chat_message_updated', _handleMessageUpdated);
    // 取消订阅同步刷新事件
    eventManager.unsubscribe('chat_refresh', _handleSyncRefresh);
    _controller.dispose();
    _filterState.dispose();
    // MessageOperations不需要dispose
    super.dispose();
  }

  // 处理消息更新事件（兼容两种事件载荷：openai 的 ValuesEventArgs 与 chat 插件的 Value）
  void _handleMessageUpdated(aboutme_event.EventArgs args) {
    Message? message;
    if (args is ValuesEventArgs<Message, String>) {
      message = args.value1;
    } else if (args is aboutme_event.Value<Message>) {
      message = args.value;
    }
    if (message == null) return;

    // 检查更新的消息是否属于当前频道
    if (message.channelId != widget.channel.id) return;

    // 重新加载消息列表
    _controller.reloadMessages();
  }

  // 处理同步刷新事件（来自 RouteRefreshManager）
  void _handleSyncRefresh(aboutme_event.EventArgs args) {
    debugPrint('[ChatScreen] 收到同步刷新事件');
    // 重新加载消息列表
    _controller.reloadMessages();
  }

  // 处理 ChatPlugin 更新
  void _handleChatPluginUpdate() {
    // 检查当前频道是否更新
    final updatedChannel = ChatPlugin.instance.channelService.channels
        .firstWhere(
          (c) => c.id == widget.channel.id,
          orElse: () => widget.channel,
        );

    // 如果背景路径发生变化，重新加载背景
    if (updatedChannel.backgroundPath != widget.channel.backgroundPath) {
      debugPrint('背景图片已更新，重新加载: ${updatedChannel.backgroundPath}');
      setState(() {
        _isLoadingBackground = true;
      });
      _loadBackgroundPath();

      // 强制重建背景图片
      if (_backgroundPath != null) {
        setState(() {
          // 添加一个随机参数，确保Image.file重新加载
          _backgroundPath =
              "$_backgroundPath?t=${DateTime.now().millisecondsSinceEpoch}";
        });
      }
    }
  }

  // 更新消息列表
  void _updateMessages() {
    _controller.reloadMessages();
  }

  // 处理回复消息
  void _handleReply(Message message) {
    setState(() {
      _replyToMessage = message;
    });
    // 聚焦输入框
    _controller.focusNode.requestFocus();
  }

  // 处理消息收藏
  void _handleToggleFavorite(Message message) async {
    await _messageOperations.toggleFavorite(message);
    if (mounted) {
      _updateMessages(); // 更新消息列表
    }
  }

  // 清除回复
  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  // 处理回复消息点击
  void _handleReplyTap(String messageId) {
    final message = widget.channel.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => widget.channel.messages.first,
    );
    _controller.scrollToMessage(message);
  }

  void _showEditDialog(Message message) async {
    if (!mounted) return;
    await _messageOperations.editMessage(message);
    if (mounted) {
      _updateMessages(); // 更新消息列表
    }
  }

  void _showClearConfirmationDialog() {
    final BuildContext currentContext = context;
    showDSDialog(
      context: currentContext,
      theme: DSThemeBridge.resolve(currentContext),
      builder: (BuildContext dialogContext) => ClearMessagesDialog(
        onConfirm: () async {
          await _controller.clearMessages();
          if (!mounted) return;
          _updateMessages(); // 更新消息列表
          if (currentContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
        onCancel: () {
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  void _copySelectedMessages() {
    final selectedMessages = _controller.messages
        .where((msg) => _controller.selectedMessageIds.value.contains(msg.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    final textToCopy = selectedMessages
        .map((msg) => '${msg.user.username}: ${msg.content}')
        .join('\n\n');

    Clipboard.setData(ClipboardData(text: textToCopy));
    Toast.success('chat_copiedSelectedMessages'.tr);

    _controller.toggleMultiSelectMode();
  }

  /// 删除多条选中的消息
  Future<void> _deleteSelectedMessages() async {
    final selectedMessages = _controller.messages
        .where((msg) => _controller.selectedMessageIds.value.contains(msg.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    // 显示一次确认对话框
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSThemeBridge(
        child: Builder(
          builder: (context) => DSDialog(
            title: 'chat_deleteMessages'.tr,
            message: '确定要删除选中的 ${selectedMessages.length} 条消息吗？此操作不可撤销。',
            cancelText: 'app_cancel'.tr,
            confirmText: 'chat_delete'.tr,
            confirmVariant: DSButtonVariant.destructive,
            onConfirm: () => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    // 使用批量删除方法，只触发一次 UI 更新
    await _messageOperations.deleteMessagesWithoutConfirmation(
      selectedMessages,
    );

    if (mounted) {
      _updateMessages(); // 重新加载消息列表
      _controller.toggleMultiSelectMode();
    }
  }

  /// 更新路由上下文，使"询问当前上下文"功能能获取到当前频道信息
  void _updateRouteContext() {
    RouteHistoryManager.updateCurrentContext(
      pageId: '/chat/channel',
      title: widget.channel.title,
      params: {
        'channelId': widget.channel.id,
        'channelName': widget.channel.title,
      },
    );
  }

  /// 搜索回调
  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFiltersAndSearch();
    });
  }

  /// 过滤回调
  void _handleFilterChanged(Map<String, dynamic> filters) {
    debugPrint('Filter changed: $filters');
    // 更新 _filterState 中的值
    filters.forEach((key, value) {
      _filterState.setValue(key, value);
    });
    _applyFiltersAndSearch();
  }

  /// 应用搜索和过滤
  void _applyFiltersAndSearch() {
    List<Message> result = List.from(_controller.messages);

    // 应用搜索
    if (_searchQuery.isNotEmpty) {
      result = result.where((msg) {
        return msg.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            msg.user.username.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();
    }

    // 应用发送人过滤
    final selectedUser = _filterState.getValue('sender');
    if (selectedUser != null &&
        selectedUser is String &&
        selectedUser.isNotEmpty) {
      result = result.where((msg) => msg.user.id == selectedUser).toList();
    }

    // 应用日期范围过滤
    final dateRange = _filterState.getValue('dateRange');
    if (dateRange != null && dateRange is Map<String, DateTime?>) {
      final startDate = dateRange['start'];
      final endDate = dateRange['end'];

      result = result.where((msg) {
        if (startDate != null && msg.date.isBefore(startDate)) return false;
        if (endDate != null) {
          final endOfDay = DateTime(
            endDate.year,
            endDate.month,
            endDate.day,
            23,
            59,
            59,
          );
          if (msg.date.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
    }

    // 应用标签过滤
    final selectedTags = _filterState.getValue('tags');
    if (selectedTags != null &&
        selectedTags is List &&
        selectedTags.isNotEmpty) {
      result = result.where((msg) {
        final messageTags = msg.metadata?['tags'] as List<String>?;
        if (messageTags == null || messageTags.isEmpty) return false;
        // 检查消息是否包含任意一个选中的标签
        return selectedTags.any((tag) => messageTags.contains(tag));
      }).toList();
    }

    setState(() {
      _filteredMessages = result;
    });
  }

  /// 获取所有唯一用户列表
  List<User> _getAllUsers() {
    final users = <String, User>{};
    for (var message in _controller.messages) {
      users[message.user.id] = message.user;
    }
    return users.values.toList();
  }

  /// 获取所有唯一标签列表
  List<String> _getAllTags() {
    final tags = <String>{};
    for (var message in _controller.messages) {
      final messageTags = message.metadata?['tags'] as List?;
      if (messageTags != null) {
        for (var tag in messageTags) {
          if (tag is String) tags.add(tag);
        }
      }
    }
    return tags.toList()..sort();
  }

  /// 构建过滤器配置
  List<FilterItem> _buildFilterItems() {
    final allUsers = _getAllUsers();
    final allTags = _getAllTags();

    return [
      // 发送人过滤
      FilterItem(
        id: 'sender',
        title: '发送人',
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          return Wrap(
            spacing: 8,
            children: allUsers.map((user) {
              final isSelected = currentValue == user.id;
              return DSChip(
                label: user.username,
                selected: isSelected,
                onSelected: (selected) {
                  onChanged(selected ? user.id : null);
                },
              );
            }).toList(),
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final user = allUsers.firstWhere(
            (u) => u.id == value,
            orElse: () => allUsers.first,
          );
          return user.username;
        },
      ),

      // 日期范围过滤
      FilterItem(
        id: 'dateRange',
        title: '日期',
        type: FilterType.dateRange,
        builder: (context, currentValue, onChanged) {
          final Map<String, DateTime?> range =
              currentValue ?? {'start': null, 'end': null};
          final startDate = range['start'];
          final endDate = range['end'];

          return Wrap(
            spacing: 8,
            children: [
              // 开始日期
              DSThemeBridge(
                child: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return DSChip(
                      icon: DsIconKind.calendar,
                      label: startDate == null
                          ? '开始日期'
                          : DateFormat('MM/dd').format(startDate),
                      onSelected: (_) async {
                        final picked = await showDSDatePickerDialog(
                          context: context,
                          theme: theme,
                          initial: startDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          onChanged({'start': picked, 'end': endDate});
                        }
                      },
                    );
                  },
                ),
              ),
              // 结束日期
              DSThemeBridge(
                child: Builder(
                  builder: (context) {
                    final theme = DSThemeBridge.resolve(context);
                    return DSChip(
                      icon: DsIconKind.calendar,
                      label: endDate == null
                          ? '结束日期'
                          : DateFormat('MM/dd').format(endDate),
                      onSelected: (_) async {
                        final picked = await showDSDatePickerDialog(
                          context: context,
                          theme: theme,
                          initial: endDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          onChanged({'start': startDate, 'end': picked});
                        }
                      },
                    );
                  },
                ),
              ),
              // 清除按钮
              if (startDate != null || endDate != null)
                DSThemeBridge(
                  child: Builder(
                    builder: (context) {
                      final theme = DSThemeBridge.resolve(context);
                      return DSIconButton(
                        icon: DsIconKind.close,
                        size: 32,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => onChanged(null),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          final Map<String, DateTime?> range = value;
          final start = range['start'];
          final end = range['end'];
          if (start != null && end != null) {
            return '${DateFormat('MM/dd').format(start)}-${DateFormat('MM/dd').format(end)}';
          } else if (start != null) {
            return '从${DateFormat('MM/dd').format(start)}';
          } else if (end != null) {
            return '至${DateFormat('MM/dd').format(end)}';
          }
          return null;
        },
      ),

      // 标签过滤
      if (allTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: '标签',
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            final List<String> selectedTags = currentValue ?? [];
            return Wrap(
              spacing: 8,
              children: allTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return DSChip(
                  label: tag,
                  selected: isSelected,
                  onSelected: (selected) {
                    final newTags = List<String>.from(selectedTags);
                    if (selected) {
                      newTags.add(tag);
                    } else {
                      newTags.remove(tag);
                    }
                    onChanged(newTags.isEmpty ? null : newTags);
                  },
                );
              }).toList(),
            );
          },
          getBadge: (value) {
            if (value == null || (value as List).isEmpty) return null;
            final tags = value as List<String>;
            return tags.length == 1 ? tags[0] : '${tags.length}个标签';
          },
        ),
    ];
  }

  // 加载背景图片路径
  Future<void> _loadBackgroundPath() async {
    // 获取最新的频道数据
    final currentChannel = ChatPlugin.instance.channelService.channels
        .firstWhere(
          (c) => c.id == widget.channel.id,
          orElse: () => widget.channel,
        );

    if (currentChannel.backgroundPath == null) {
      setState(() {
        _backgroundPath = null;
        _isLoadingBackground = false;
      });
      return;
    }

    try {
      final absolutePath = await ImageUtils.getAbsolutePath(
        currentChannel.backgroundPath!,
      );

      if (mounted) {
        final file = File(absolutePath);
        final exists = await file.exists(); // 检查文件是否存在

        if (exists) {
          setState(() {
            _backgroundPath = absolutePath;
            _isLoadingBackground = false;
          });
          debugPrint('背景图片加载成功: $_backgroundPath');
        } else {
          debugPrint('背景图片文件不存在: $absolutePath');
          setState(() {
            _backgroundPath = null;
            _isLoadingBackground = false;
          });
        }
      }
    } catch (e) {
      debugPrint('加载背景图片路径出错: $e');
      if (mounted) {
        setState(() {
          _backgroundPath = null;
          _isLoadingBackground = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用已加载的背景路径构建UI（通用壳负责背景图层与 SuperCupertino 导航壳）
    return ChatScreenScaffold(
      title: Text(widget.channel.title),
      largeTitle: widget.channel.title,
      backgroundPath: _backgroundPath,
      isLoadingBackground: _isLoadingBackground,
      enableSearchBar: true,
      searchPlaceholder: '搜索消息内容、发送人...',
      onSearchChanged: _handleSearchChanged,
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(),
      onMultiFilterChanged: _handleFilterChanged,
      actions: _buildActions(),
      body: _buildListenableContent(),
    );
  }

  /// 构建监听 controller 的消息主体内容
  Widget _buildListenableContent() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // 获取显示的消息（根据是否有搜索/过滤来决定）
        final displayMessages =
            _searchQuery.isNotEmpty || _filterState.hasAnyFilter
            ? _filteredMessages
            : _controller.messages;

        return FutureBuilder<List<dynamic>>(
          future: MessageListBuilder.buildMessageListWithDateSeparators(
            displayMessages,
            _controller.selectedDate,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _lastMessageItems = snapshot.data;
            }
            // 新 Future 未完成时沿用上次数据，防止列表清空导致气泡 State 重建
            final messageItems = snapshot.data ?? _lastMessageItems ?? [];
            final messageIndexMap = <String, int>{};
            for (var i = 0; i < displayMessages.length; i++) {
              messageIndexMap[displayMessages[i].id] = i;
            }

            return _buildChatBody(
              messageItems,
              messageIndexMap,
              displayMessages,
              _backgroundPath,
            );
          },
        );
      },
    );
  }

  /// 构建 Actions 按钮
  List<Widget> _buildActions() {
    final ds = AppTheme.of(context);
    if (_controller.isMultiSelectMode) {
      return [
        DSIconButton(
          icon: DsIconKind.copy,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: ds.textSub,
          onPressed: _copySelectedMessages,
          tooltip: '复制选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.trash,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: ds.danger,
          onPressed: _deleteSelectedMessages,
          tooltip: '删除选中消息',
        ),
        DSIconButton(
          icon: DsIconKind.close,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: ds.textSub,
          onPressed: _controller.toggleMultiSelectMode,
          tooltip: '退出多选模式',
        ),
      ];
    }

    return [
      DSMenu(
        align: DSMenuAlign.end,
        items: [
          DSMenuItem(
            icon: DsIconKind.list,
            label: 'chat_multiSelectMode'.tr,
            onTap: _controller.toggleMultiSelectMode,
          ),
          DSMenuItem(
            icon: DsIconKind.bot,
            label: 'chat_autoReplySettings'.tr,
            onTap: _openAutoReplySettings,
          ),
          DSMenuItem(
            icon: DsIconKind.trash,
            danger: true,
            label: 'chat_clearMessages'.tr,
            onTap: _showClearConfirmationDialog,
          ),
        ],
        child: DSIconButton(
          icon: DsIconKind.more,
          size: 36,
          color: ds.surfaceAlt,
          iconColor: ds.textSub,
          tooltip: '更多操作',
        ),
      ),
    ];
  }

  /// 当前频道的自动回复配置（含 enabled/agent/contextCount/currentOnly）
  Map<String, dynamic> get _autoReplyConfig {
    final live = ChatPlugin.instance.channelService.channels.firstWhere(
      (c) => c.id == widget.channel.id,
      orElse: () => widget.channel,
    );
    return readAutoReplyConfig(live);
  }

  /// 打开自动回复设置弹层（与输入框智能体入口共用）
  Future<void> _openAutoReplySettings() async {
    await showAutoReplySettingsSheet(
      context: context,
      channelId: widget.channel.id,
    );
    if (mounted) setState(() {});
  }

  /// 构建聊天主体内容
  Widget _buildChatBody(
    List<dynamic> messageItems,
    Map<String, int> messageIndexMap,
    List<Message> displayMessages,
    String? backgroundPath,
  ) {
    return Column(
      children: [
        if (_replyToMessage != null)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withAlpha(51),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '回复 ${_replyToMessage!.user.username}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _replyToMessage!.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearReply,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: MessageList(
            items: messageItems,
            isMultiSelectMode: _controller.isMultiSelectMode,
            selectedMessageIds: _controller.selectedMessageIds,
            onMessageEdit: _showEditDialog,
            onMessageDelete: _controller.deleteMessage,
            onMessageCopy: (message) => _messageOperations.copyMessage(message),
            onSetFixedSymbol: (message, symbol) =>
                _messageOperations.setFixedSymbol(message, symbol),
            onSetBubbleColor: (message, color) =>
                _messageOperations.setBubbleColor(message, color),
            onReply: _handleReply,
            onToggleFavorite: _handleToggleFavorite,
            onToggleMessageSelection: _controller.toggleMessageSelection,
            onReplyTap: _handleReplyTap,
            scrollController: _controller.scrollController,
            currentUserId: ChatPlugin.instance.userService.currentUser.id,
            highlightedMessage: widget.highlightMessage,
            shouldHighlight: widget.highlightMessage != null,
            messageIndexMap: messageIndexMap,
            onAvatarTap: (message) async {
              // 检查是否为AI消息
              final metadata = message.metadata;
              if (metadata != null &&
                  metadata.containsKey('isAI') &&
                  metadata['isAI'] == true &&
                  metadata.containsKey('agentId')) {
                final agentId = metadata['agentId'] as String;

                if (mounted) {
                  try {
                    // 获取OpenAI插件并转换类型
                    final openaiPlugin =
                        PluginManager.instance.getPlugin('openai')
                            as OpenAIPlugin;
                    // 获取agent
                    final agent = await openaiPlugin.controller.getAgent(
                      agentId,
                    );
                    if (agent != null) {
                      NavigationHelper.push(
                        context,
                        AgentEditScreen(agent: agent),
                      );
                    } else {
                      Toast.error('chat_aiAssistantNotFound'.tr);
                    }
                  } catch (e) {
                    // 插件不可用或类型转换失败时显示提示
                    Toast.error('无法访问AI编辑界面，OpenAI插件可能未加载');
                  }
                }
              } else {
                // 如果不是AI消息，显示用户资料编辑对话框
                // （保存由对话框内部完成，统一写入个人主页数据源）
                final chatPlugin = ChatPlugin.instance;
                final users = chatPlugin.userService.getAllUsers();
                final targetUser = users.firstWhere(
                  (user) => user.id == message.user.id,
                  orElse: () => message.user,
                );

                await showDSDialog<User>(
                  context: context,
                  theme: DSThemeBridge.resolve(context),
                  builder: (context) => ProfileEditDialog(
                    user: targetUser,
                    chatPlugin: chatPlugin,
                  ),
                );
              }
            },
            showAvatar: ChatPlugin.instance.settingsService.showAvatarInChat,
          ),
        ),
        // 已封存频道禁止发送消息，用提示条替换输入框
        _isChannelArchived() ? _buildArchivedBanner() : MessageInput(
              controller: _controller.draftController,
              onSendMessage:
                  (content, {metadata, String type = 'text', replyTo}) async {
                // 频道开启自动回复时，把配置的 agent 并入消息元数据，
                // openai 插件据此以「评论线程」形式自动回复（不进频道消息列表）
                Map<String, dynamic>? effectiveMetadata = metadata;
                final autoCfg = _autoReplyConfig;
                final autoAgent =
                    autoCfg['enabled'] == true ? autoReplyAgentOf(autoCfg) : null;
                if (autoAgent != null) {
                  effectiveMetadata = {...?metadata};
                  final agents = List<Map<String, dynamic>>.from(
                    (effectiveMetadata['agents'] as List<dynamic>? ?? [])
                        .map((a) => Map<String, dynamic>.from(a as Map)),
                  );
                  if (!agents.any((a) => a['id'] == autoAgent['id'])) {
                    agents.add(Map<String, dynamic>.from(autoAgent));
                  }
                  effectiveMetadata['agents'] = agents;
                  effectiveMetadata['autoReply'] = true;
                  effectiveMetadata['autoReplyAgent'] = Map<String, dynamic>.from(
                    autoAgent,
                  );
                  // 自动评论的上下文：currentOnly 开 = 0（仅当前句），否则取配置长度
                  final currentOnly = autoCfg['currentOnly'] != false;
                  effectiveMetadata['autoReplyContextCount'] = currentOnly
                      ? 0
                      : (autoCfg['contextCount'] as num?)?.toInt() ?? 0;
                }
                final sent = await _controller.sendMessage(
                  content,
                  metadata: effectiveMetadata,
                  type: type,
                  replyTo: _replyToMessage,
                );
                // 广播真实存入频道的消息实例（触发 AI/积分/小组件等订阅方）
                if (sent != null) {
                  eventManager.broadcast(
                    'chat_message_sent',
                    aboutme_event.Value<Message>(sent),
                  );
                }
                // 发送后清除回复状态
                if (_replyToMessage != null) {
                  setState(() {
                    _replyToMessage = null;
                  });
                }
              },
              onSaveDraft: _controller.saveDraft,
              replyTo: _replyToMessage,
              focusNode: _controller.focusNode,
            ),
      ],
    );
  }

  /// 频道是否处于封存状态（取服务端最新数据，widget.channel 可能是旧快照）
  bool _isChannelArchived() {
    final liveChannel = ChatPlugin.instance.channelService.channels.firstWhere(
      (c) => c.id == widget.channel.id,
      orElse: () => widget.channel,
    );
    return liveChannel.isArchived;
  }

  /// 已封存频道的底部提示条
  Widget _buildArchivedBanner() {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'chat_archivedNoSend'.tr,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
