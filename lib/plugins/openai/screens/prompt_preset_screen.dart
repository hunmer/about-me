import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:aboutme/core/route/route_history_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/widgets/preset_edit_form.dart';
import 'package:aboutme/plugins/openai/models/prompt_preset.dart';
import 'package:aboutme/plugins/openai/services/prompt_preset_service.dart';

class PromptPresetScreen extends StatefulWidget {
  const PromptPresetScreen({super.key});

  @override
  State<PromptPresetScreen> createState() => _PromptPresetScreenState();
}

class _PromptPresetScreenState extends State<PromptPresetScreen> {
  late final PromptPresetService _service;
  List<PromptPreset> _filteredPresets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = PromptPresetService();

    // 加载预设数据
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoading = true;
    });

    await _service.loadPresets();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _filteredPresets = _service.presets;
      });
    }
  }

  /// 构建过滤条件列表
  List<FilterItem> _buildFilterItems() {
    // 获取所有可用标签
    final allTags = <String>{};
    for (final preset in _service.presets) {
      allTags.addAll(preset.tags);
    }

    return [
      // 标签过滤
      FilterItem(
        id: 'tags',
        title: 'openai_tags'.tr,
        type: FilterType.tagsMultiple,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildTagsFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
            availableTags: allTags.toList(),
          );
        },
        getBadge: FilterBuilders.tagsBadge,
      ),
    ];
  }

  /// 应用过滤条件
  void _applyFilters(Map<String, dynamic> filters) {
    List<PromptPreset> result = [..._service.presets];

    // 标签过滤
    if (filters['tags'] != null && (filters['tags'] as List).isNotEmpty) {
      final selectedTags = filters['tags'] as List<String>;
      result =
          result.where((preset) {
            return selectedTags.any((tag) => preset.tags.contains(tag));
          }).toList();
    }

    setState(() {
      _filteredPresets = result;
    });
  }

  /// 处理搜索
  void _handleSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredPresets = _service.presets;
      });
      return;
    }

    final keyword = query.toLowerCase();
    final filteredBySearch =
        _service.presets.where((preset) {
          return preset.name.toLowerCase().contains(keyword) ||
              preset.description.toLowerCase().contains(keyword) ||
              preset.content.toLowerCase().contains(keyword);
        }).toList();

    setState(() {
      _filteredPresets = filteredBySearch;
    });
  }

  /// 显示编辑页面
  Future<void> _showEditPage({PromptPreset? preset}) async {
    // 编辑页为无名路由，手动上报编辑上下文，关闭后恢复预设tab上下文
    RouteHistoryManager.updateCurrentContext(
      pageId: '/openai/preset_edit',
      title: preset?.name ?? 'openai_promptPreset'.tr,
      params: {
        'mode': preset == null ? '新建' : '编辑',
        'name': preset?.name ?? '',
      },
    );
    await showPresetEditPage(
      context: context,
      preset: preset,
      onSave: (newPreset, prompts) async {
        // 确保 prompts 正确设置到 preset 中
        final updatedPreset = newPreset.copyWith(prompts: prompts);

        // 保存包含 prompts 的预设
        if (preset == null) {
          await _service.addPreset(updatedPreset);
        } else {
          await _service.updatePreset(updatedPreset);
        }
        // 重新加载以获取最新的 prompts 数据
        await _loadPresets();
      },
    );
    if (mounted) {
      RouteHistoryManager.updateCurrentContext(
        pageId: '/openai/presets',
        title: 'openai_promptPreset'.tr,
      );
    }
  }

  /// 删除预设
  Future<void> _deletePreset(PromptPreset preset) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (dialogContext) => DSDialog(
                    title: 'openai_deletePreset'.tr,
                    message: 'openai_confirmDeletePreset'.tr,
                    confirmText: 'openai_delete'.tr,
                    cancelText: 'openai_cancel'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.of(dialogContext).pop(true),
                    onCancel: () => Navigator.of(dialogContext).pop(false),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      await _service.deletePreset(preset.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('openai_promptPresetManagement'.tr),
        largeTitle: 'openai_promptPresetManagement'.tr,
        enableLargeTitle: false,

        // 启用多条件过滤
        enableMultiFilter: true,
        multiFilterItems: _buildFilterItems(),
        onMultiFilterChanged: _applyFilters,

        // 启用搜索栏
        enableSearchBar: true,
        onSearchChanged: _handleSearch,

        // 第三方导航栏回调,DS 组件需包主题桥
        actions: [
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.plus,
                  size: 40,
                  color: theme.surfaceAlt,
                  iconColor: theme.textSub,
                  onPressed: () => _showEditPage(),
                );
              },
            ),
          ),
        ],
        body: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            if (_isLoading) {
              return const Center(child: DSLoadingDots());
            }

            if (_service.presets.isEmpty) {
              return Center(
                child: DSEmptyState(
                  emoji: '📝',
                  title: 'openai_noPresetsYet'.tr,
                  message: 'openai_createFirstPreset'.tr,
                  actionLabel: 'openai_addPreset'.tr,
                  onAction: () => _showEditPage(),
                ),
              );
            }

            if (_filteredPresets.isEmpty) {
              return Center(
                child: DSEmptyState(
                  emoji: '🔍',
                  title: 'openai_noMatchingPresets'.tr,
                  message: 'openai_tryAdjustingFilters'.tr,
                ),
              );
            }

            return Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: _filteredPresets.length,
                  itemBuilder: (context, index) {
                    final preset = _filteredPresets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DSCard(
                        onTap: () => _showEditPage(preset: preset),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    preset.name,
                                    style: DsTypography.body.copyWith(
                                      color: theme.text,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (preset.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        preset.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: DsTypography.caption.copyWith(
                                          color: theme.textSub,
                                        ),
                                      ),
                                    ),
                                  if (preset.tags.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children:
                                            preset.tags
                                                .map(
                                                  (tag) => DSChip(label: tag),
                                                )
                                                .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // DSPopover 经根 Overlay 展示,内容已自带主题
                            DSPopover(
                              width: 200,
                              contentBuilder: (context, close) {
                                final menuTheme = DSThemeBridge.resolve(
                                  context,
                                );
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _PresetMenuRow(
                                      icon: DsIcon(
                                        DsIconKind.edit,
                                        size: 20,
                                        color: menuTheme.primary,
                                      ),
                                      label: 'openai_editPreset'.tr,
                                      theme: menuTheme,
                                      onTap: () async {
                                        close();
                                        await _showEditPage(preset: preset);
                                      },
                                    ),
                                    _PresetMenuRow(
                                      icon: DsIcon(
                                        DsIconKind.trash,
                                        size: 20,
                                        color: menuTheme.danger,
                                      ),
                                      label: 'openai_deletePreset'.tr,
                                      theme: menuTheme,
                                      danger: true,
                                      onTap: () async {
                                        close();
                                        await _deletePreset(preset);
                                      },
                                    ),
                                  ],
                                );
                              },
                              child: DSIconButton(
                                icon: DsIconKind.more,
                                size: 36,
                                color: theme.surfaceAlt,
                                iconColor: theme.textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 预设菜单行(果冻风格)
class _PresetMenuRow extends StatelessWidget {
  const _PresetMenuRow({
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
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.md,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
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
