import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/moments/screens/moments_profile_screen.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';

/// 角色卡详情弹窗
class AgentDetailDialog {
  /// 展示角色卡详情
  ///
  /// [onEdit] 为「编辑」入口（null 时默认跳转编辑页），
  /// [onChat] 为「开始聊天」入口（null 时默认在 agent_chat 创建新会话并进入）
  static void show(
    BuildContext context,
    AIAgent agent, {
    VoidCallback? onEdit,
    VoidCallback? onChat,
  }) {
    void edit() {
      onEdit ??= () => NavigationHelper.push(
        context,
        AgentEditScreen(agent: agent),
      );
      onEdit!();
    }

    Future<void> chat() async {
      if (onChat != null) {
        onChat();
        return;
      }
      final controller = AgentChatPlugin.instance.conversationController;
      if (controller == null) {
        Toast.error('Agent Chat 尚未初始化');
        return;
      }
      final conversation = await controller.createConversation(
        title: agent.name,
        agentId: agent.id,
      );
      if (!context.mounted) return;
      await NavigationHelper.push(
        context,
        ChatScreen(
          conversation: conversation,
          storage: controller.storage,
          conversationService: controller.conversationService,
          getSettings: () => AgentChatPlugin.instance.settings,
        ),
      );
    }

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: '角色卡',
            content: _AgentDetailContent(
              agent: agent,
              onViewMoments: () {
                Navigator.of(dialogContext).pop();
                NavigationHelper.push(
                  context,
                  MomentsProfileScreen(agentId: agent.id),
                );
              },
            ),
            confirmText: '开始聊天',
            onConfirm: () {
              Navigator.of(dialogContext).pop();
              chat();
            },
            cancelText: '编辑',
            onCancel: () {
              Navigator.of(dialogContext).pop();
              edit();
            },
          ),
    );
  }

  /// Agent 头像/图标（列表项与弹窗共用）
  static Widget buildAgentIcon(AIAgent agent, {double size = 40}) {
    // 如果有头像，优先显示头像
    if (agent.avatarUrl != null && agent.avatarUrl!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getColorForServiceProvider(
                agent.serviceProviderId,
              ).withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: AdaptiveImage(
              imagePath: agent.avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // 如果有自定义图标，使用自定义图标(持久化 IconData,刻意保留 Material)
    if (agent.icon != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              agent.iconColor ??
              _getColorForServiceProvider(agent.serviceProviderId),
        ),
        child: Icon(agent.icon, size: size * 0.6, color: Colors.white),
      );
    }

    // 默认图标
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getColorForServiceProvider(agent.serviceProviderId),
      ),
      child: Icon(Icons.smart_toy, size: size * 0.6, color: Colors.white),
    );
  }

  static Color _getColorForServiceProvider(String providerId) {
    switch (providerId) {
      case 'openai':
        return Colors.green;
      case 'azure':
        return Colors.blue;
      case 'ollama':
        return Colors.orange;
      case 'deepseek':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

/// 角色卡详情内容（弹窗内展示）
class _AgentDetailContent extends StatelessWidget {
  final AIAgent agent;

  /// 「查看朋友圈」入口（仅开启活人感的 agent 显示）
  final VoidCallback? onViewMoments;

  const _AgentDetailContent({required this.agent, this.onViewMoments});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 详情信息区（可滚动；高度收紧给底部入口留出空间）
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AgentDetailDialog.buildAgentIcon(agent, size: 56),
                    SizedBox(width: theme.spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.name,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (agent.description.isNotEmpty)
                            Text(
                              agent.description,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (agent.tags.isNotEmpty) ...[
                  SizedBox(height: theme.spacing.sm),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        agent.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tag,
                                  style: DsTypography.label.copyWith(
                                    fontSize: 10,
                                    color: theme.textSub,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
                SizedBox(height: theme.spacing.md),
                _buildInfoRow(theme, '服务商', agent.serviceProviderId),
                SizedBox(height: theme.spacing.sm),
                _buildInfoRow(theme, '模型', agent.model),
                SizedBox(height: theme.spacing.sm),
                if (agent.effectiveSystemPrompt.isNotEmpty) ...[
                  _buildInfoRow(theme, '角色设定', null),
                  SizedBox(height: theme.spacing.xs),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(theme.spacing.sm),
                    decoration: BoxDecoration(
                      color: theme.surfaceAlt,
                      borderRadius: theme.radii.md,
                    ),
                    child: Text(
                      agent.effectiveSystemPrompt,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 开启活人感的 agent：底部占满宽度的朋友圈入口（钉在滚动区外，
        // 角色设定再长也始终可见）
        if (agent.alivenessConfig?.enabled == true &&
            onViewMoments != null) ...[
          SizedBox(height: theme.spacing.md),
          SizedBox(
            width: double.infinity,
            child: DSButton(
              label: 'moments_viewMoments'.tr,
              icon: DsIconKind.camera,
              expand: true,
              variant: DSButtonVariant.secondary,
              onPressed: onViewMoments,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(AppThemeData theme, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: DsTypography.label.copyWith(color: theme.textSub),
          ),
        ),
        if (value != null)
          Expanded(
            child: Text(
              value,
              style: DsTypography.caption.copyWith(color: theme.text),
            ),
          ),
      ],
    );
  }
}
