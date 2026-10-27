import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/widgets/common/persona_intro_dialog.dart';
import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/moments/screens/moments_profile_screen.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';

/// 角色卡详情弹窗（基于人设介绍卡片展示）
class AgentDetailDialog {
  /// 展示角色卡详情
  ///
  /// [onEdit] 为「编辑」入口（null 时默认跳转编辑页），
  /// [onChat] 为「开始聊天」入口（null 时默认在 agent_chat 创建新会话并进入）
  static Future<void> show(
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

    final avatarUrl = agent.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return showPersonaIntroDialog(
      context: context,
      badgeText: '角色卡',
      portrait:
          hasAvatar
              ? AdaptiveImage(
                imagePath: avatarUrl,
                width: double.infinity,
                height: double.infinity,
              )
              // 无头像的 agent：人像区中央放大显示图标
              : Center(child: AgentDetailDialog.buildAgentIcon(agent, size: 96)),
      title: agent.name,
      subtitle: agent.description.isNotEmpty ? agent.description : null,
      content: _AgentDetailContent(agent: agent),
      buttons: [
        // 开启活人感的 agent 提供朋友圈入口
        if (agent.alivenessConfig?.enabled == true)
          PersonaIntroButton(
            label: 'moments_viewMoments'.tr,
            icon: Icons.photo_camera_outlined,
            onPressed: () {
              Navigator.of(context).pop();
              NavigationHelper.push(
                context,
                MomentsProfileScreen(agentId: agent.id),
              );
            },
          ),
        PersonaIntroButton(
          label: '编辑',
          onPressed: () {
            Navigator.of(context).pop();
            edit();
          },
        ),
        PersonaIntroButton(
          label: '开始聊天',
          primary: true,
          onPressed: () {
            Navigator.of(context).pop();
            chat();
          },
        ),
      ],
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

/// 角色卡详情内容（人设卡片标题下方区域，白底固定配色）
class _AgentDetailContent extends StatelessWidget {
  final AIAgent agent;

  const _AgentDetailContent({required this.agent});

  @override
  Widget build(BuildContext context) {
    const labelText = TextStyle(fontSize: 12, color: Color(0xFF8C8C8C));
    const valueText = TextStyle(fontSize: 13, color: Color(0xFF141414));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (agent.tags.isNotEmpty)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children:
                agent.tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C8C8C),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        SizedBox(height: agent.tags.isEmpty ? 0 : 12),
        _buildInfoRow('服务商', agent.serviceProviderId, labelText, valueText),
        const SizedBox(height: 6),
        _buildInfoRow('模型', agent.model, labelText, valueText),
        if (agent.effectiveSystemPrompt.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('角色设定', style: labelText),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              agent.effectiveSystemPrompt,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF595959),
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value,
    TextStyle labelText,
    TextStyle valueText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text(label, style: labelText)),
        if (value != null)
          Expanded(child: Text(value, style: valueText)),
      ],
    );
  }
}
