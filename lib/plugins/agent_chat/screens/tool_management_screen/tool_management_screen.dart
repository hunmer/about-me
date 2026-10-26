import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'components/plugin_section.dart';
import 'components/agent_chat_tool_form.dart';
import 'package:aboutme/core/services/toast_service.dart';

/// 工具管理界面
class ToolManagementScreen extends StatefulWidget {
  final String? conversationId;
  final Function(String pluginId, String toolId, ToolConfig config)?
  onAddToChat;

  const ToolManagementScreen({
    super.key,
    this.conversationId,
    this.onAddToChat,
  });

  @override
  State<ToolManagementScreen> createState() => _ToolManagementScreenState();
}

class _ToolManagementScreenState extends State<ToolManagementScreen> {
  final _searchController = TextEditingController();
  String _searchKeyword = '';
  bool _isLoading = false;
  String? _selectedPluginFilter; // null 表示显示全部

  Map<String, PluginToolSet> _allPluginTools = {};
  List<String> _filteredToolIds = [];

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载工具配置
  Future<void> _loadTools() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _allPluginTools = ToolConfigManager.instance.getAllPluginTools();
      _applySearch();
    } catch (e) {
      _showError('加载工具配置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 应用搜索过滤
  void _applySearch() {
    if (_searchKeyword.isEmpty) {
      _filteredToolIds = [];
    } else {
      _filteredToolIds = ToolConfigManager.instance.searchTools(_searchKeyword);
    }
    setState(() {});
  }

  /// 搜索框变化
  void _onSearchChanged(String value) {
    setState(() {
      _searchKeyword = value;
    });
    _applySearch();
  }

  /// 添加新工具
  Future<void> _addTool() async {
    // 获取所有插件 ID
    final pluginIds = _allPluginTools.keys.toList();

    if (pluginIds.isEmpty) {
      _showError('没有可用的插件');
      return;
    }

    // 选择插件
    final selectedPlugin = await showDSDialog<String>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'agent_chat_selectPlugin'.tr,
                        textAlign: TextAlign.center,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                      SizedBox(height: theme.spacing.md),
                      Flexible(
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(ctx).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                            },
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: pluginIds.length,
                            itemBuilder: (context, index) {
                              final pluginId = pluginIds[index];
                              return DSListItem(
                                title: pluginId,
                                onTap:
                                    () =>
                                        Navigator.pop(dialogContext, pluginId),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );

    if (selectedPlugin == null) return;

    // 打开编辑对话框
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) =>
                      AgentChatToolForm(pluginId: selectedPlugin, isNew: true),
            ),
          ),
    );

    if (result != null) {
      try {
        final toolId = result['toolId'] as String;
        final config = result['config'] as ToolConfig;

        await ToolConfigManager.instance.addTool(
          selectedPlugin,
          toolId,
          config,
        );

        _showSuccess('工具添加成功');
        await _loadTools();
      } catch (e) {
        _showError('添加工具失败: $e');
      }
    }
  }

  /// 导入配置
  Future<void> _importConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      // 确认导入
      final confirmed = await showDSDialog<bool>(
        context: context,
        theme: DSThemeBridge.resolve(context),
        builder:
            (dialogContext) => DSThemeBridge(
              child: Builder(
                builder:
                    (ctx) => DSDialog(
                      title: 'agent_chat_confirmImport'.tr,
                      message: 'agent_chat_importConfigOverride'.tr,
                      cancelText: 'agent_chat_cancel'.tr,
                      confirmText: 'agent_chat_confirm'.tr,
                      onConfirm: () => Navigator.pop(dialogContext, true),
                      onCancel: () => Navigator.pop(dialogContext, false),
                    ),
              ),
            ),
      );

      if (confirmed != true) return;

      setState(() {
        _isLoading = true;
      });

      await ToolConfigManager.instance.importConfig(filePath);
      _showSuccess('配置导入成功');
      await _loadTools();
    } catch (e) {
      _showError('导入配置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 导出配置
  Future<void> _exportConfig() async {
    try {
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'tools_config_$timestamp.json';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出工具配置',
        fileName: fileName,
      );

      if (outputPath == null) return;

      setState(() {
        _isLoading = true;
      });

      await ToolConfigManager.instance.exportConfig(outputPath);
      _showSuccess('配置已导出到: $outputPath');
    } catch (e) {
      _showError('导出配置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 恢复默认配置
  Future<void> _resetToDefault() async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder:
                  (ctx) => DSDialog(
                    title: 'agent_chat_confirmRestoreDefault'.tr,
                    message: 'agent_chat_restoreDefaultDescription'.tr,
                    cancelText: 'agent_chat_cancel'.tr,
                    confirmText: 'agent_chat_restoreDefault'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onConfirm: () => Navigator.pop(dialogContext, true),
                    onCancel: () => Navigator.pop(dialogContext, false),
                  ),
            ),
          ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await ToolConfigManager.instance.resetToDefault();
      _showSuccess('已恢复默认配置');
      await _loadTools();
    } catch (e) {
      _showError('恢复默认配置失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示错误消息
  void _showError(String message) {
    toastService.showToast(message);
  }

  /// 显示成功消息
  void _showSuccess(String message) {
    toastService.showToast(message);
  }

  /// 构建插件分组列表
  List<Widget> _buildPluginSections() {
    final sections = <Widget>[];

    _allPluginTools.forEach((pluginId, toolSet) {
      // 如果选择了插件过滤，只显示该插件
      if (_selectedPluginFilter != null && pluginId != _selectedPluginFilter) {
        return;
      }

      // 如果有搜索关键词，只显示匹配的工具
      List<String> toolIds;
      if (_searchKeyword.isNotEmpty) {
        toolIds =
            toolSet.tools.keys
                .where((toolId) => _filteredToolIds.contains(toolId))
                .toList();
        if (toolIds.isEmpty) return; // 跳过没有匹配工具的插件
      } else {
        toolIds = toolSet.tools.keys.toList();
      }

      sections.add(
        PluginSection(
          pluginId: pluginId,
          toolSet: toolSet,
          visibleToolIds: toolIds,
          onRefresh: _loadTools,
          onAddToChat: widget.onAddToChat,
        ),
      );
    });

    return sections;
  }

  /// 构建插件筛选按钮栏
  Widget _buildPluginFilterBar() {
    final pluginIds = _allPluginTools.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
          scrollbars: false,
        ),
        child: DSChipBar(
          labels: [
            'agent_chat_all'.tr,
            for (final pluginId in pluginIds)
              'agent_chat_pluginInfo'.trParams({
                'pluginId': pluginId,
                'enabledCount':
                    (_allPluginTools[pluginId]?.enabledToolCount ?? 0)
                        .toString(),
                'totalCount':
                    (_allPluginTools[pluginId]?.toolCount ?? 0).toString(),
              }),
          ],
          selected:
              (pluginIds.indexOf(_selectedPluginFilter ?? '') + 1).clamp(
                0,
                pluginIds.length,
              ),
          onChanged: (index) => setState(() {
            _selectedPluginFilter = index == 0 ? null : pluginIds[index - 1];
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return SuperCupertinoNavigationWrapper(
      title: Text('agent_chat_toolManagement'.tr),
      largeTitle: 'agent_chat_toolManagement'.tr,
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: 'agent_chat_searchPlaceholder'.tr,
      onSearchChanged: (query) {
        _onSearchChanged(query);
      },
      onSearchSubmitted: (query) {
        _onSearchChanged(query);
      },
      // 第三方导航栏 actions 回调内构建 DS 组件需包 DSThemeBridge
      actions: [
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              // 与原 PopupMenuButton 一致：加载中禁用菜单
              return IgnorePointer(
                ignoring: _isLoading,
                child: DSPopover(
                  width: 190,
                  contentBuilder: (popoverContext, close) {
                    final popoverTheme = DSThemeBridge.resolve(popoverContext);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ToolMenuAction(
                          icon: DsIconKind.plus,
                          label: 'agent_chat_addTool'.tr,
                          theme: popoverTheme,
                          onTap: () {
                            close();
                            _addTool();
                          },
                        ),
                        _ToolMenuAction(
                          icon: DsIconKind.download,
                          label: 'agent_chat_importConfig'.tr,
                          theme: popoverTheme,
                          onTap: () {
                            close();
                            _importConfig();
                          },
                        ),
                        _ToolMenuAction(
                          icon: DsIconKind.share,
                          label: 'agent_chat_exportConfig'.tr,
                          theme: popoverTheme,
                          onTap: () {
                            close();
                            _exportConfig();
                          },
                        ),
                        _ToolMenuAction(
                          icon: DsIconKind.refresh,
                          label: 'agent_chat_restoreDefault'.tr,
                          theme: popoverTheme,
                          danger: true,
                          onTap: () {
                            close();
                            _resetToDefault();
                          },
                        ),
                      ],
                    );
                  },
                  child: JellyBox(
                    width: 40,
                    height: 40,
                    radius: theme.radii.md,
                    color: theme.primary,
                    child: Center(
                      child: DsIcon(
                        DsIconKind.more,
                        size: 20,
                        color: theme.onPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      body:
          _isLoading
              ? const Center(child: DSThemeBridge(child: DSLoadingDots()))
              : Column(
                children: [
                  // 插件筛选按钮栏
                  if (_allPluginTools.isNotEmpty) _buildPluginFilterBar(),

                  const SizedBox(height: 8),
                  Divider(color: theme.textSub.withValues(alpha: 0.2)),

                  // 工具列表
                  Expanded(
                    child:
                        _allPluginTools.isEmpty
                            ? Center(
                              child: Text(
                                'agent_chat_noToolConfig'.tr,
                                style: DsTypography.body.copyWith(
                                  color: theme.textSub,
                                ),
                              ),
                            )
                            : ScrollConfiguration(
                              behavior: ScrollConfiguration.of(
                                context,
                              ).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: ListView(
                                padding: EdgeInsets.zero,
                                children: _buildPluginSections(),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
  
  Widget _buildStatItem(
    String label,
    String value,
    DsIconKind icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final theme = DSThemeBridge.resolve(context);
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DsIcon(icon, color: color ?? theme.primaryText),
        const SizedBox(height: 4),
        Text(
          value,
          style: DsTypography.title.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.text,
          ),
        ),
        Text(label, style: DsTypography.caption.copyWith(color: theme.textSub)),
      ],
    );

    if (onTap != null) {
      return Pressable(
        onPressed: onTap,
        semanticLabel: label,
        builder:
            (context, states) =>
                Padding(padding: const EdgeInsets.all(8), child: child),
      );
    }

    return child;
  }

  /// 显示已禁用工具列表
  void _showDisabledTools() {
    // 收集所有已禁用的工具
    final disabledTools = <Map<String, dynamic>>[];

    print('🔍 开始收集已禁用工具...');
    print('📦 插件总数: ${_allPluginTools.length}');

    _allPluginTools.forEach((pluginId, toolSet) {
      print('📌 检查插件: $pluginId (${toolSet.tools.length} 个工具)');

      int disabledCount = 0;
      toolSet.tools.forEach((toolId, config) {
        if (!config.enabled) {
          disabledCount++;
          disabledTools.add({
            'pluginId': pluginId,
            'toolId': toolId,
            'config': config,
          });
          print('  ❌ 禁用工具: $toolId - ${config.title}');
        }
      });

      if (disabledCount > 0) {
        print('  ⚠️  $pluginId 有 $disabledCount 个禁用工具');
      }
    });

    print('📊 总共找到 ${disabledTools.length} 个已禁用工具');

    // 按插件ID排序
    disabledTools.sort(
      (a, b) => (a['pluginId'] as String).compareTo(b['pluginId'] as String),
    );

    showDSDialog(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (dialogContext) => DSThemeBridge(
            child: Builder(
              builder: (ctx) {
                final theme = DSThemeBridge.resolve(ctx);
                return JellyBox(
                  radius: theme.radii.xxl,
                  padding: EdgeInsets.all(theme.spacing.xl),
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                    maxHeight: 560,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DsIcon(DsIconKind.block, color: theme.textSub),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'agent_chat_disabledTools'.tr,
                              style: DsTypography.title.copyWith(
                                color: theme.text,
                              ),
                            ),
                          ),
                          Text(
                            '${disabledTools.length} 个',
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: theme.spacing.md),
                      Flexible(
                        child:
                            disabledTools.isEmpty
                                ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DsIcon(
                                          DsIconKind.check,
                                          size: 64,
                                          color: theme.success,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'agent_chat_allToolsEnabled'.tr,
                                          style: DsTypography.body.copyWith(
                                            color: theme.textSub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(
                                    ctx,
                                  ).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: disabledTools.length,
                                    itemBuilder: (context, index) {
                                      final item = disabledTools[index];
                                      final pluginId =
                                          item['pluginId'] as String;
                                      final toolId = item['toolId'] as String;
                                      final config =
                                          item['config'] as ToolConfig;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Container(
                                          padding: EdgeInsets.all(
                                            theme.spacing.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.surfaceAlt.withValues(
                                              alpha: 0.5,
                                            ),
                                            borderRadius: theme.radii.md,
                                            border: Border.all(
                                              color: theme.textSub.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: theme.surface,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  pluginId[0].toUpperCase(),
                                                  style: DsTypography.body
                                                      .copyWith(
                                                        color: theme.textSub,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      toolId,
                                                      style: DsTypography.body
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                theme.textSub,
                                                            decoration:
                                                                TextDecoration
                                                                    .lineThrough,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      config.title,
                                                      style: DsTypography.body
                                                          .copyWith(
                                                            color: theme.text,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '插件: $pluginId',
                                                      style: DsTypography
                                                          .caption
                                                          .copyWith(
                                                            color:
                                                                theme.textSub,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Pressable(
                                                onPressed: () async {
                                                  try {
                                                    await ToolConfigManager
                                                        .instance
                                                        .toggleToolEnabled(
                                                          pluginId,
                                                          toolId,
                                                          true,
                                                        );
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                    await _loadTools();
                                                    _showSuccess(
                                                      '已启用工具: $toolId',
                                                    );
                                                  } catch (e) {
                                                    _showError('启用失败: $e');
                                                  }
                                                },
                                                semanticLabel: '启用此工具',
                                                builder:
                                                    (context, states) => DsIcon(
                                                      DsIconKind.check,
                                                      color: theme.success,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                      ),
                      SizedBox(height: theme.spacing.md),
                      if (disabledTools.isNotEmpty)
                        DSButton(
                          label: 'agent_chat_enableAll'.tr,
                          icon: DsIconKind.check,
                          variant: DSButtonVariant.outline,
                          expand: true,
                          onPressed: () async {
                            final confirmed = await showDSDialog<bool>(
                              context: ctx,
                              theme: DSThemeBridge.resolve(ctx),
                              builder:
                                  (confirmContext) => DSThemeBridge(
                                    child: Builder(
                                      builder:
                                          (c2) => DSDialog(
                                            title:
                                                'agent_chat_confirmEnableAll'
                                                    .tr,
                                            message:
                                                'agent_chat_confirmEnableAllTools'
                                                    .trParams({
                                                      'count':
                                                          disabledTools.length
                                                              .toString(),
                                                    }),
                                            cancelText: 'agent_chat_cancel'.tr,
                                            confirmText:
                                                'agent_chat_enableAll'.tr,
                                            onConfirm:
                                                () => Navigator.pop(
                                                  confirmContext,
                                                  true,
                                                ),
                                            onCancel:
                                                () => Navigator.pop(
                                                  confirmContext,
                                                  false,
                                                ),
                                          ),
                                    ),
                                  ),
                            );

                            if (confirmed == true) {
                              try {
                                for (final item in disabledTools) {
                                  await ToolConfigManager.instance
                                      .toggleToolEnabled(
                                        item['pluginId'] as String,
                                        item['toolId'] as String,
                                        true,
                                      );
                                }
                                Navigator.pop(dialogContext);
                                await _loadTools();
                                _showSuccess('已启用所有工具');
                              } catch (e) {
                                _showError('批量启用失败: $e');
                              }
                            }
                          },
                        ),
                      SizedBox(height: theme.spacing.sm),
                      DSButton(
                        label: 'agent_chat_close'.tr,
                        variant: DSButtonVariant.ghost,
                        expand: true,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}

/// 顶栏气泡菜单行
class _ToolMenuAction extends StatelessWidget {
  const _ToolMenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
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
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.caption.copyWith(color: accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
