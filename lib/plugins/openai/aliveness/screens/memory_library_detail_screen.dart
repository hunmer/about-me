import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';

/// 单个记忆库的碎片与开环事件管理页。
class MemoryLibraryDetailScreen extends StatefulWidget {
  final String memoryId;
  final String memoryName;

  const MemoryLibraryDetailScreen({
    super.key,
    required this.memoryId,
    required this.memoryName,
  });

  @override
  State<MemoryLibraryDetailScreen> createState() =>
      _MemoryLibraryDetailScreenState();
}

class _MemoryLibraryDetailScreenState extends State<MemoryLibraryDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<MemoryFragment> _fragments = [];
  List<OpenLoop> _loops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final memory = MemoryService.instance;
      final fragments = await memory.loadFragments(widget.memoryId);
      final loops = await memory.loadOpenLoops(widget.memoryId);
      if (!mounted) return;
      fragments.sort((a, b) {
        if (a.userMarked != b.userMarked) return a.userMarked ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      setState(() {
        _fragments = fragments;
        _loops = loops;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showError(error);
      await _load();
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
  }

  Future<void> _toggleMarked(MemoryFragment fragment) {
    return _runAction(() async {
      final memory = MemoryService.instance;
      if (fragment.userMarked) {
        await memory.unmarkFragment(widget.memoryId, fragment.id);
      } else {
        await memory.markFragmentImportant(widget.memoryId, fragment.id);
      }
    });
  }

  Future<void> _deleteFragment(MemoryFragment fragment) async {
    final confirmed = await _confirm(
      '删除这条记忆？',
      '${fragment.key}\n${fragment.value}',
    );
    if (confirmed != true) return;
    await _runAction(
      () => MemoryService.instance.deleteFragment(widget.memoryId, fragment.id),
    );
  }

  Future<void> _closeLoop(OpenLoop loop) {
    return _runAction(() async {
      loop.closed = true;
      await MemoryService.instance.saveOpenLoops(widget.memoryId, _loops);
    });
  }

  Future<void> _deleteLoop(OpenLoop loop) async {
    final confirmed = await _confirm('删除这个开环事件？', loop.description);
    if (confirmed != true) return;
    await _runAction(() async {
      _loops.removeWhere((item) => item.id == loop.id);
      await MemoryService.instance.saveOpenLoops(widget.memoryId, _loops);
    });
  }

  Future<void> _addFragment() => _editFragment();

  Future<void> _editFragment([MemoryFragment? fragment]) async {
    final editing = fragment != null;
    final keyController = TextEditingController(text: fragment?.key);
    final valueController = TextEditingController(text: fragment?.value);
    final tagsController = TextEditingController(
      text: fragment?.tags.join(', '),
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? errorMessage;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: Text(editing ? '编辑记忆' : '添加记忆碎片'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: keyController,
                    readOnly: editing,
                    enabled: !saving,
                    autofocus: !editing,
                    decoration: InputDecoration(
                      labelText: 'Key（必填）',
                      hintText: '例如：user.language',
                      helperText: editing ? 'Key 不可修改' : null,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入 key'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: valueController,
                    enabled: !saving,
                    autofocus: editing,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Value（必填）',
                      hintText: '例如：简体中文',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请输入 value'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: tagsController,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: '标签（可选）',
                      hintText: '用逗号分隔，例如：工作,面试',
                    ),
                  ),
                  if (!editing) ...[
                    const SizedBox(height: 12),
                    const Text('同一记忆库中，已有相同 key 时将覆盖其 value 和标签。'),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final key = keyController.text.trim();
                        final value = valueController.text.trim();
                        final tags = tagsController.text
                            .split(RegExp(r'[,，]'))
                            .map((tag) => tag.trim())
                            .where((tag) => tag.isNotEmpty)
                            .toList();
                        setDialogState(() {
                          saving = true;
                          errorMessage = null;
                        });
                        try {
                          final memory = MemoryService.instance;
                          if (editing) {
                            await memory.updateByKey(
                              widget.memoryId,
                              key,
                              value,
                              tags,
                              source: 'manual',
                            );
                          } else {
                            await memory.upsertForTool(
                              widget.memoryId,
                              key,
                              value,
                              tags,
                              source: 'manual',
                            );
                          }
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(true);
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            saving = false;
                            errorMessage = '操作失败：$error';
                          });
                        }
                      },
                child: Text(saving ? '保存中…' : (editing ? '保存' : '添加')),
              ),
            ],
          ),
        ),
      ),
    );
    bool? saved;
    try {
      saved = await navigator.push(route);
    } finally {
      // pop 的结果早于退出动画结束，输入框卸载后才能释放控制器。
      await route.completed;
      keyController.dispose();
      valueController.dispose();
      tagsController.dispose();
    }
    if (!mounted || saved != true) return;
    await _load();
  }

  Future<void> _addLoop() async {
    final descController = TextEditingController();
    var days = 1;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<bool>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('添加后续事件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '事件描述',
                  hintText: '例如：用户周五要体检',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('跟进时间：'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: days,
                    items: [
                      for (final value in [1, 2, 3, 5, 7])
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value 天后'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => days = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    final confirmed = await navigator.push(route);
    await route.completed;
    final description = descController.text.trim();
    descController.dispose();
    if (!mounted || confirmed != true || description.isEmpty) return;
    await _runAction(
      () => MemoryService.instance.addOpenLoop(
        widget.memoryId,
        description,
        followUpDays: days,
      ),
    );
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final active = _fragments.where((fragment) => !fragment.archived).toList();
    final archived = _fragments.where((fragment) => fragment.archived).toList();
    final openLoops = _loops.where((loop) => !loop.closed).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memoryName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '记忆碎片 (${active.length})'),
            Tab(text: '开环事件 (${openLoops.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tabController.index == 0 ? _addFragment : _addLoop,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? '添加碎片' : '添加事件'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFragments(active, archived),
                _buildLoops(openLoops),
              ],
            ),
    );
  }

  Widget _buildFragments(
    List<MemoryFragment> active,
    List<MemoryFragment> archived,
  ) {
    if (_fragments.isEmpty) {
      return const Center(child: Text('暂无记忆碎片'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final fragment in active) _buildFragmentTile(fragment),
        if (archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text('已淡忘 (${archived.length})'),
          ),
          for (final fragment in archived)
            _buildFragmentTile(fragment, dimmed: true),
        ],
      ],
    );
  }

  Widget _buildFragmentTile(MemoryFragment fragment, {bool dimmed = false}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: dimmed ? theme.disabledColor.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            fragment.userMarked ? Icons.star : Icons.star_border,
            color: fragment.userMarked ? Colors.amber : theme.disabledColor,
          ),
          tooltip: fragment.userMarked ? '取消重要标记' : '标记为重要',
          onPressed: () => _toggleMarked(fragment),
        ),
        title: Text(
          fragment.key,
          style: TextStyle(color: dimmed ? theme.disabledColor : null),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fragment.value,
              style: TextStyle(color: dimmed ? theme.disabledColor : null),
            ),
            Text(
              [
                if (fragment.isSelf) '自我记忆',
                if (fragment.tags.isNotEmpty) fragment.tags.take(4).join(' / '),
                '版本 ${fragment.revision}',
                '更新于 ${_formatDate(fragment.updatedAt)}',
                if (fragment.archived) '已淡忘',
                if (fragment.activateCount > 0)
                  '想起过 ${fragment.activateCount} 次',
              ].join(' · '),
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
              onPressed: () => _editFragment(fragment),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.disabledColor),
              tooltip: '删除',
              onPressed: () => _deleteFragment(fragment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoops(List<OpenLoop> openLoops) {
    final closed = _loops.where((loop) => loop.closed).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (openLoops.isEmpty) const Center(child: Text('暂无待跟进事件')),
        for (final loop in openLoops)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: Text(loop.description),
              subtitle: Text(
                '记录于 ${_formatDate(loop.createdAt)}'
                '${loop.followUpBy != null ? ' · 建议 ${_formatDate(loop.followUpBy!)} 跟进' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: '标记已跟进',
                    onPressed: () => _closeLoop(loop),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除',
                    onPressed: () => _deleteLoop(loop),
                  ),
                ],
              ),
            ),
          ),
        if (closed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text('已跟进 (${closed.length})'),
          ),
          for (final loop in closed)
            Card(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text(loop.description),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteLoop(loop),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}';
}
