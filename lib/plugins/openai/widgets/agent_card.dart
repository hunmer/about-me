import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/plugins/openai/services/soul_forge_service.dart';
import 'package:aboutme/plugins/openai/services/chat_assistant_service.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/widgets/common/agent_card.dart';
import 'package:aboutme/plugins/openai/widgets/agent_detail_dialog.dart';

/// Agent 卡片组件
///
/// 使用声明式构建，通过 AgentCardWidget 渲染 UI
class AgentCard extends StatefulWidget {
  final AIAgent agent;

  const AgentCard({super.key, required this.agent});

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  final GlobalKey _cardKey = GlobalKey();

  AIAgent get agent => widget.agent;

  /// 长按快捷菜单项（圆盘与底部 sheet 共用；内置 agent 不可删除）
  List<ArcMenuItem> _agentActions() => [
        ArcMenuItem(
          icon: DsIconKind.edit,
          label: '编辑',
          onTap: _editAgent,
        ),
        if (!SoulForgeService.isBuiltinAgent(agent.id) &&
            !ChatAssistantService.isBuiltinAgent(agent.id))
          ArcMenuItem(
            icon: DsIconKind.trash,
            label: '删除',
            destructive: true,
            onTap: _deleteAgent,
          ),
      ];

  /// 显示操作菜单
  void _showActionMenu(BuildContext context) {
    SmoothBottomSheet.showActionList(
      context: context,
      actions: _agentActions(),
    );
  }

  /// 展示角色卡详情弹窗
  void _showAgentDetail() {
    AgentDetailDialog.show(context, agent, onEdit: _editAgent);
  }

  /// 编辑 Agent
  void _editAgent() {
    NavigationHelper.openContainerWithHero(
      context,
      (context) => AgentEditScreen(agent: agent),
      sourceKey: _cardKey,
      heroTag: 'agent_card_${agent.id}',
    );
  }

  /// 删除 Agent
  Future<void> _deleteAgent() async {
    final controller = OpenAIPlugin.instance.controller;
    await controller.deleteAgent(agent.id);
    Toast.success('${agent.name} 已被删除');
  }

  @override
  Widget build(BuildContext context) {
    // 使用声明式构建，通过 AgentCardWidget 渲染 UI
    return AgentCardWidget(
      key: _cardKey,
      name: agent.name,
      description: agent.description,
      serviceProviderId: agent.serviceProviderId,
      tags: agent.tags,
      avatarUrl: agent.avatarUrl,
      iconCodePoint: agent.icon?.codePoint,
      iconColorValue: agent.iconColor?.value,
      onTap: () => _showAgentDetail(),
      arcActions: _agentActions(),
      onMore: () => _showActionMenu(context),
    );
  }
}
