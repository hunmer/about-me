import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_template_service.dart';
import 'package:aboutme/plugins/agent_chat/models/saved_tool_template.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/save_tool_dialog.dart';
import 'components/template_execution_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

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

  // 多条件过滤参数
  Map<String, dynamic> _multiFilters = {};

  @override
  void initState() {
    super.initState();
    widget.templateService.addListener(_onTemplatesChanged);
  }

  @override
  void dispose() {
    widget.templateService.removeListener(_onTemplatesChanged);
    super.dispose();
  }

  void _onTemplatesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 构建多条件过滤项（design.md §8）
  List<FilterItem> _buildFilterItems(List<String> allTags) {
    return [
      if (allTags.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'agent_chat_tag'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: allTags,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),
    ];
  }

  void _applyMultiFilters(Map<String, dynamic> filters) {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _multiFilters = filters;
        });
      }
    });
  }

  /// 检查模板是否通过多条件过滤
  bool _passesMultiFilters(SavedToolTemplate template) {
    final selectedTags = (_multiFilters['tags'] as List?)?.cast<String>();
    if (selectedTags == null || selectedTags.isEmpty) return true;
    return template.tags.any((tag) => selectedTags.contains(tag));
  }

  @override
  Widget build(BuildContext context) {
    // 应用搜索过滤
    var templates = widget.templateService.templates;

    if (_searchQuery.isNotEmpty) {
      templates = widget.templateService.searchTemplates(_searchQuery);
    }

    // 应用多条件过滤:只要模板包含任一选中标签就显示
    templates = templates.where(_passesMultiFilters).toList();

    final allTags = widget.templateService.getAllTags();

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
      // 标签筛选收敛到多条件过滤栏（design.md §8）
      enableMultiFilter: true,
      multiFilterItems: _buildFilterItems(allTags),
      onMultiFilterChanged: _applyMultiFilters,
      // 第三方导航栏 actions 回调内构建 DS 组件需包 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSIconButton(
                icon: DsIconKind.refresh,
                size: 40,
                color: theme.surfaceAlt,
                iconColor: theme.textSub,
                onPressed: _resetToDefaultTemplates,
                tooltip: 'agent_chat_resetDefaultTemplates'.tr,
              );
            },
          ),
        ),
      ],
      body:
          templates.isEmpty
              ? _buildEmptyState()
              : HandDrawnListView(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                ),
                itemCount: templates.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 16),
                // 便签倾斜角度由模板 id 哈希确定,重排后不变（design.md §11）
                tiltKeyOf: (index) => templates[index].id,
                itemBuilder: (context, index) {
                  // 挂载即播墨线描画入场（design.md §10）
                  return WiredDraw(
                    child: _buildTemplateCard(templates[index]),
                  );
                },
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
            _searchQuery.isEmpty
                ? 'agent_chat_emptyTemplates'.tr
                : 'agent_chat_noMatchTemplates'.tr,
            style: DsTypography.heading.copyWith(color: theme.textSub),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'agent_chat_emptyTemplatesHint'.tr,
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
      // 手绘卡片容器:纯色实底 + 墨线描边（design.md §9.1）
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: theme.surface,
        radius: theme.radii.lg,
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
                        semanticLabel: 'agent_chat_executeTest'.tr,
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
                        'agent_chat_stepCount'.trParams({
                          'count': '${template.steps.length}',
                        }),
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
                          'agent_chat_usedCount'.trParams({
                            'count': '${template.usageCount}',
                          }),
                          theme.success,
                        ),
                      if (template.declaredTools.isNotEmpty)
                        _buildInfoChip(
                          DsIconKind.gear,
                          'agent_chat_toolCount'.trParams({
                            'count': '${template.declaredTools.length}',
                          }),
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
                          template.tags
                              .map(
                                (tag) => DSChip(
                                  icon: DsIconKind.tag,
                                  label: tag,
                                ),
                              )
                              .toList(),
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
      return 'agent_chat_daysAgo'.trParams({
        'count': '${difference.inDays}',
      });
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
          toastService.showToast('agent_chat_deleteSuccess'.tr);
        }
      } catch (e) {
        if (mounted) {
          toastService.showToast(
            'agent_chat_deleteFailed'.trParams({'error': '$e'}),
          );
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
                    message: 'agent_chat_resetDefaultHint'.tr,
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
        toastService.showToast('agent_chat_resetSuccess'.tr);

        // 刷新界面
        setState(() {});
      }
    } catch (e) {
      // 关闭加载指示器
      if (mounted) {
        Navigator.pop(context);

        // 显示错误提示
        toastService.showToast(
          'agent_chat_resetFailed'.trParams({'error': '$e'}),
        );
      }
    }
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
