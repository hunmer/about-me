import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/controllers/conversation_controller.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';

/// 建议问题测试产生的会话列表（独立于主会话列表）
class TestConversationListScreen extends StatefulWidget {
  const TestConversationListScreen({super.key});

  @override
  State<TestConversationListScreen> createState() =>
      _TestConversationListScreenState();
}

class _TestConversationListScreenState
    extends State<TestConversationListScreen> {
  late ConversationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AgentChatPlugin.instance.conversationController!;
    // 延迟添加监听器，避免在build期间触发setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.addListener(_onControllerChanged);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _controller.testConversations;

    return SuperCupertinoNavigationWrapper(
      title: const Text('测试会话'),
      largeTitle: '测试会话',
      enableLargeTitle: true,
      body:
          conversations.isEmpty
              ? const Center(
                child: DSEmptyState(
                  icon: DsIconKind.science,
                  title: '暂无测试会话',
                  message: '在助手页运行建议问题测试后，会话会保存到这里',
                ),
              )
              : HandDrawnListView(
                padding: EdgeInsets.zero,
                itemCount: conversations.length,
                tiltKeyOf: (index) => conversations[index].id,
                // 原项间仅 8px，不足以容纳贴条出血，调到 16（与主列表一致）
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return WiredDraw(child: _buildConversationCard(conversation));
                },
              ),
    );
  }

  /// 会话卡片
  Widget _buildConversationCard(Conversation conversation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SwipeActionWrapper(
        key: ValueKey(conversation.id),
        trailingActions: [
          SwipeActionPresets.delete(
            onTap: () => _showDeleteConfirmDialog(conversation),
          ),
        ],
        child: DSListItemCard(
          title: conversation.title,
          icon: DsIconKind.science,
          subtitle: conversation.lastMessagePreview,
          trailingText: _formatDateTime(conversation.lastMessageAt),
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

  /// 格式化时间（与主会话列表保持一致）
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
                    title: '删除测试会话',
                    message: '确定删除「${conversation.title}」吗？',
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
