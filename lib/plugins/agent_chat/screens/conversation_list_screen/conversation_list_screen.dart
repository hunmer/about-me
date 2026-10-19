import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/conversation_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/agent_chat_settings_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_management_screen/tool_management_screen.dart';
import 'package:aboutme/plugins/agent_chat/screens/tool_template_screen/tool_template_screen.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';

/// 会话列表屏幕
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late ConversationController _controller;
  late ToolTemplateService _templateService;

  /// 缓存的会话数量，用于检测实际变化
  int _cachedConversationCount = 0;

  /// 缓存的会话ID列表哈希，用于快速检测变化
  int _cachedConversationHash = 0;

  @override
  void initState() {
    super.initState();
    // 通过插件实例获取controller
    _controller = AgentChatPlugin.instance.conversationController!;

    // 初始化工具模板服务
    _templateService = ToolTemplateService(_controller.storage);

    // 延迟添加监听器，避免在build期间触发setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.addListener(_onControllerChanged);

        // 初始化会话缓存，避免首次触发不必要的重建
        final initialConversations = _controller.conversations;
        _cachedConversationCount = initialConversations.length;
        _cachedConversationHash = _computeConversationHash(
          initialConversations,
        );

        // 触发一次更新以确保显示最新状态
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[ConversationListScreen] dispose 开始');
    _controller.removeListener(_onControllerChanged);
    super.dispose();
    debugPrint('[ConversationListScreen] dispose 完成');
  }

  void _onControllerChanged() {
    if (mounted) {
      // 检查会话列表是否有实际变化，避免不必要的重建导致闪烁
      final conversations = _controller.conversations;
      final newCount = conversations.length;
      final newHash = _computeConversationHash(conversations);

      // 仅当会话列表发生实际变化时才触发重建
      final hasChanges =
          newCount != _cachedConversationCount ||
          newHash != _cachedConversationHash;

      if (hasChanges) {
        _cachedConversationCount = newCount;
        _cachedConversationHash = newHash;

        // 使用 addPostFrameCallback 避免在构建过程中调用 setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  /// 计算会话列表的哈希值，用于快速检测变化
  int _computeConversationHash(List<Conversation> conversations) {
    if (conversations.isEmpty) return 0;
    // 基于会话ID、最后消息时间、置顶状态等计算哈希
    int hash = 0;
    for (final conv in conversations) {
      hash =
          hash ^
          conv.id.hashCode ^
          conv.lastMessageAt.hashCode ^
          conv.isPinned.hashCode;
      if (conv.lastMessagePreview != null) {
        hash = hash ^ conv.lastMessagePreview.hashCode;
      }
    }
    return hash;
  }

  /// 打开设置页面
  void _openSettings() {
    NavigationHelper.push(
      context,
      AgentChatSettingsScreen(plugin: AgentChatPlugin.instance),
    );
  }

  /// 打开工具管理页面
  void _openToolManagement() {
    NavigationHelper.push(context, const ToolManagementScreen());
  }

  /// 打开工具模板页面
  void _openToolTemplate() {
    NavigationHelper.push(
      context,
      ToolTemplateScreen(templateService: _templateService),
    );
  }

  /// 构建分组过滤的 FilterItem
  List<FilterItem> _buildGroupFilterItems() {
    // 从所有会话（未过滤）的groups字段中提取唯一的分组名称
    final allGroupNames = <String>{};
    for (final conv in _controller.allConversations) {
      allGroupNames.addAll(conv.groups);
    }
    final groups = allGroupNames.toList()..sort();

    // 如果没有分组，返回空列表
    if (groups.isEmpty) {
      return [];
    }

    return [
      FilterItem(
        id: 'groups',
        title: '分组',
        type: FilterType.tagsMultiple,
        builder: (context, currentValue, onChanged) {
          final selectedGroups = currentValue as List<String>? ?? [];

          // 第三方过滤面板回调内构建 DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                return Row(
                  children: [
                    // "全部"按钮
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Center(
                        child: DSChip(
                          label: '全部',
                          selected: selectedGroups.isEmpty,
                          onSelected: (selected) {
                            if (selected || selectedGroups.isNotEmpty) {
                              onChanged(<String>[]);
                            }
                          },
                        ),
                      ),
                    ),
                    // 分组按钮
                    ...groups.map((groupName) {
                      final isSelected = selectedGroups.contains(groupName);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: DSChip(
                            label: groupName,
                            selected: isSelected,
                            onSelected: (selected) {
                              final newGroups = List<String>.from(
                                selectedGroups,
                              );
                              if (selected) {
                                newGroups.add(groupName);
                              } else {
                                newGroups.remove(groupName);
                              }
                              onChanged(newGroups);
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          );
        },
        getBadge: (value) {
          final selectedGroups = value as List<String>? ?? [];
          return selectedGroups.isEmpty ? null : '${selectedGroups.length}';
        },
        initialValue: <String>[],
      ),
    ];
  }

  /// 显示添加频道底部弹层（smooth_sheets）
  Future<void> _showAddChannelDialog() async {
    final nameController = TextEditingController();

    try {
      final result = await SmoothBottomSheet.showForm<bool>(
        context: context,
        title: 'agent_chat_addChannel'.tr,
        child: Builder(
          builder: (ctx) {
            final theme = DSThemeBridge.resolve(ctx);
            return Padding(
              padding: EdgeInsets.all(theme.spacing.xl),
              child: DSInput(
                controller: nameController,
                label: '频道名称',
                hint: '请输入频道名称',
                textInputAction: TextInputAction.done,
              ),
            );
          },
        ),
        onSave: () => Navigator.pop(context, true),
      );

      if (result == true && nameController.text.isNotEmpty) {
        try {
          await _controller.createConversation(title: nameController.text);

          if (mounted) {
            ToastService.instance.showToast('频道已创建');
          }
        } catch (e) {
          if (mounted) {
            ToastService.instance.showToast('创建频道失败: $e');
          }
          debugPrint('创建频道失败: $e');
        }
      }
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyConversations =
        _controller.conversationService.conversations.isNotEmpty;

    return SuperCupertinoNavigationWrapper(
      title: Text('agent_chat_aiChat'.tr),
      largeTitle: 'agent_chat_aiChat'.tr,
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'agent_chat_searchPlaceholder'.tr,
      onSearchChanged: (query) {
        _controller.setSearchQuery(query);
      },
      onSearchSubmitted: (query) {
        _controller.setSearchQuery(query);
      },
      // 第三方导航栏 actions 回调内构建 DS 组件需包 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 添加按钮
                  DSIconButton(
                    icon: DsIconKind.plus,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _showAddChannelDialog,
                    tooltip: '添加频道',
                  ),
                  // 工具管理按钮
                  DSIconButton(
                    icon: DsIconKind.gear,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _openToolManagement,
                    tooltip: '工具管理',
                  ),
                  // 工具模板按钮
                  DSIconButton(
                    icon: DsIconKind.clipboard,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _openToolTemplate,
                    tooltip: '工具模板',
                  ),
                  // 设置按钮
                  DSIconButton(
                    icon: DsIconKind.gear,
                    size: 40,
                    onPressed: _openSettings,
                    tooltip: '设置',
                  ),
                ],
              );
            },
          ),
        ),
      ],
      // 多条件过滤配置
      enableMultiFilter: true,
      multiFilterItems: _buildGroupFilterItems(),
      onMultiFilterChanged: (filters) {
        final selectedGroups = filters['groups'] as List<String>? ?? [];
        // 清空现有过滤
        _controller.clearGroupFilters();
        // 应用新的过滤
        for (final group in selectedGroups) {
          _controller.toggleGroupFilter(group);
        }
      },
      body:
          _controller.isLoading
              ? const Center(child: DSThemeBridge(child: DSLoadingDots()))
              : hasAnyConversations
              ? _buildConversationList()
              : _buildEmptyState(),
    );
  }

  /// 空状态视图
  Widget _buildEmptyState() {
    return Center(
      child: DSEmptyState(
        icon: DsIconKind.chat,
        title: '还没有任何会话',
        message: '创建一个频道，开始和 AI 聊天吧',
        actionLabel: '新建会话',
        onAction: _showAddChannelDialog,
      ),
    );
  }

  /// 会话列表
  Widget _buildConversationList() {
    final conversations = _controller.conversations;

    return _conversationListTransition(
      isEmpty: conversations.isEmpty,
      emptyWidget: _buildEmptyListState(key: const ValueKey('empty')),
      listWidget: HandDrawnListView(
        key: ValueKey('conversation_list_${conversations.length}'),
        padding: EdgeInsets.zero,
        itemCount: conversations.length,
        tiltKeyOf: (index) => conversations[index].id,
        // 原项间仅 8px，不足以容纳贴条出血，调到 16
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          // 挂载即播墨线描画入场（design.md §10）
          return WiredDraw(child: _buildConversationCard(conversation));
        },
      ),
    );
  }

  /// 会话列表过渡动画组件
  Widget _conversationListTransition({
    required bool isEmpty,
    required Widget emptyWidget,
    required Widget listWidget,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isEmpty ? emptyWidget : listWidget,
    );
  }

  /// 空列表状态
  Widget _buildEmptyListState({Key? key}) {
    return Center(
      key: key,
      child: const DSEmptyState(
        icon: DsIconKind.chat,
        title: '没有匹配的会话',
        message: '尝试调整搜索条件或分组过滤器',
      ),
    );
  }

  /// 会话卡片
  Widget _buildConversationCard(Conversation conversation) {
    final theme = DSThemeBridge.resolve(context);
    return Padding(
      // 垂直间距交给 separatorBuilder(贴条出血需 ≥16)
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SwipeActionWrapper(
        key: ValueKey(conversation.id),
        leadingActions: [
          SwipeActionPresets.edit(
            onTap: () => _showEditConversationDialog(conversation),
          ),
          // 共享 SwipeAction 组件 API 需要 IconData，刻意保留 Material 图标
          SwipeActionOption(
            label: conversation.isPinned ? '取消置顶' : '置顶',
            icon:
                conversation.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
            backgroundColor: Colors.purple,
            onTap: () => _controller.togglePin(conversation.id),
          ),
        ],
        trailingActions: [
          SwipeActionPresets.delete(
            onTap: () => _showDeleteConfirmDialog(conversation),
          ),
        ],
        child: DSListItemCard(
          title: conversation.title,
          icon: conversation.isPinned ? DsIconKind.pin : DsIconKind.chat,
          subtitle: conversation.lastMessagePreview,
          trailingText: _formatDateTime(conversation.lastMessageAt),
          trailing:
              conversation.unreadCount > 0
                  ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.danger,
                      borderRadius: theme.radii.pill,
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: DsTypography.caption.copyWith(
                        color: theme.onDanger,
                      ),
                    ),
                  )
                  : null,
          onTap: () {
            NavigationHelper.openContainerWithHero(
              context,
              (context) => ChatScreen(
                conversation: conversation,
                storage: _controller.storage,
                conversationService: _controller.conversationService,
                getSettings: () => AgentChatPlugin.instance.settings,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 格式化时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  /// 显示编辑会话对话框
  Future<void> _showEditConversationDialog(Conversation conversation) async {
    final titleController = TextEditingController(text: conversation.title);
    final groupsController = TextEditingController(
      text: conversation.groups.join(', '),
    );

    try {
      final result = await showDSDialog<bool>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder:
            (dialogContext) => DSThemeBridge(
              child: Builder(
                builder: (ctx) {
                  final theme = DSThemeBridge.resolve(ctx);
                  return JellyBox(
                    radius: theme.radii.xxl,
                    padding: EdgeInsets.all(theme.spacing.xl),
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'agent_chat_editConversation'.tr,
                          textAlign: TextAlign.center,
                          style: DsTypography.title.copyWith(color: theme.text),
                        ),
                        SizedBox(height: theme.spacing.md),
                        DSInput(controller: titleController, label: '会话标题'),
                        SizedBox(height: theme.spacing.md),
                        DSInput(
                          controller: groupsController,
                          label: '分组',
                          hint: '用逗号分隔多个分组，例如：工作, 生活',
                        ),
                        SizedBox(height: theme.spacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: DSButton(
                                label: 'agent_chat_cancel'.tr,
                                variant: DSButtonVariant.outline,
                                onPressed:
                                    () => Navigator.pop(dialogContext, false),
                              ),
                            ),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: DSButton(
                                label: 'agent_chat_save'.tr,
                                onPressed:
                                    () => Navigator.pop(dialogContext, true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      );

      if (result == true && titleController.text.isNotEmpty) {
        // 解析分组字符串
        final groupsText = groupsController.text.trim();
        final groups =
            groupsText.isEmpty
                ? <String>[]
                : groupsText
                    .split(',')
                    .map((g) => g.trim())
                    .where((g) => g.isNotEmpty)
                    .toList();

        final updated = conversation.copyWith(
          title: titleController.text,
          groups: groups,
        );
        await _controller.updateConversation(updated);

        if (mounted) {
          ToastService.instance.showToast('会话已更新');
        }
      }
    } finally {
      // 确保无论如何都会 dispose controller
      titleController.dispose();
      groupsController.dispose();
    }
  }

  /// 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(Conversation conversation) async {
    final result = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'agent_chat_confirmDelete'.tr,
                    message: 'agent_chat_confirmDeleteConversation'.trParams({
                      'title': conversation.title,
                    }),
                    cancelText: 'agent_chat_cancel'.tr,
                    confirmText: 'agent_chat_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.pop(dialogContext, true),
                    onCancel: () => Navigator.pop(dialogContext, false),
                  ),
            ),
          ),
    );

    if (result == true) {
      await _controller.deleteConversation(conversation.id);

      if (mounted) {
        ToastService.instance.showToast('会话已删除');
      }
    }
  }
}
