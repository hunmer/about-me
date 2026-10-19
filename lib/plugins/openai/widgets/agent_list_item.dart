import 'package:flutter/material.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/soul_forge_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/widgets/swipe_action/swipe_action_wrapper.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/plugins/openai/widgets/agent_detail_dialog.dart';

class AgentListItem extends StatelessWidget {
  final AIAgent agent;

  const AgentListItem({super.key, required this.agent});

  /// 编辑 Agent
  void _editAgent(BuildContext context) {
    NavigationHelper.push(context, AgentEditScreen(agent: agent));
  }

  /// 展示角色卡详情弹窗
  void _showAgentDetail(BuildContext context) {
    AgentDetailDialog.show(context, agent, onEdit: () => _editAgent(context));
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
        if (!SoulForgeService.isBuiltinAgent(agent.id) &&
                !ChatAssistantService.isBuiltinAgent(agent.id))
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
              AgentDetailDialog.buildAgentIcon(agent),
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
