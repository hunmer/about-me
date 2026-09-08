import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/screens/agent_resource_list_screen.dart';
import 'package:aboutme/plugins/openai/services/agent_resource_store_service.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:flutter/material.dart';

class AgentResourceStoreScreen extends StatefulWidget {
  const AgentResourceStoreScreen({
    super.key,
    required this.type,
    required this.installed,
    required this.onInstalled,
  });

  final AgentResourceType type;
  final List<AgentResourceItem> installed;
  final ValueChanged<AgentResourceItem> onInstalled;

  @override
  State<AgentResourceStoreScreen> createState() =>
      _AgentResourceStoreScreenState();
}

class _AgentResourceStoreScreenState extends State<AgentResourceStoreScreen> {
  List<AgentResourceStoreItem> _items = const [];
  String _query = '';
  Map<String, dynamic> _filters = {};
  final Set<String> _installedIds = {};
  final Set<String> _installingIds = {};
  bool _loading = true;
  String? _error;

  bool get _isSkills => widget.type == AgentResourceType.skills;

  @override
  void initState() {
    super.initState();
    _installedIds.addAll(widget.installed.map((resource) => resource.id));
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await AgentResourceStoreService.load(
        widget.type,
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _installed(AgentResourceStoreItem item) =>
      _installedIds.contains(item.id);

  Future<void> _install(AgentResourceStoreItem item) async {
    if (_installingIds.contains(item.id) || _installed(item)) return;
    setState(() => _installingIds.add(item.id));
    try {
      final content = await AgentResourceStoreService.fetchContent(item);
      widget.onInstalled(item.toResource(content));
      _installedIds.add(item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${item.name} 已安装')));
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('安装失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _installingIds.remove(item.id));
    }
  }

  Future<void> _showDetails(AgentResourceStoreItem item) async {
    final installed = _installed(item);
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(item.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.description.isNotEmpty) Text(item.description),
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('标签：${item.tags.join(' · ')}'),
                  ],
                  if (item.updatedAt?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('更新时间：${item.updatedAt}'),
                  ],
                  if (item.needsEnv.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('需要环境变量：${item.needsEnv.join(', ')}'),
                  ],
                  const SizedBox(height: 8),
                  SelectableText(item.contentUrl),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('关闭'),
              ),
              if (!installed)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _install(item);
                  },
                  child: const Text('安装'),
                ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSkills ? 'Skills 商店' : 'MCP 商店';
    final visible =
        _items.where((item) {
          final query = _query.trim().toLowerCase();
          final tags =
              (_filters['tags'] as List<dynamic>?)?.cast<String>() ?? const [];
          final queryMatch =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              item.tags.any((tag) => tag.toLowerCase().contains(query));
          return queryMatch && (tags.isEmpty || item.tags.any(tags.contains));
        }).toList();
    final availableTags =
        _items.expand((item) => item.tags).toSet().toList()..sort();
    return SuperCupertinoNavigationWrapper(
      title: Text(title),
      largeTitle: title,
      enableSearchBar: true,
      searchPlaceholder: '搜索$title',
      onSearchChanged: (value) => setState(() => _query = value),
      enableMultiFilter: _isSkills && availableTags.isNotEmpty,
      multiFilterItems: [
        if (_isSkills)
          FilterItem(
            id: 'tags',
            title: '标签',
            type: FilterType.tagsMultiple,
            builder:
                (context, value, onChanged) => FilterBuilders.buildTagsFilter(
                  context: context,
                  currentValue: value,
                  onChanged: onChanged,
                  availableTags: availableTags,
                ),
            getBadge: FilterBuilders.tagsBadge,
          ),
      ],
      onMultiFilterChanged: (filters) => setState(() => _filters = filters),
      actions: [
        DSIconButton(
          icon: DsIconKind.refresh,
          tooltip: '刷新',
          onPressed: () => _load(forceRefresh: true),
        ),
      ],
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final item = visible[index];
                  final installed = _installed(item);
                  final installing = _installingIds.contains(item.id);
                  return ListTile(
                    onTap: () => _showDetails(item),
                    title: Text(item.name),
                    subtitle: Text(
                      [
                        if (item.description.isNotEmpty) item.description,
                        if (item.tags.isNotEmpty) item.tags.join(' · '),
                        if (item.needsEnv.isNotEmpty)
                          '需要环境变量: ${item.needsEnv.join(', ')}',
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        installed
                            ? const Chip(label: Text('已安装'))
                            : FilledButton(
                              onPressed:
                                  installing ? null : () => _install(item),
                              child:
                                  installing
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('安装'),
                            ),
                  );
                },
              ),
    );
  }
}
