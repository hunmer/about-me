import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_library.dart';
import 'package:aboutme/plugins/openai/aliveness/screens/memory_library_detail_screen.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';

/// 记忆库管理页：创建、查看和选择 agent 要使用的独立记忆库。
class MemoryManagerScreen extends StatefulWidget {
  final AlivenessConfig? config;
  final ValueChanged<AlivenessConfig>? onConfigChanged;

  const MemoryManagerScreen({super.key, this.config, this.onConfigChanged});

  @override
  State<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends State<MemoryManagerScreen> {
  List<MemoryLibrary> _libraries = const [];
  late Set<String> _selectedIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = {...?widget.config?.memoryIds};
    _load();
  }

  Future<void> _load() async {
    try {
      final libraries = await AlivenessStore.instance.loadMemoryLibraries();
      if (!mounted) return;
      setState(() {
        _libraries = libraries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastService.instance.showToast('加载记忆库失败：$error');
    }
  }

  void _toggleLibrary(MemoryLibrary library, bool enabled) {
    setState(() {
      if (enabled) {
        _selectedIds.add(library.id);
      } else {
        _selectedIds.remove(library.id);
      }
    });
    final config = widget.config;
    final onChanged = widget.onConfigChanged;
    if (config != null && onChanged != null) {
      onChanged(config.copyWith(memoryIds: _selectedIds.toList()));
    }
  }

  Future<void> _createLibrary() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建记忆库'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '例如：工作与计划',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      await AlivenessStore.instance.createMemoryLibrary(name.trim());
      await _load();
    } catch (error) {
      if (mounted) ToastService.instance.showToast('创建记忆库失败：$error');
    }
  }

  Future<void> _copyId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) ToastService.instance.showToast('记忆库 ID 已复制');
  }

  @override
  Widget build(BuildContext context) {
    final canSelect = widget.config != null && widget.onConfigChanged != null;
    return Scaffold(
      appBar: AppBar(title: const Text('记忆库')),
      body: Column(
        children: [
          if (canSelect)
            const MaterialBanner(
              content: Text('选择供当前 agent 使用的库；返回编辑页保存生效'),
              actions: [SizedBox.shrink()],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _libraries.isEmpty
                ? const Center(
                    child: Text(
                      '暂无记忆库\n创建后可由多个 agent 共同使用',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: _libraries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final library = _libraries[index];
                      final selected = _selectedIds.contains(library.id);
                      return Card(
                        child: ListTile(
                          leading: canSelect
                              ? Checkbox(
                                  value: selected,
                                  onChanged: (value) =>
                                      _toggleLibrary(library, value ?? false),
                                )
                              : const Icon(Icons.storage_outlined),
                          title: Text(library.name),
                          subtitle: Text(
                            'ID: ${library.id}\n创建于 ${_formatDate(library.createdAt)}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'copy') _copyId(library.id);
                              if (action == 'open') {
                                NavigationHelper.push(
                                  context,
                                  MemoryLibraryDetailScreen(
                                    memoryId: library.id,
                                    memoryName: library.name,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'open', child: Text('打开')),
                              PopupMenuItem(
                                value: 'copy',
                                child: Text('复制 ID'),
                              ),
                            ],
                          ),
                          onTap: () => NavigationHelper.push(
                            context,
                            MemoryLibraryDetailScreen(
                              memoryId: library.id,
                              memoryName: library.name,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLibrary,
        icon: const Icon(Icons.add),
        label: const Text('新建记忆库'),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
