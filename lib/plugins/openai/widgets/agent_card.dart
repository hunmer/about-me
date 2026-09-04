import 'package:flutter/material.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/screens/agent_edit_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';
import 'package:aboutme/widgets/common/agent_card.dart';

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

  /// 显示操作菜单
  void _showActionMenu(BuildContext context) {
    SmoothBottomSheet.show(
      context: context,
      backgroundColor: DSThemeBridge.resolve(context).surface,
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AgentSheetActionRow(
                      icon: DsIcon(
                        DsIconKind.edit,
                        size: 20,
                        color: theme.primary,
                      ),
                      label: '编辑',
                      theme: theme,
                      onTap: () {
                        Navigator.pop(context);
                        _editAgent();
                      },
                    ),
                    _AgentSheetActionRow(
                      icon: DsIcon(
                        DsIconKind.trash,
                        size: 20,
                        color: theme.danger,
                      ),
                      label: '删除',
                      theme: theme,
                      danger: true,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteAgent();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
    );
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
      onTap: () => _editAgent(),
      onLongPress: () => _showActionMenu(context),
    );
  }
}

/// Agent 卡片长按菜单行(果冻风格)
class _AgentSheetActionRow extends StatelessWidget {
  const _AgentSheetActionRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.md,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: danger ? theme.danger : theme.text,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
