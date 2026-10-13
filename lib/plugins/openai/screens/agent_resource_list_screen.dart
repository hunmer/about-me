import 'dart:convert';

import 'package:agentlib/agent_slots.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/screens/agent_resource_store_screen.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_builders.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:get/get.dart';
enum AgentResourceType { skills, mcpServers }

class AgentResourceListScreen extends StatefulWidget {
  const AgentResourceListScreen({
    super.key,
    required this.type,
    required this.resources,
    required this.onChanged,
  });

  final AgentResourceType type;
  final List<AgentResourceItem> resources;
  final ValueChanged<List<AgentResourceItem>> onChanged;

  @override
  State<AgentResourceListScreen> createState() =>
      _AgentResourceListScreenState();
}

class _AgentResourceListScreenState extends State<AgentResourceListScreen> {
  late List<AgentResourceItem> _resources;
  Map<String, dynamic> _filters = {};
  String _query = '';

  bool get _isSkills => widget.type == AgentResourceType.skills;

  @override
  void initState() {
    super.initState();
    _resources = List.of(widget.resources);
  }

  List<AgentResourceItem> get _visibleResources {
    final status = _filters['status'] as Map<String, bool>? ?? {};
    final tags =
        (_filters['tags'] as List<dynamic>?)?.cast<String>() ?? const [];
    return _resources.where((item) {
      final query = _query.trim().toLowerCase();
      final queryMatch =
          query.isEmpty ||
          item.displayName.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query) ||
          item.tags.any((tag) => tag.toLowerCase().contains(query));
      final statusMatch =
          status.isEmpty ||
          (status['enabled'] == true && item.enabled) ||
          (status['disabled'] == true && !item.enabled);
      final tagMatch = tags.isEmpty || item.tags.any(tags.contains);
      return queryMatch && statusMatch && tagMatch;
    }).toList();
  }

  List<FilterItem> get _filterItems {
    final tags =
        _resources.expand((item) => item.tags).toSet().toList()..sort();
    return [
      FilterItem(
        id: 'status',
        title: '启用状态',
        type: FilterType.checkbox,
        initialValue: const {'enabled': true, 'disabled': true},
        builder:
            (context, value, onChanged) => FilterBuilders.buildCheckboxFilter(
              context: context,
              currentValue: value,
              onChanged: onChanged,
              options: const {'enabled': '已启用', 'disabled': '已停用'},
            ),
        getBadge: FilterBuilders.checkboxBadge,
      ),
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
                availableTags: tags,
              ),
          getBadge: FilterBuilders.tagsBadge,
        ),
    ];
  }

  void _toggle(AgentResourceItem item) {
    final index = _resources.indexWhere((entry) => entry.id == item.id);
    _resources[index] = item.copyWith(enabled: !item.enabled);
    widget.onChanged(List.of(_resources));
    setState(() {});
  }

  void _addResource() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isSkills ? '添加 Skill' : '添加 MCP Server'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_cancel'.tr),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text('app_add'.tr),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    if (_resources.any((item) => item.id == value.trim())) return;
    _resources.add(AgentResourceItem(id: value.trim()));
    widget.onChanged(List.of(_resources));
    setState(() {});
  }

  Future<void> _importLocalSkill() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown', 'txt'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    final id = file.name;
    if (_resources.any((item) => item.id == id)) return;
    _resources.add(
      AgentResourceItem(
        id: id,
        name: id.replaceFirst(RegExp(r'\.(md|markdown|txt)$'), ''),
        content: utf8.decode(file.bytes!),
      ),
    );
    widget.onChanged(List.of(_resources));
    setState(() {});
  }

  Future<void> _importSkillFromUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('openai_importSkillFromUrl'.tr),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://example.com/skill.md',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_cancel'.tr),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text('app_import'.tr),
              ),
            ],
          ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final id = uri.toString();
      if (_resources.any((item) => item.id == id)) return;
      _resources.add(
        AgentResourceItem(
          id: id,
          name: uri.pathSegments.isEmpty ? id : uri.pathSegments.last,
          content: response.body,
        ),
      );
      widget.onChanged(List.of(_resources));
      setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    }
  }

  Future<void> _editResource(AgentResourceItem item) async {
    final nameController = TextEditingController(text: item.name ?? item.id);
    final tagsController = TextEditingController(text: item.tags.join(', '));
    final edited = await showDialog<AgentResourceItem>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('openai_editResource'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                if (_isSkills)
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(labelText: 'Tags（逗号分隔）'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('app_cancel'.tr),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      item.copyWith(
                        name: nameController.text.trim(),
                        tags:
                            tagsController.text
                                .split(',')
                                .map((tag) => tag.trim())
                                .where((tag) => tag.isNotEmpty)
                                .toSet()
                                .toList(),
                      ),
                    ),
                child: Text('app_save'.tr),
              ),
            ],
          ),
    );
    nameController.dispose();
    tagsController.dispose();
    if (edited == null) return;
    final index = _resources.indexWhere((entry) => entry.id == item.id);
    _resources[index] = edited;
    widget.onChanged(List.of(_resources));
    setState(() {});
  }

  Future<void> _showAddMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('openai_addManually'.tr),
                  onTap: () => Navigator.pop(context, 'manual'),
                ),
                if (_isSkills)
                  ListTile(
                    leading: const Icon(Icons.file_open),
                    title: Text('openai_importSkillFromLocal'.tr),
                    onTap: () => Navigator.pop(context, 'local'),
                  ),
                if (_isSkills)
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text('openai_importSkillFromUrl'.tr),
                    onTap: () => Navigator.pop(context, 'url'),
                  ),
              ],
            ),
          ),
    );
    switch (action) {
      case 'manual':
        _addResource();
      case 'local':
        _importLocalSkill();
      case 'url':
        _importSkillFromUrl();
    }
  }

  void _openStore() {
    NavigationHelper.push(
      context,
      AgentResourceStoreScreen(
        type: widget.type,
        installed: _resources,
        onInstalled: (resource) {
          final index = _resources.indexWhere((item) => item.id == resource.id);
          if (index >= 0) {
            _resources[index] = resource;
          } else {
            _resources.add(resource);
          }
          widget.onChanged(List.of(_resources));
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSkills ? 'Skills' : 'MCP Servers';
    return SuperCupertinoNavigationWrapper(
      title: Text(title),
      largeTitle: title,
      enableSearchBar: true,
      searchPlaceholder: '搜索$title',
      onSearchChanged: (value) => setState(() => _query = value),
      enableMultiFilter: true,
      multiFilterItems: _filterItems,
      onMultiFilterChanged: (filters) => setState(() => _filters = filters),
      actions: [
        DSIconButton(
          icon: DsIconKind.store,
          tooltip: '打开商店',
          onPressed: _openStore,
        ),
        DSIconButton(
          icon: DsIconKind.plus,
          tooltip: '添加',
          onPressed: _showAddMenu,
        ),
      ],
      body: ListView.builder(
        itemCount: _visibleResources.length,
        itemBuilder: (context, index) {
          final item = _visibleResources[index];
          return ListTile(
            onTap: () => _editResource(item),
            title: Text(item.displayName),
            subtitle:
                item.tags.isEmpty ? Text(item.id) : Text(item.tags.join(' · ')),
            trailing: Switch.adaptive(
              value: item.enabled,
              onChanged: (_) => _toggle(item),
            ),
          );
        },
      ),
    );
  }
}
