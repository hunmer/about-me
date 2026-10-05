import 'package:flutter/material.dart';

import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';

/// 记忆碎片管理页：查看/手动标记重要/删除碎片，管理开环事件。
/// 对应 PRD「人工可标记重要记忆」与记忆可观测性。
class MemoryManagerScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const MemoryManagerScreen({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends State<MemoryManagerScreen>
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
      if (mounted) setState(() {}); // 切 Tab 时刷新 FAB 显隐
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final memory = MemoryService.instance;
    final fragments = await memory.loadFragments(widget.agentId);
    final loops = await memory.loadOpenLoops(widget.agentId);
    if (!mounted) return;
    setState(() {
      // 重要度优先，同级新的在前
      fragments.sort((a, b) {
        if (a.userMarked != b.userMarked) return a.userMarked ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      _fragments = fragments;
      _loops = loops;
      _loading = false;
    });
  }

  Future<void> _toggleMarked(MemoryFragment fragment) async {
    final memory = MemoryService.instance;
    if (fragment.userMarked) {
      await memory.unmarkFragment(widget.agentId, fragment.id);
    } else {
      await memory.markFragmentImportant(widget.agentId, fragment.id);
    }
    _load();
  }

  Future<void> _deleteFragment(MemoryFragment fragment) async {
    final confirmed = await _confirm('删除这条记忆？', fragment.content);
    if (confirmed != true) return;
    await MemoryService.instance.deleteFragment(widget.agentId, fragment.id);
    _load();
  }

  Future<void> _closeLoop(OpenLoop loop) async {
    loop.closed = true;
    await MemoryService.instance.saveOpenLoops(widget.agentId, _loops);
    _load();
  }

  Future<void> _deleteLoop(OpenLoop loop) async {
    final confirmed = await _confirm('删除这个开环事件？', loop.description);
    if (confirmed != true) return;
    _loops.removeWhere((l) => l.id == loop.id);
    await MemoryService.instance.saveOpenLoops(widget.agentId, _loops);
    _load();
  }

  /// 手动录入开环事件（如"周五体检"），到期后 AI 会主动跟进
  Future<void> _addLoop() async {
    final descCtrl = TextEditingController();
    var days = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('添加待跟进事件'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
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
                      for (final d in [1, 2, 3, 5, 7])
                        DropdownMenuItem(value: d, child: Text('$d 天后')),
                    ],
                    onChanged: (v) =>
                        v != null ? setDlgState(() => days = v) : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final desc = descCtrl.text.trim();
    if (desc.isEmpty) return;
    await MemoryService.instance.addOpenLoop(
      widget.agentId,
      desc,
      followUpDays: days,
    );
    _load();
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active =
        _fragments.where((f) => !f.archived).toList();
    final archived = _fragments.where((f) => f.archived).toList();
    final openLoops = _loops.where((l) => !l.closed).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('记忆管理 · ${widget.agentName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '记忆碎片 (${active.length})'),
            Tab(text: '开环事件 (${openLoops.length})'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _addLoop,
              icon: const Icon(Icons.add),
              label: const Text('添加事件'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFragmentsTab(theme, active, archived),
                _buildLoopsTab(theme, openLoops),
              ],
            ),
    );
  }

  Widget _buildFragmentsTab(
    ThemeData theme,
    List<MemoryFragment> active,
    List<MemoryFragment> archived,
  ) {
    if (_fragments.isEmpty) {
      return Center(
        child: Text(
          '暂无记忆\n与该 AI 聊天后会自动积累记忆碎片',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.disabledColor,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final f in active) _buildFragmentTile(theme, f),
        if (archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              '已淡忘 (${archived.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ),
          for (final f in archived)
            _buildFragmentTile(theme, f, dimmed: true),
        ],
      ],
    );
  }

  Widget _buildFragmentTile(ThemeData theme, MemoryFragment f,
      {bool dimmed = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: dimmed ? theme.disabledColor.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            f.userMarked ? Icons.star : Icons.star_border,
            color: f.userMarked ? Colors.amber : theme.disabledColor,
          ),
          tooltip: f.userMarked ? '取消重要标记' : '标记为重要（永不淡忘）',
          onPressed: () => _toggleMarked(f),
        ),
        title: Text(
          f.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: dimmed ? theme.disabledColor : null,
          ),
        ),
        subtitle: Text(
          [
            if (f.isSelf) '自我记忆',
            if (f.tags.isNotEmpty) f.tags.take(4).join(' / '),
            _formatDate(f.createdAt),
            if (f.archived) '已淡忘',
            if (f.activateCount > 0) '想起过 ${f.activateCount} 次',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.disabledColor,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: theme.disabledColor),
          tooltip: '删除',
          onPressed: () => _deleteFragment(f),
        ),
      ),
    );
  }

  Widget _buildLoopsTab(ThemeData theme, List<OpenLoop> openLoops) {
    final closed = _loops.where((l) => l.closed).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (openLoops.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                '暂无待跟进事件\nAI 记下你的面试/约会/出行等安排后会出现在这里',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ),
          ),
        for (final l in openLoops)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: Text(l.description),
              subtitle: Text(
                '记录于 ${_formatDate(l.createdAt)}'
                '${l.followUpBy != null ? ' · 建议 ${_formatDate(l.followUpBy!)} 跟进' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    tooltip: '标记已跟进（AI 不再主动提起）',
                    onPressed: () => _closeLoop(l),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.disabledColor,
                    ),
                    tooltip: '删除',
                    onPressed: () => _deleteLoop(l),
                  ),
                ],
              ),
            ),
          ),
        if (closed.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              '已跟进 (${closed.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ),
          for (final l in closed)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: theme.disabledColor.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.check_circle, size: 20),
                title: Text(
                  l.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.disabledColor,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.disabledColor,
                  ),
                  onPressed: () => _deleteLoop(l),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}';
}
