import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'tool_list_item.dart';

/// 插件分组展示组件
class PluginSection extends StatefulWidget {
  final String pluginId;
  final PluginToolSet toolSet;
  final List<String> visibleToolIds;
  final VoidCallback onRefresh;
  final Function(String pluginId, String toolId, ToolConfig config)?
  onAddToChat;

  const PluginSection({
    super.key,
    required this.pluginId,
    required this.toolSet,
    required this.visibleToolIds,
    required this.onRefresh,
    this.onAddToChat,
  });

  @override
  State<PluginSection> createState() => _PluginSectionState();
}

class _PluginSectionState extends State<PluginSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final enabledCount = widget.toolSet.enabledToolCount;
    final totalCount = widget.visibleToolIds.length;

    if (totalCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.textSub.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // 插件标题栏
          Pressable(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            semanticLabel: widget.pluginId,
            builder:
                (context, states) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      DsIcon(
                        _isExpanded ? DsIconKind.book : DsIconKind.clipboard,
                        size: 24,
                        color: theme.primaryText,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.pluginId,
                              style: DsTypography.heading.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.text,
                              ),
                            ),
                            Text(
                              '$enabledCount / $totalCount 个工具已启用',
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DsIcon(
                        _isExpanded
                            ? DsIconKind.chevronUp
                            : DsIconKind.chevronDown,
                        size: 22,
                        color: theme.textSub,
                      ),
                    ],
                  ),
                ),
          ),

          // 工具列表
          if (_isExpanded)
            ...widget.visibleToolIds.map((toolId) {
              final config = widget.toolSet.tools[toolId];
              if (config == null) return const SizedBox.shrink();

              return ToolListItem(
                pluginId: widget.pluginId,
                toolId: toolId,
                config: config,
                onRefresh: widget.onRefresh,
                onAddToChat: widget.onAddToChat,
              );
            }),
        ],
      ),
    );
  }
}
