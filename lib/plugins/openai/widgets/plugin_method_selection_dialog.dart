import 'package:get/get.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/models/plugin_analysis_method.dart';

class PluginMethodSelectionDialog extends StatefulWidget {
  const PluginMethodSelectionDialog({super.key});

  @override
  State<PluginMethodSelectionDialog> createState() =>
      _PluginMethodSelectionDialogState();
}

class _PluginMethodSelectionDialogState
    extends State<PluginMethodSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPluginId;
  String _searchQuery = '';

  // 获取所有插件ID列表
  List<String> get _allPluginIds {
    final pluginIds =
        PluginAnalysisMethod.predefinedMethods
            .map((m) => m.pluginId)
            .whereType<String>()
            .toSet()
            .toList();
    pluginIds.sort();
    return pluginIds;
  }

  // 插件显示名称映射
  Map<String, String> get _pluginDisplayNames => {
    'system': '系统',
    'activity': '活动',
    'bill': '账单',
    'calendar': '日历',
    'calendar_album': '日记相册',
    'chat': '聊天',
    'checkin': '签到',
    'contact': '联系人',
    'database': '数据库',
    'day': '纪念日',
    'diary': '日记',
    'goods': '物品',
    'habits': '习惯',
    'nodes': '节点',
    'notes': '笔记',
    'store': '商店',
    'timer': '计时器',
    'todo': '任务',
    'tracker': '目标',
    'ui': '界面',
  };

  // 过滤方法列表
  List<PluginAnalysisMethod> get _filteredMethods {
    var methods = PluginAnalysisMethod.predefinedMethods;

    // 按插件ID过滤
    if (_selectedPluginId != null) {
      methods = methods.where((m) => m.pluginId == _selectedPluginId).toList();
    }

    // 按搜索关键词过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      methods =
          methods.where((m) {
            return m.name.toLowerCase().contains(query) ||
                m.title.toLowerCase().contains(query);
          }).toList();
    }

    return methods;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return JellyBox(
            radius: theme.radii.xxl,
            padding: EdgeInsets.all(theme.spacing.lg),
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    DsIcon(DsIconKind.grid, size: 24, color: theme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'openai_selectAnalysisMethod'.tr,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                    const Spacer(),
                    Text(
                      '共 ${_filteredMethods.length} 个方法',
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: theme.spacing.sm),

                // 搜索框
                DSInput.search(controller: _searchController, hint: '搜索方法...'),
                const SizedBox(height: 12),

                // 插件过滤按钮
                DSChipBar(
                  labels: [
                    'openai_all'.tr,
                    for (final pluginId in _allPluginIds)
                      _pluginDisplayNames[pluginId] ?? pluginId,
                  ],
                  selected:
                      (_allPluginIds.indexOf(_selectedPluginId ?? '') + 1)
                          .clamp(0, _allPluginIds.length),
                  onChanged: (index) => setState(() {
                    _selectedPluginId =
                        index == 0 ? null : _allPluginIds[index - 1];
                  }),
                ),
                const SizedBox(height: 12),

                // 方法列表
                Flexible(
                  child:
                      _filteredMethods.isEmpty
                          ? Center(
                            child: DSEmptyState(
                              emoji: '🔍',
                              title: '没有找到匹配的方法',
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredMethods.length,
                            itemBuilder: (context, index) {
                              final method = _filteredMethods[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: DSCard(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: theme.spacing.md,
                                    vertical: theme.spacing.sm,
                                  ),
                                  onTap: () {
                                    // 直接使用默认模板，不打开表单对话框
                                    final jsonString = jsonEncode(
                                      method.template,
                                    );
                                    Navigator.pop(context, {
                                      'methodName': method.name,
                                      'jsonString': jsonString,
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      DsIcon(
                                        DsIconKind.bot,
                                        size: 20,
                                        color: theme.primary,
                                      ),
                                      SizedBox(width: theme.spacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              method.name,
                                              style: DsTypography.body.copyWith(
                                                color: theme.text,
                                              ),
                                            ),
                                            Text(
                                              method.title,
                                              style: DsTypography.caption
                                                  .copyWith(
                                                    color: theme.textSub,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DSChip(
                                        label:
                                            _pluginDisplayNames[method
                                                .pluginId] ??
                                            method.pluginId ??
                                            '',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),

                // 底部按钮
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DSButton(
                      label: 'openai_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
