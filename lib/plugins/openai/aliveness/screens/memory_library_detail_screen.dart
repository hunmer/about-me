import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/openai/aliveness/models/memory_fragment.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';

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

class _MemoryLibraryDetailScreenState extends State<MemoryLibraryDetailScreen> {
  int _tab = 0;
  List<MemoryFragment> _fragments = [];
  List<OpenLoop> _loops = [];
  bool _loading = true;

  final MultiFilterState _fragmentFilters = MultiFilterState();
  final MultiFilterState _loopFilters = MultiFilterState();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fragmentFilters.dispose();
    _loopFilters.dispose();
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
    Toast.error('openai_memoryActionFailed'.trParams({'@error': '$error'}));
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
      'openai_memoryDeleteFragmentTitle'.tr,
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
    final confirmed = await _confirm(
      'openai_memoryDeleteLoopTitle'.tr,
      loop.description,
    );
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
    var saving = false;
    String? errorMessage;
    String? keyError;
    String? valueError;
    final saved = await showDSDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => DSDialog(
          title: (editing
                  ? 'openai_memoryEditFragment'
                  : 'openai_memoryAddFragmentTitle')
              .tr,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DSInput(
                controller: keyController,
                label: editing
                    ? 'openai_memoryKeyReadonlyLabel'.tr
                    : 'openai_memoryKeyLabel'.tr,
                hint: 'openai_memoryKeyHint'.tr,
                enabled: !editing && !saving,
                errorText: keyError,
              ),
              const SizedBox(height: 12),
              DSInput(
                controller: valueController,
                label: 'openai_memoryValueLabel'.tr,
                hint: 'openai_memoryValueHint'.tr,
                enabled: !saving,
                minLines: 1,
                maxLines: 3,
                errorText: valueError,
              ),
              const SizedBox(height: 12),
              DSInput(
                controller: tagsController,
                label: 'openai_memoryTagsLabel'.tr,
                hint: 'openai_memoryTagsHint'.tr,
                enabled: !saving,
              ),
              if (!editing) ...[
                const SizedBox(height: 12),
                Text(
                  'openai_memoryUpsertHint'.tr,
                  style: DsTypography.caption.copyWith(
                    color: AppTheme.of(context).textSub,
                  ),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: DsTypography.caption.copyWith(
                    color: AppTheme.of(context).danger,
                  ),
                ),
              ],
            ],
          ),
          confirmText: saving
              ? 'openai_memorySaving'.tr
              : (editing ? 'app_save' : 'app_add').tr,
          cancelText: 'app_cancel'.tr,
          onConfirm: () async {
            if (saving) return;
            final key = keyController.text.trim();
            final value = valueController.text.trim();
            if (key.isEmpty || value.isEmpty) {
              setDialogState(() {
                keyError = key.isEmpty
                    ? 'openai_memoryKeyRequired'.tr
                    : null;
                valueError = value.isEmpty
                    ? 'openai_memoryValueRequired'.tr
                    : null;
              });
              return;
            }
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
                errorMessage = 'openai_memoryActionFailed'.trParams({
                  '@error': '$error',
                });
              });
            }
          },
          onCancel: () {
            if (!saving) Navigator.of(dialogContext).pop(false);
          },
        ),
      ),
    );
    // pop 结果早于退出动画结束，等输入框卸载后再释放控制器
    await Future.delayed(const Duration(milliseconds: 400));
    keyController.dispose();
    valueController.dispose();
    tagsController.dispose();
    if (!mounted || saved != true) return;
    await _load();
  }

  Future<void> _addLoop() async {
    final descController = TextEditingController();
    var days = 1;
    final confirmed = await showDSDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = AppTheme.of(context);
          return DSDialog(
            title: 'openai_memoryAddLoop'.tr,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DSInput(
                  controller: descController,
                  label: 'openai_memoryLoopDescLabel'.tr,
                  hint: 'openai_memoryLoopDescHint'.tr,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'openai_memoryLoopFollowUpLabel'.tr,
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                    SizedBox(width: theme.spacing.sm),
                    DSSelect<int>(
                      width: 120,
                      value: days,
                      items: [
                        for (final value in [1, 2, 3, 5, 7])
                          DSSelectItem(
                            value: value,
                            label: 'openai_memoryDaysLater'.trParams({
                              '@n': '$value',
                            }),
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
            confirmText: 'app_add'.tr,
            cancelText: 'app_cancel'.tr,
            onConfirm: () =>
                Navigator.of(dialogContext).pop(descController.text.isNotEmpty),
            onCancel: () => Navigator.of(dialogContext).pop(false),
          );
        },
      ),
    );
    await Future.delayed(const Duration(milliseconds: 400));
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

  Future<bool?> _confirm(String title, String body) => showDSDialog<bool>(
    context: context,
    builder: (dialogContext) => DSDialog(
      title: title,
      message: body,
      confirmText: 'app_ok'.tr,
      cancelText: 'app_cancel'.tr,
      confirmVariant: DSButtonVariant.destructive,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onCancel: () => Navigator.of(dialogContext).pop(false),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filteredFragments = _applyFragmentFilters(_fragments);
    final active = filteredFragments
        .where((fragment) => !fragment.archived)
        .toList();
    final archived = filteredFragments
        .where((fragment) => fragment.archived)
        .toList();
    final filteredLoops = _applyLoopFilters(_loops);
    final openLoops = filteredLoops.where((loop) => !loop.closed).toList();

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  DSLightHeader(
                    title: widget.memoryName,
                    trailing: DSIconButton(
                      icon: DsIconKind.plus,
                      size: 38,
                      color: theme.primary,
                      iconColor: theme.onPrimary,
                      onPressed: _tab == 0 ? _addFragment : _addLoop,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.lg,
                    ),
                    child: DSTabs(
                      labels: [
                        'openai_memoryFragmentsTab'.trParams({
                          '@count': '${active.length}',
                        }),
                        'openai_memoryLoopsTab'.trParams({
                          '@count': '${openLoops.length}',
                        }),
                      ],
                      selected: _tab,
                      onChanged: (index) => setState(() => _tab = index),
                    ),
                  ),
                  _buildFilterBar(),
                  Expanded(
                    child: _loading
                        ? Center(child: DSLoadingDots(color: theme.primary))
                        : IndexedStack(
                            index: _tab,
                            children: [
                              _buildFragments(active, archived),
                              _buildLoops(openLoops),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 过滤栏：随 tab 切换碎片/开环两组条件
  Widget _buildFilterBar() {
    if (_tab == 0) {
      return MultiFilterBar(
        filterState: _fragmentFilters,
        filterItems: _buildFragmentFilterItems(),
        onFilterChanged: (_) => setState(() {}),
      );
    }
    return MultiFilterBar(
      filterState: _loopFilters,
      filterItems: [_buildKeywordFilterItem(_loopFilters)],
      onFilterChanged: (_) => setState(() {}),
    );
  }

  static const _statusFilterOptions = {
    'marked': 'openai_memoryFilterMarked',
    'archived': 'openai_memoryFilterArchived',
    'self': 'openai_memoryFilterSelf',
  };

  List<FilterItem> _buildFragmentFilterItems() {
    final availableTags = _fragments
        .expand((fragment) => fragment.tags)
        .toSet()
        .toList()
      ..sort();
    final statusLabels = {
      for (final entry in _statusFilterOptions.entries)
        entry.key: entry.value.tr,
    };
    return [
      _buildKeywordFilterItem(_fragmentFilters),
      FilterItem(
        id: 'tags',
        title: 'openai_memoryFilterTags'.tr,
        type: FilterType.tagsMultiple,
        builder: (context, value, onChanged) => FilterBuilders.buildTagsFilter(
          context: context,
          currentValue: value,
          onChanged: onChanged,
          availableTags: availableTags,
        ),
        getBadge: FilterBuilders.tagsBadge,
      ),
      FilterItem(
        id: 'status',
        title: 'openai_memoryFilterStatus'.tr,
        type: FilterType.tagsSingle,
        builder: (context, value, onChanged) =>
            FilterBuilders.buildSingleChoiceFilter(
              context: context,
              currentValue: value,
              onChanged: onChanged,
              options: statusLabels,
            ),
        getBadge: (value) =>
            FilterBuilders.singleChoiceBadge(value, statusLabels),
      ),
    ];
  }

  FilterItem _buildKeywordFilterItem(MultiFilterState state) {
    return FilterItem(
      id: 'keyword',
      title: 'openai_memoryFilterKeyword'.tr,
      type: FilterType.input,
      builder: (context, value, onChanged) =>
          FilterBuilders.buildKeywordFilter(
            context: context,
            currentValue: value,
            onChanged: onChanged,
            placeholder: 'openai_memoryFilterKeywordPlaceholder'.tr,
          ),
      getBadge: FilterBuilders.keywordBadge,
    );
  }

  List<MemoryFragment> _applyFragmentFilters(List<MemoryFragment> source) {
    final keyword = ((_fragmentFilters.getValue('keyword') as String?) ?? '')
        .trim()
        .toLowerCase();
    final tags = (_fragmentFilters.getValue('tags') as List?)
        ?.cast<String>() ?? const <String>[];
    final status = _fragmentFilters.getValue('status') as String?;
    return source.where((fragment) {
      if (keyword.isNotEmpty &&
          !fragment.key.toLowerCase().contains(keyword) &&
          !fragment.value.toLowerCase().contains(keyword)) {
        return false;
      }
      if (tags.isNotEmpty && !fragment.tags.any(tags.contains)) return false;
      switch (status) {
        case 'marked':
          if (!fragment.userMarked) return false;
        case 'archived':
          if (!fragment.archived) return false;
        case 'self':
          if (!fragment.isSelf) return false;
      }
      return true;
    }).toList();
  }

  List<OpenLoop> _applyLoopFilters(List<OpenLoop> source) {
    final keyword = ((_loopFilters.getValue('keyword') as String?) ?? '')
        .trim()
        .toLowerCase();
    if (keyword.isEmpty) return source;
    return source
        .where((loop) => loop.description.toLowerCase().contains(keyword))
        .toList();
  }

  Widget _buildFragments(
    List<MemoryFragment> active,
    List<MemoryFragment> archived,
  ) {
    if (_fragments.isEmpty) {
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.book,
          title: 'openai_memoryFragmentsEmpty'.tr,
        ),
      );
    }
    if (active.isEmpty && archived.isEmpty) {
      return Center(
        child: DSEmptyState(
          icon: DsIconKind.search,
          title: 'openai_memoryFilterNoMatch'.tr,
        ),
      );
    }
    return _stickyList([
      for (final fragment in active) _buildFragmentCard(fragment),
      if (archived.isNotEmpty) ...[
        _sectionHeader('openai_memoryArchivedSection'.tr, archived.length),
        // 已淡忘条目去掉贴条：不再"贴在板上"呼应归档语义
        for (final fragment in archived)
          _stickyItem(fragment.id, _buildFragmentCard(fragment, dimmed: true),
              showTape: false),
      ],
    ]);
  }

  Widget _buildLoops(List<OpenLoop> openLoops) {
    // 分区同样基于过滤后全集，与 openLoops 数据链路一致
    final closed = _applyLoopFilters(_loops)
        .where((loop) => loop.closed)
        .toList();
    if (openLoops.isEmpty && closed.isEmpty) {
      return Center(
        child: DSEmptyState(
          icon: _loops.isEmpty ? DsIconKind.clock : DsIconKind.search,
          title: _loops.isEmpty
              ? 'openai_memoryLoopsEmpty'.tr
              : 'openai_memoryFilterNoMatch'.tr,
        ),
      );
    }
    return _stickyList([
      for (final loop in openLoops) _buildOpenLoopCard(loop),
      if (closed.isNotEmpty) ...[
        _sectionHeader('openai_memoryClosedSection'.tr, closed.length),
        for (final loop in closed)
          _stickyItem(
            loop.id,
            _buildClosedLoopCard(loop),
            showTape: false,
          ),
      ],
    ]);
  }

  /// 便签化滚动列表：CustomScrollView + SliverList，
  /// 数据卡由 [_stickyItem] 包裹便签化，分区标题保持平直
  Widget _stickyList(List<Widget> children) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                theme.spacing.lg,
                12, // 贴条顶部出血
                theme.spacing.lg,
                MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(children),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stickyItem(String id, Widget child, {bool showTape = true}) {
    return HandDrawnStickyItem(
      tiltKey: id,
      showTape: showTape,
      child: child,
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Padding(
          padding: EdgeInsets.only(
            top: theme.spacing.lg,
            bottom: theme.spacing.sm,
          ),
          child: Text(
            '$label ($count)',
            style: DsTypography.body.copyWith(color: theme.textSub),
          ),
        );
      },
    );
  }

  Widget _buildFragmentCard(MemoryFragment fragment, {bool dimmed = false}) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSCard(
          color: dimmed ? theme.surfaceAlt : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DSIconButton(
                    icon: fragment.userMarked
                        ? DsIconKind.star
                        : DsIconKind.starOutline,
                    size: 34,
                    color: theme.surface,
                    iconColor: fragment.userMarked
                        ? theme.primary
                        : theme.textSub,
                    tooltip: fragment.userMarked
                        ? 'openai_memoryUnmarkImportant'.tr
                        : 'openai_memoryMarkImportant'.tr,
                    onPressed: () => _toggleMarked(fragment),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      fragment.key,
                      style: DsTypography.title.copyWith(
                        color: dimmed ? theme.textSub : theme.text,
                      ),
                    ),
                  ),
                  DSIconButton(
                    icon: DsIconKind.edit,
                    size: 34,
                    color: theme.surface,
                    iconColor: theme.textSub,
                    onPressed: () => _editFragment(fragment),
                  ),
                  DSIconButton(
                    icon: DsIconKind.trash,
                    size: 34,
                    color: theme.surface,
                    iconColor: theme.danger,
                    onPressed: () => _deleteFragment(fragment),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                fragment.value,
                style: DsTypography.body.copyWith(
                  color: dimmed ? theme.textSub : theme.text,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                [
                  if (fragment.isSelf) 'openai_memorySelfMemory'.tr,
                  if (fragment.tags.isNotEmpty)
                    fragment.tags.take(4).join(' / '),
                  'openai_memoryVersion'.trParams({
                    '@n': '${fragment.revision}',
                  }),
                  'openai_memoryUpdatedAt'.trParams({
                    '@date': _formatDate(fragment.updatedAt),
                  }),
                  if (fragment.archived) 'openai_memoryArchived'.tr,
                  if (fragment.activateCount > 0)
                    'openai_memoryActivated'.trParams({
                      '@n': '${fragment.activateCount}',
                    }),
                ].join(' · '),
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpenLoopCard(OpenLoop loop) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DSIconButton(
                    icon: DsIconKind.check,
                    size: 34,
                    color: theme.surface,
                    iconColor: theme.primary,
                    tooltip: 'openai_memoryMarkFollowed'.tr,
                    onPressed: () => _closeLoop(loop),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      loop.description,
                      style: DsTypography.title.copyWith(color: theme.text),
                    ),
                  ),
                  DSIconButton(
                    icon: DsIconKind.trash,
                    size: 34,
                    color: theme.surface,
                    iconColor: theme.danger,
                    onPressed: () => _deleteLoop(loop),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                [
                  'openai_memoryLoopCreatedAt'.trParams({
                    '@date': _formatDate(loop.createdAt),
                  }),
                  if (loop.followUpBy != null)
                    'openai_memoryLoopFollowUp'.trParams({
                      '@date': _formatDate(loop.followUpBy!),
                    }),
                ].join(' · '),
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClosedLoopCard(OpenLoop loop) {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return DSCard(
          color: theme.surfaceAlt,
          child: Row(
            children: [
              DsIcon(DsIconKind.check, size: 18, color: theme.primary),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  loop.description,
                  style: DsTypography.body.copyWith(color: theme.textSub),
                ),
              ),
              DSIconButton(
                icon: DsIconKind.trash,
                size: 34,
                color: theme.surfaceAlt,
                iconColor: theme.danger,
                onPressed: () => _deleteLoop(loop),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}';
}
