import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'agent_chat_tool_form.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 工具列表项组件
class ToolListItem extends StatelessWidget {
  final String pluginId;
  final String toolId;
  final ToolConfig config;
  final VoidCallback onRefresh;
  final Function(String pluginId, String toolId, ToolConfig config)?
  onAddToChat;

  const ToolListItem({
    super.key,
    required this.pluginId,
    required this.toolId,
    required this.config,
    required this.onRefresh,
    this.onAddToChat,
  });

  /// 切换启用状态
  Future<void> _toggleEnabled(BuildContext context, bool enabled) async {
    try {
      await ToolConfigManager.instance.toggleToolEnabled(
        pluginId,
        toolId,
        enabled,
      );
      onRefresh();
    } catch (e) {
      toastService.showToast('切换状态失败: $e');
    }
  }

  /// 编辑工具
  Future<void> _editTool(BuildContext context) async {
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => AgentChatToolForm(
                    pluginId: pluginId,
                    toolId: toolId,
                    config: config,
                    isNew: false,
                  ),
            ),
          ),
    );

    if (result != null) {
      try {
        final updatedConfig = result['config'] as ToolConfig;
        await ToolConfigManager.instance.updateTool(
          pluginId,
          toolId,
          updatedConfig,
        );

        toastService.showToast('工具更新成功');
        onRefresh();
      } catch (e) {
        toastService.showToast('更新工具失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Dismissible(
      key: Key('${pluginId}_$toolId'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // 弹出确认对话框
        return await showDSDialog<bool>(
          context: context,
          theme: DSThemeBridge.resolve(context),
          builder:
              (dialogContext) => DSThemeBridge(
                child: Builder(
                  builder:
                      (ctx) => DSDialog(
                        title: 'agent_chat_confirmDelete'.tr,
                        message: 'agent_chat_confirmDeleteTool'.trParams({
                          'toolId': toolId,
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
      },
      onDismissed: (direction) async {
        try {
          await ToolConfigManager.instance.deleteTool(pluginId, toolId);
          toastService.showToast('工具已删除');
          onRefresh();
        } catch (e) {
          toastService.showToast('删除工具失败: $e');
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.danger,
        child: DsIcon(DsIconKind.trash, color: theme.onDanger, size: 32),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: theme.radii.md,
          border: Border.all(color: theme.textSub.withValues(alpha: 0.25)),
        ),
        child: Pressable(
          onPressed: () => _editTool(context),
          semanticLabel: toolId,
          builder:
              (context, states) => Row(
                children: [
                  DsIcon(
                    config.enabled ? DsIconKind.check : DsIconKind.close,
                    size: 24,
                    color: config.enabled ? theme.success : theme.textSub,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toolId,
                          style: DsTypography.body.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration:
                                config.enabled
                                    ? null
                                    : TextDecoration.lineThrough,
                            color: config.enabled ? theme.text : theme.textSub,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.title,
                          style: DsTypography.body.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.getBriefDescription(),
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            DsIcon(
                              DsIconKind.hash,
                              size: 14,
                              color: theme.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${config.parameters.length} 个参数',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                            const SizedBox(width: 12),
                            DsIcon(
                              DsIconKind.copy,
                              size: 14,
                              color: theme.textSub,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${config.examples.length} 个示例',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAddToChat != null)
                        Pressable(
                          onPressed:
                              () => onAddToChat!(pluginId, toolId, config),
                          semanticLabel: '添加到聊天',
                          builder:
                              (context, states) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: DsIcon(
                                  DsIconKind.chat,
                                  size: 20,
                                  color: theme.primaryText,
                                ),
                              ),
                        ),
                      // 共享 DSSwitch 保持不变
                      DSSwitch(
                        value: config.enabled,
                        onChanged: (value) => _toggleEnabled(context, value),
                      ),
                    ],
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
