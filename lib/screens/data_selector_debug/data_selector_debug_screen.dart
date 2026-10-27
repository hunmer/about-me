import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/services/plugin_data_selector/models/index.dart';
import 'package:aboutme/core/services/plugin_data_selector/plugin_data_selector_service.dart';

/// 插件数据选择器调试页面
///
/// - 按插件枚举所有已注册的 data_selectors，点击可实际运行并查看返回结果
/// - 校验选择器 ID 是否符合 `pluginId.selectorName` 规范
/// - 列出尚未注册任何选择器的插件，作为新增 data_selectors 的候选
class DataSelectorDebugScreen extends StatefulWidget {
  const DataSelectorDebugScreen({super.key});

  @override
  State<DataSelectorDebugScreen> createState() =>
      _DataSelectorDebugScreenState();
}

class _DataSelectorDebugScreenState extends State<DataSelectorDebugScreen> {
  // pluginId -> 已注册选择器
  final Map<String, List<SelectorDefinition>> _grouped = {};
  List<String> _pluginsWithoutSelectors = [];
  List<String> _invalidIdSelectors = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final selectors = pluginDataSelectorService.getAllSelectors();
    final grouped = <String, List<SelectorDefinition>>{};
    final invalid = <String>[];
    for (final s in selectors) {
      grouped.putIfAbsent(s.pluginId, () => []).add(s);
      if (!s.id.startsWith('${s.pluginId}.')) {
        invalid.add(s.id);
      }
    }

    final pluginIds =
        PluginManager.instance.getAllPlugins().map((p) => p.id).toSet();
    final without =
        pluginIds.difference(grouped.keys.toSet()).toList()..sort();

    setState(() {
      _grouped
        ..clear()
        ..addAll(grouped);
      _pluginsWithoutSelectors = without;
      _invalidIdSelectors = invalid;
    });
  }

  Future<void> _runSelector(SelectorDefinition selector) async {
    try {
      final result = await pluginDataSelectorService.showSelector(
        context,
        selector.id,
      );
      if (!mounted) return;
      _showResultDialog(selector, result);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(selector, e);
    }
  }

  void _showResultDialog(SelectorDefinition selector, SelectorResult? result) {
    String content;
    if (result == null || result.cancelled) {
      content = '已取消（cancelled）';
    } else {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        content = encoder.convert(result.toMap());
      } catch (_) {
        // rawData 可能不可 JSON 序列化，回退到 toString
        content = result.toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('结果: ${selector.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(SelectorDefinition selector, Object error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('调用失败: ${selector.name}'),
        content: SingleChildScrollView(
          child: Text('$error'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectorCount =
        _grouped.values.fold<int>(0, (sum, list) => sum + list.length);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据选择器调试'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新加载',
            onPressed: _reload,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCell(label: '选择器', value: selectorCount),
                  _StatCell(label: '有选择器的插件', value: _grouped.length),
                  _StatCell(label: '无选择器的插件', value: _pluginsWithoutSelectors.length),
                  _StatCell(label: 'ID不规范', value: _invalidIdSelectors.length),
                ],
              ),
            ),
          ),
          if (_invalidIdSelectors.isNotEmpty)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('以下选择器 ID 未遵循 pluginId.name 规范，建议调整：',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    ..._invalidIdSelectors.map(
                      (id) => Text('- $id',
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text('已注册选择器（点击运行调试）', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          ..._grouped.entries.map((entry) => _buildPluginSection(entry.key, entry.value)),
          const SizedBox(height: 8),
          Text('未注册选择器的插件（可新增 data_selectors）',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (_pluginsWithoutSelectors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('所有插件均已注册选择器'),
            )
          else
            Card(
              child: Column(
                children: _pluginsWithoutSelectors
                    .map((id) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.add_circle_outline),
                          title: Text(id),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPluginSection(String pluginId, List<SelectorDefinition> selectors) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(pluginId, style: theme.textTheme.titleSmall),
        subtitle: Text('${selectors.length} 个选择器'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: selectors.map(_buildSelectorTile).toList(),
      ),
    );
  }

  Widget _buildSelectorTile(SelectorDefinition selector) {
    final theme = Theme.of(context);
    final modeText = selector.selectionMode == SelectionMode.single
        ? '单选'
        : '多选${selector.maxSelectionCount > 0 ? '(≤${selector.maxSelectionCount})' : ''}';
    final idValid = selector.id.startsWith('${selector.pluginId}.');

    return ListTile(
      dense: true,
      leading: Icon(
        selector.icon ?? Icons.data_object,
        color: selector.color ?? theme.colorScheme.primary,
      ),
      title: Text(selector.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selector.id,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              _Chip(text: '${selector.stepCount}步'),
              _Chip(text: modeText),
              if (selector.searchable) const _Chip(text: '可搜索'),
              if (!idValid)
                _Chip(
                  text: 'ID不规范',
                  color: theme.colorScheme.error,
                ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => _runSelector(selector),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final int value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: theme.colorScheme.primary)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color? color;

  const _Chip({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: effectiveColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: effectiveColor),
      ),
    );
  }
}
