import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/gestures.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'components/plugin_section.dart';
import 'components/tool_editor_dialog.dart';
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
    final selectedPlugin = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('agent_chat_selectPlugin'.tr),
            content: SizedBox(
              width: double.maxFinite,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
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
                    return ListTile(
                      title: Text(pluginId),
                      onTap: () => Navigator.pop(context, pluginId),
                    );
                  },
                ),
              ),
            ),
          ),
    );

    if (selectedPlugin == null) return;

    // 打开编辑对话框
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => ToolEditorDialog(pluginId: selectedPlugin, isNew: true),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('agent_chat_confirmImport'.tr),
              content: Text('agent_chat_importConfigOverride'.tr),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('agent_chat_cancel'.tr),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('agent_chat_confirm'.tr),
                ),
              ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('agent_chat_confirmRestoreDefault'.tr),
            content: Text('agent_chat_restoreDefaultDescription'.tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('agent_chat_cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('agent_chat_restoreDefault'.tr),
              ),
            ],
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

    return SizedBox(
      height: 50,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
          scrollbars: false,
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // "全部" 按钮
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('agent_chat_all'.tr),
                selected: _selectedPluginFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _selectedPluginFilter = null;
                  });
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            // 各个插件按钮
            ...pluginIds.map((pluginId) {
              final toolSet = _allPluginTools[pluginId];
              final enabledCount = toolSet?.enabledToolCount ?? 0;
              final totalCount = toolSet?.toolCount ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    'agent_chat_pluginInfo'.trParams({
                      'pluginId': pluginId,
                      'enabledCount': enabledCount.toString(),
                      'totalCount': totalCount.toString(),
                    }),
                  ),
                  selected: _selectedPluginFilter == pluginId,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPluginFilter = selected ? pluginId : null;
                    });
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SuperCupertinoNavigationWrapper(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: '更多选项',
          enabled: !_isLoading,
          onSelected: (value) {
            switch (value) {
              case 'add':
                _addTool();
                break;
              case 'import':
                _importConfig();
                break;
              case 'export':
                _exportConfig();
                break;
              case 'reset':
                _resetToDefault();
                break;
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      const Icon(Icons.add),
                      const SizedBox(width: 12),
                      Text('agent_chat_addTool'.tr),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      const Icon(Icons.file_download),
                      const SizedBox(width: 12),
                      Text('agent_chat_importConfig'.tr),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      const Icon(Icons.file_upload),
                      const SizedBox(width: 12),
                      Text('agent_chat_exportConfig'.tr),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      const Icon(Icons.restore, color: Colors.red),
                      const SizedBox(width: 12),
                      Text(
                        'agent_chat_restoreDefault'.tr,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
        ),
      ],
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // 插件筛选按钮栏
                  if (_allPluginTools.isNotEmpty) _buildPluginFilterBar(),

                  const SizedBox(height: 8),
                  const Divider(),

                  // 工具列表
                  Expanded(
                    child:
                        _allPluginTools.isEmpty
                            ? Center(child: Text('agent_chat_noToolConfig'.tr))
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

                  // 底部统计信息
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: _buildStatistics(),
                  ),
                ],
              ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatistics() {
    // 直接从内存中的工具配置计算统计，确保与 _showDisabledTools 一致
    int totalTools = 0;
    int enabledTools = 0;

    _allPluginTools.forEach((pluginId, toolSet) {
      toolSet.tools.forEach((toolId, config) {
        totalTools++;
        if (config.enabled) {
          enabledTools++;
        }
      });
    });

    final disabledCount = totalTools - enabledTools;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('总工具数', totalTools.toString(), Icons.build),
            _buildStatItem(
              '已启用',
              enabledTools.toString(),
              Icons.check_circle,
              color: Colors.green,
            ),
            _buildStatItem(
              '已禁用',
              disabledCount.toString(),
              Icons.block,
              color: Colors.grey,
              onTap: disabledCount > 0 ? _showDisabledTools : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8), child: child),
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

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.block, color: Colors.grey),
                const SizedBox(width: 8),
                Text('agent_chat_disabledTools'.tr),
                const Spacer(),
                Text(
                  '${disabledTools.length} 个',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  disabledTools.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 64,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 16),
                              Text('agent_chat_allToolsEnabled'.tr),
                            ],
                          ),
                        ),
                      )
                      : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
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
                            final pluginId = item['pluginId'] as String;
                            final toolId = item['toolId'] as String;
                            final config = item['config'] as ToolConfig;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  pluginId[0].toUpperCase(),
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                              title: Text(
                                toolId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    config.title,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '插件: $pluginId',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                tooltip: '启用此工具',
                                onPressed: () async {
                                  try {
                                    await ToolConfigManager.instance
                                        .toggleToolEnabled(
                                          pluginId,
                                          toolId,
                                          true,
                                        );
                                    Navigator.pop(context);
                                    await _loadTools();
                                    _showSuccess('已启用工具: $toolId');
                                  } catch (e) {
                                    _showError('启用失败: $e');
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
            ),
            actions: [
              if (disabledTools.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text('agent_chat_confirmEnableAll'.tr),
                            content: Text(
                              'agent_chat_confirmEnableAllTools'.trParams({
                                'count': disabledTools.length.toString(),
                              }),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('agent_chat_cancel'.tr),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('agent_chat_enableAll'.tr),
                              ),
                            ],
                          ),
                    );

                    if (confirmed == true) {
                      try {
                        for (final item in disabledTools) {
                          await ToolConfigManager.instance.toggleToolEnabled(
                            item['pluginId'] as String,
                            item['toolId'] as String,
                            true,
                          );
                        }
                        Navigator.pop(context);
                        await _loadTools();
                        _showSuccess('已启用所有工具');
                      } catch (e) {
                        _showError('批量启用失败: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.done_all),
                  label: Text('agent_chat_enableAll'.tr),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('agent_chat_close'.tr),
              ),
            ],
          ),
    );
  }
}
