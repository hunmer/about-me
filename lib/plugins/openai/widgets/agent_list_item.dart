import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/soul_forge_service.dart';
import 'package:aboutme/widgets/swipe_action/swipe_action_wrapper.dart';
import 'package:aboutme/widgets/adaptive_image.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

class AgentListItem extends StatelessWidget {
  final AIAgent agent;

  const AgentListItem({super.key, required this.agent});

  /// 编辑 Agent
  void _editAgent(BuildContext context) {
    NavigationHelper.push(context, AgentEditScreen(agent: agent));
  }

  /// 展示角色卡详情弹窗
  void _showAgentDetail(BuildContext context) {
    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSDialog(
            title: '角色卡',
            content: _AgentDetailContent(agent: agent),
            confirmText: '编辑',
            onConfirm: () {
              Navigator.of(dialogContext).pop();
              _editAgent(context);
            },
            cancelText: '关闭',
          ),
    );
  }

  /// 删除 Agent
  Future<void> _deleteAgent(BuildContext context) async {
    final controller = OpenAIPlugin.instance.controller;
    await controller.deleteAgent(agent.id);
    Toast.success('${agent.name} 已被删除');
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SwipeActionWrapper(
      key: ValueKey(agent.id),
      leadingActions: [
        SwipeActionPresets.edit(onTap: () => _editAgent(context)),
      ],
      trailingActions: [
        // 内置 agent 不可删除
        if (!SoulForgeService.isBuiltinAgent(agent.id))
          SwipeActionPresets.delete(onTap: () => _deleteAgent(context)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: DSCard(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm,
          ),
          onTap: () => _showAgentDetail(context),
          child: Row(
            children: [
              _buildAgentIcon(agent),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agent.name,
                      style: DsTypography.body.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '服务商: ${agent.serviceProviderId}',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTags(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAgentIcon(AIAgent agent, {double size = 40}) {
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

  Widget _buildTags(AppThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children:
          agent.tags.take(3).map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            );
          }).toList(),
    );
  }
}

/// 角色卡详情内容（弹窗内展示）
class _AgentDetailContent extends StatelessWidget {
  final AIAgent agent;

  const _AgentDetailContent({required this.agent});

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgentListItem._buildAgentIcon(agent, size: 56),
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
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            ],
          ],
        ),
      ),
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
