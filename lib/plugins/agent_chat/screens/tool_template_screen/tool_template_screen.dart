import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/save_tool_dialog.dart';
import 'components/template_execution_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';

/// 工具模板管理界面
class ToolTemplateScreen extends StatefulWidget {
  final ToolTemplateService templateService;
  final Function(SavedToolTemplate)? onUseTemplate;

  const ToolTemplateScreen({
    super.key,
    required this.templateService,
    this.onUseTemplate,
  });

  @override
  State<ToolTemplateScreen> createState() => _ToolTemplateScreenState();
}

class _ToolTemplateScreenState extends State<ToolTemplateScreen> {
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  final ScrollController _tagsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.templateService.addListener(_onTemplatesChanged);
  }

  @override
  void dispose() {
    _tagsScrollController.dispose();
    widget.templateService.removeListener(_onTemplatesChanged);
    super.dispose();
  }

  void _onTemplatesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 应用搜索和标签过滤
    var templates = widget.templateService.templates;

    if (_searchQuery.isNotEmpty) {
      templates = widget.templateService.searchTemplates(_searchQuery);
    }

    // 多标签过滤:只要模板包含任一选中标签就显示
    if (_selectedTags.isNotEmpty) {
      templates =
          templates
              .where((t) => t.tags.any((tag) => _selectedTags.contains(tag)))
              .toList();
    }

    final allTags = widget.templateService.getAllTags();
    final theme = DSThemeBridge.resolve(context);

    return SuperCupertinoNavigationWrapper(
      title: Text('agent_chat_toolTemplate'.tr),
      largeTitle: 'agent_chat_toolTemplate'.tr,
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'agent_chat_searchPlaceholder'.tr,
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      onSearchSubmitted: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      // 第三方导航栏 actions 回调内构建 DS 组件需包 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标签过滤按钮
                  if (allTags.isNotEmpty)
                    Pressable(
                      onPressed: () => _showTagFilterDialog(allTags),
                      semanticLabel: '按标签过滤',
                      builder:
                          (context, states) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: DSIconBadge(
                              icon: DsIconKind.sort,
                              count: _selectedTags.length,
                              size: 22,
                              iconColor:
                                  _selectedTags.isNotEmpty
                                      ? theme.primaryText
                                      : theme.textSub,
                            ),
                          ),
                    ),
                  // 重置默认模板按钮
                  DSIconButton(
                    icon: DsIconKind.refresh,
                    size: 40,
                    color: theme.surfaceAlt,
                    iconColor: theme.textSub,
                    onPressed: _resetToDefaultTemplates,
                    tooltip: '重置默认模板',
                  ),
                ],
              );
            },
          ),
        ),
      ],
      body: Column(
        children: [
          // 当前选中的标签
          if (_selectedTags.isNotEmpty)
            Container(
              color: theme.background,
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  Text(
                    '当前过滤：',
                    style: DsTypography.caption.copyWith(color: theme.textSub),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Scrollbar(
                      controller: _tagsScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tagsScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _selectedTags.map((tag) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Center(
                                    child: DSChip(
                                      icon: DsIconKind.tag,
                                      label: tag,
                                      onDeleted: () {
                                        setState(() {
                                          _selectedTags.remove(tag);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedTags.length > 1)
                    DSButton(
                      label: 'agent_chat_clear'.tr,
                      icon: DsIconKind.close,
                      size: DSButtonSize.sm,
                      variant: DSButtonVariant.ghost,
                      onPressed: () {
                        setState(() {
                          _selectedTags.clear();
                        });
                      },
                    ),
                ],
              ),
            ),
          // 模板列表
          Expanded(
            child:
                templates.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return _buildTemplateCard(template);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final theme = DSThemeBridge.resolve(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DsIcon(DsIconKind.clipboard, size: 64, color: theme.textSub),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '暂无保存的工具模板' : '未找到匹配的模板',
            style: DsTypography.heading.copyWith(color: theme.textSub),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '在AI工具调用消息中点击"保存工具"即可保存',
              style: DsTypography.body.copyWith(color: theme.textSub),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建模板卡片
  Widget _buildTemplateCard(SavedToolTemplate template) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radii.lg,
        border: Border.all(color: theme.textSub.withValues(alpha: 0.25)),
      ),
      child: Pressable(
        onPressed: () => _editTemplate(template),
        semanticLabel: template.name,
        builder:
            (context, states) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: DsTypography.heading.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.text,
                          ),
                        ),
                      ),
                      // 执行按钮
                      Pressable(
                        onPressed: () => _executeTemplate(template),
                        semanticLabel: '执行测试',
                        builder:
                            (context, states) => Padding(
                              padding: const EdgeInsets.all(6),
                              child: DsIcon(
                                DsIconKind.play,
                                size: 24,
                                color: theme.success,
                              ),
                            ),
                      ),
                      // 使用按钮
                      if (widget.onUseTemplate != null)
                        DSButton(
                          label: 'agent_chat_use'.tr,
                          icon: DsIconKind.send,
                          size: DSButtonSize.sm,
                          onPressed: () {
                            widget.onUseTemplate!(template);
                            Navigator.pop(context);
                          },
                        ),
                      const SizedBox(width: 8),
                      // 更多菜单
                      DSPopover(
                        width: 170,
                        contentBuilder: (popoverContext, close) {
                          final popoverTheme = DSThemeBridge.resolve(
                            popoverContext,
                          );
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _TemplateMenuAction(
                                icon: DsIconKind.edit,
                                label: 'agent_chat_edit'.tr,
                                theme: popoverTheme,
                                accent: popoverTheme.primaryText,
                                onTap: () {
                                  close();
                                  _editTemplate(template);
                                },
                              ),
                              _TemplateMenuAction(
                                icon: DsIconKind.trash,
                                label: 'agent_chat_delete'.tr,
                                theme: popoverTheme,
                                accent: popoverTheme.danger,
                                onTap: () {
                                  close();
                                  _deleteTemplate(template);
                                },
                              ),
                            ],
                          );
                        },
                        child: DsIcon(
                          DsIconKind.more,
                          size: 20,
                          color: theme.textSub,
                        ),
                      ),
                    ],
                  ),

                  // 描述
                  if (template.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      template.description!,
                      style: DsTypography.body.copyWith(color: theme.textSub),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 统计信息
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        DsIconKind.gear,
                        '${template.steps.length} 个步骤',
                        theme.primaryText,
                      ),
                      _buildInfoChip(
                        DsIconKind.clock,
                        _formatTime(template.createdAt),
                        theme.textSub,
                      ),
                      if (template.usageCount > 0)
                        _buildInfoChip(
                          DsIconKind.star,
                          '使用 ${template.usageCount} 次',
                          theme.success,
                        ),
                      if (template.declaredTools.isNotEmpty)
                        _buildInfoChip(
                          DsIconKind.gear,
                          '${template.declaredTools.length} 个工具',
                          theme.warning,
                        ),
                    ],
                  ),

                  // 标签
                  if (template.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          template.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primary.mixWhite(0.92),
                                borderRadius: theme.radii.pill,
                                border: Border.all(
                                  color: theme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DsIcon(
                                    DsIconKind.tag,
                                    size: 12,
                                    color: theme.primaryText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag,
                                    style: DsTypography.caption.copyWith(
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip(DsIconKind icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIcon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: DsTypography.caption.copyWith(color: color)),
      ],
    );
  }

  /// 格式化时间
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 24) {
      return timeago.format(dateTime, locale: 'zh');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  /// 编辑模板
  Future<void> _editTemplate(SavedToolTemplate template) async {
    final result = await showEditToolDialog(
      context,
      template,
      widget.templateService,
    );

    if (result == true && mounted) {
      // 编辑成功，界面会自动更新（通过监听器）
      setState(() {});
    }
  }

  /// 删除模板
  Future<void> _deleteTemplate(SavedToolTemplate template) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'agent_chat_deleteConfirmation'.tr,
                    message: 'agent_chat_confirmDeleteTemplate'.trParams({
                      'templateName': template.name,
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

    if (confirmed == true) {
      try {
        await widget.templateService.deleteTemplate(template.id);
        if (mounted) {
          toastService.showToast('删除成功');
        }
      } catch (e) {
        if (mounted) {
          toastService.showToast('删除失败: $e');
        }
      }
    }
  }

  /// 执行模板测试
  Future<void> _executeTemplate(SavedToolTemplate template) async {
    // 克隆步骤以避免修改原始模板
    final steps = widget.templateService.cloneTemplateSteps(template);

    await showDSDialog(
      context: context,
      barrierDismissible: false,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => TemplateExecutionDialog(
                    templateName: template.name,
                    steps: steps,
                  ),
            ),
          ),
    );
  }

  /// 显示标签过滤对话框
  Future<void> _showTagFilterDialog(List<String> allTags) async {
    final result = await showDSDialog<Set<String>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => _TagFilterDialog(
                    allTags: allTags,
                    selectedTags: Set.from(_selectedTags),
                    templateService: widget.templateService,
                  ),
            ),
          ),
    );

    if (result != null) {
      setState(() {
        _selectedTags = result;
      });
    }
  }

  /// 重置为默认模板
  Future<void> _resetToDefaultTemplates() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'agent_chat_resetConfirmation'.tr,
                    message:
                        '此操作将强制恢复所有默认工具模板到初始状态。\n\n'
                        '⚠️ 注意：如果您修改过默认模板，这些修改将会被覆盖！\n\n'
                        '自定义模板不会受到影响。',
                    cancelText: 'agent_chat_cancel'.tr,
                    confirmText: 'agent_chat_reset'.tr,
                    onConfirm: () => Navigator.pop(dialogContext, true),
                    onCancel: () => Navigator.pop(dialogContext, false),
                  ),
            ),
          ),
    );

    if (confirmed != true) return;

    try {
      // 显示加载指示器
      if (mounted) {
        showDSDialog(
          context: context,
          barrierDismissible: false,
          theme: DSThemeBridge.resolve(context),
          builder:
              (_) => DSThemeBridge(
                child: Builder(
                  builder:
                      (ctx) => Center(
                        child: DSLoadingDots(
                          label: 'agent_chat_resettingDefaultTemplates'.tr,
                        ),
                      ),
                ),
              ),
        );
      }

      // 执行重置操作
      await widget.templateService.restoreDefaultTemplates();

      // 关闭加载指示器
      if (mounted) {
        Navigator.pop(context);

        // 显示成功提示
        toastService.showToast('默认模板已成功重置');

        // 刷新界面
        setState(() {});
      }
    } catch (e) {
      // 关闭加载指示器
      if (mounted) {
        Navigator.pop(context);

        // 显示错误提示
        toastService.showToast('重置失败: $e');
      }
    }
  }
}

/// 标签过滤对话框
class _TagFilterDialog extends StatefulWidget {
  final List<String> allTags;
  final Set<String> selectedTags;
  final ToolTemplateService templateService;

  const _TagFilterDialog({
    required this.allTags,
    required this.selectedTags,
    required this.templateService,
  });

  @override
  State<_TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<_TagFilterDialog> {
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return JellyBox(
      radius: theme.radii.xxl,
      padding: EdgeInsets.all(theme.spacing.xl),
      constraints: const BoxConstraints(maxWidth: 460, maxHeight: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DsIcon(DsIconKind.sort, size: 24, color: theme.primaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'agent_chat_selectTagFilter'.tr,
                  style: DsTypography.title.copyWith(color: theme.text),
                ),
              ),
              if (_selectedTags.isNotEmpty)
                DSButton(
                  label: 'agent_chat_clear'.tr,
                  size: DSButtonSize.sm,
                  variant: DSButtonVariant.ghost,
                  onPressed: () {
                    setState(() {
                      _selectedTags.clear();
                    });
                  },
                ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    widget.allTags.map((tag) {
                      final count =
                          widget.templateService.templates
                              .where((t) => t.tags.contains(tag))
                              .length;
                      final isSelected = _selectedTags.contains(tag);

                      return Center(
                        child: DSChip(
                          icon: DsIconKind.tag,
                          label: '$tag ($count)',
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
          SizedBox(height: theme.spacing.lg),
          Row(
            children: [
              Expanded(
                child: DSButton(
                  label: 'agent_chat_cancel'.tr,
                  variant: DSButtonVariant.outline,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: DSButton(
                  label:
                      '${'agent_chat_confirm'.tr}'
                      '${_selectedTags.isEmpty ? '' : ' (${_selectedTags.length})'}',
                  onPressed: () => Navigator.pop(context, _selectedTags),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 模板卡片气泡菜单行
class _TemplateMenuAction extends StatelessWidget {
  const _TemplateMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.accent,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final effective = accent ?? theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: effective),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.caption.copyWith(color: effective),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
