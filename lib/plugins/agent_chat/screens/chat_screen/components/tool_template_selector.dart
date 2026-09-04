import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';

/// 工具模板选择器组件
///
/// 显示工具模板搜索结果，用于选择模板
class ToolTemplateSelector extends StatelessWidget {
  final List<SavedToolTemplate> templates;
  final Function(SavedToolTemplate) onTemplateSelected;
  final VoidCallback onCancel;

  const ToolTemplateSelector({
    super.key,
    required this.templates,
    required this.onTemplateSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
          bottom: BorderSide(color: theme.textSub.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                DsIcon(DsIconKind.search, size: 18, color: theme.primaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '找到 ${templates.length} 个匹配的工具模板',
                    style: DsTypography.caption.copyWith(
                      color: theme.textSub,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Pressable(
                  onPressed: onCancel,
                  semanticLabel: '取消',
                  builder:
                      (context, states) => SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: DsIcon(
                            DsIconKind.close,
                            size: 20,
                            color: theme.textSub,
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),

          // 模板列表
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    DsIcon(DsIconKind.search, size: 48, color: theme.textSub),
                    const SizedBox(height: 8),
                    Text(
                      '未找到匹配的工具模板',
                      style: DsTypography.body.copyWith(color: theme.textSub),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: templates.length > 5 ? 5 : templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return _buildTemplateItem(template);
              },
            ),

          // 查看更多
          if (templates.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '还有 ${templates.length - 5} 个结果，请使用更精确的关键词',
                style: DsTypography.caption.copyWith(
                  color: theme.textSub,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建模板项
  Widget _buildTemplateItem(SavedToolTemplate template) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Pressable(
          onPressed: () => onTemplateSelected(template),
          builder:
              (context, states) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // 图标
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.warning.mixWhite(0.9),
                        borderRadius: theme.radii.sm,
                      ),
                      child: DsIcon(
                        DsIconKind.gear,
                        size: 22,
                        color: theme.warning,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: DsTypography.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              DsIcon(
                                DsIconKind.clipboard,
                                size: 12,
                                color: theme.textSub,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${template.steps.length} 个步骤',
                                style: DsTypography.caption.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                              if (template.usageCount > 0) ...[
                                const SizedBox(width: 12),
                                DsIcon(
                                  DsIconKind.star,
                                  size: 12,
                                  color: theme.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '使用 ${template.usageCount} 次',
                                  style: DsTypography.caption.copyWith(
                                    color: theme.success,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (template.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              template.description!,
                              style: DsTypography.caption.copyWith(
                                color: theme.textSub,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 箭头
                    DsIcon(
                      DsIconKind.chevronRight,
                      size: 14,
                      color: theme.textSub.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }
}
