part of 'notes_plugin.dart';

// ==================== 数据选择器注册 ====================

void _registerDataSelectors() {
  // 注册笔记选择器
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'notes.note',
      pluginId: NotesPlugin.instance.id,
      name: '选择笔记',
      icon: NotesPlugin.instance.icon,
      color: NotesPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'note',
          title: '选择笔记',
          viewType: SelectorViewType.list,
          isFinalStep: true,
          dataLoader: (_) async {
            if (!NotesPlugin.instance._isInitialized) return [];

            // 获取所有笔记
            final allNotes = NotesPlugin.instance.controller.searchNotes(
              query: '',
            );

            // 构建文件夹路径映射
            final folderPaths = <String, String>{};
            for (final folder
                in NotesPlugin.instance.controller.getAllFolders()) {
              folderPaths[folder.id] = _buildFolderPath(folder.id);
            }

            return allNotes.map((note) {
              final folderPath = folderPaths[note.folderId] ?? '';
              return SelectableItem(
                id: note.id,
                title: note.title,
                subtitle: folderPath.isNotEmpty ? '📁 $folderPath' : null,
                icon: Icons.note_outlined,
                rawData: note,
              );
            }).toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              return item.title.toLowerCase().contains(lowerQuery) ||
                  (item.subtitle?.toLowerCase().contains(lowerQuery) ?? false);
            }).toList();
          },
        ),
      ],
    ),
  );

  // 注册文件夹选择器
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'notes.folder',
      pluginId: NotesPlugin.instance.id,
      name: 'notes_folderSelectorName'.tr,
      description: 'notes_folderSelectorDesc'.tr,
      icon: Icons.folder,
      color: NotesPlugin.instance.color,
      searchable: true,
      selectionMode: SelectionMode.single,
      steps: [
        SelectorStep(
          id: 'select_folder',
          title: 'notes_selectFolderTitle'.tr,
          viewType: SelectorViewType.list,
          dataLoader: (previousSelections) async {
            if (!NotesPlugin.instance._isInitialized) return [];

            // 获取所有文件夹（不包括 root）
            final allFolders =
                NotesPlugin.instance.controller
                    .getAllFolders()
                    .where((folder) => folder.id != 'root')
                    .toList();

            return allFolders.map((folder) {
              // 获取文件夹中的笔记数量
              final notesCount =
                  NotesPlugin.instance.controller
                      .getFolderNotes(folder.id)
                      .length;

              // 构建文件夹路径
              final folderPath = _buildFolderPath(folder.id);

              return SelectableItem(
                id: folder.id,
                title: folder.name,
                subtitle: '$folderPath • $notesCount ${'notes_notesCount'.tr}',
                icon: folder.icon,
                color: folder.color,
                rawData: {
                  'id': folder.id,
                  'name': folder.name,
                  'parentId': folder.parentId,
                  'notesCount': notesCount,
                  'folderPath': folderPath,
                  'icon': folder.icon.codePoint,
                  'color': folder.color.value,
                },
              );
            }).toList();
          },
          searchFilter: (items, query) {
            if (query.isEmpty) return items;
            final lowerQuery = query.toLowerCase();
            return items.where((item) {
              return item.title.toLowerCase().contains(lowerQuery) ||
                  (item.subtitle?.toLowerCase().contains(lowerQuery) ?? false);
            }).toList();
          },
          isFinalStep: true,
        ),
      ],
    ),
  );

  // 注册笔记列表配置选择器（选择文件夹、标签、日期范围）
  pluginDataSelectorService.registerSelector(
    SelectorDefinition(
      id: 'notes.list.config',
      pluginId: NotesPlugin.instance.id,
      name: 'notes_listConfigSelectorName'.tr,
      description: 'notes_listConfigSelectorDesc'.tr,
      icon: Icons.tune,
      color: NotesPlugin.instance.color,
      searchable: false,
      selectionMode: SelectionMode.single,
      steps: [
        // 使用自定义表单完成所有配置
        SelectorStep(
          id: 'config',
          title: 'notes_listConfigSelectorName'.tr,
          viewType: SelectorViewType.customForm,
          dataLoader: (_) async => [], // customForm 不需要加载数据
          isFinalStep: true,
          customFormBuilder: (context, previousSelections, onComplete) {
            return _NotesListConfigForm(
              onComplete: (config) {
                onComplete(config);
              },
            );
          },
        ),
      ],
    ),
  );
}

/// 构建文件夹完整路径（用于显示在副标题）
String _buildFolderPath(String folderId) {
  final folder = NotesPlugin.instance.controller.getFolder(folderId);
  if (folder == null || folder.id == 'root') return '';

  final pathParts = <String>[];
  var currentFolder = folder;

  while (currentFolder.id != 'root') {
    pathParts.insert(0, currentFolder.name);
    if (currentFolder.parentId != null) {
      final parent = NotesPlugin.instance.controller.getFolder(
        currentFolder.parentId!,
      );
      if (parent != null) {
        currentFolder = parent;
      } else {
        break;
      }
    } else {
      break;
    }
  }

  return pathParts.join(' / ');
}

/// 笔记列表配置表单
class _NotesListConfigForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const _NotesListConfigForm({required this.onComplete});

  @override
  State<_NotesListConfigForm> createState() => _NotesListConfigFormState();
}

class _NotesListConfigFormState extends State<_NotesListConfigForm> {
  String? _selectedFolderId;
  String? _selectedFolderName;
  final Set<String> _selectedTags = {};
  DateTime? _startDate;
  DateTime? _endDate;

  List<Folder> _folders = [];
  List<String> _allTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final controller = NotesPlugin.instance.controller;

    // 获取所有文件夹
    final allFolders =
        controller
            .getAllFolders()
            .where((folder) => folder.id != 'root')
            .toList();

    // 获取所有标签
    final allNotes = controller.searchNotes(query: '');
    final tagsSet = <String>{};
    for (final note in allNotes) {
      tagsSet.addAll(note.tags);
    }

    setState(() {
      _folders = allFolders;
      _allTags = tagsSet.toList()..sort();
      _isLoading = false;
      // 默认选择"全部笔记"
      _selectedFolderId = null;
      _selectedFolderName = null;
    });
  }

  void _confirm() {
    widget.onComplete({
      'folderId': _selectedFolderId,
      'folderName': _selectedFolderName,
      'tags': _selectedTags.toList(),
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return DSThemeBridge(
        child: Builder(
          builder:
              (context) => Center(
                child: DSLoadingDots(color: NotesPlugin.instance.color),
              ),
        ),
      );
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  // 标题
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        DsIcon(
                          DsIconKind.sort,
                          color: NotesPlugin.instance.color,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'notes_listConfigSelectorName'.tr,
                            style: DsTypography.title.copyWith(
                              color: theme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: theme.stroke.withValues(alpha: 0.4),
                  ),
                  // 配置选项
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 文件夹选择
                        _buildFolderSelector(theme),
                        const SizedBox(height: 16),
                        // 标签选择
                        _buildTagSelector(theme),
                        const SizedBox(height: 16),
                        // 日期范围选择
                        _buildDateRangeSelector(theme),
                      ],
                    ),
                  ),
                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: DSButton(
                            label: 'notes_cancel'.tr,
                            variant: DSButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DSButton(
                            label: 'notes_confirm'.tr,
                            onPressed: _confirm,
                          ),
                        ),
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

  Widget _buildFolderSelector(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'notes_selectFolderTitle'.tr,
          style: DsTypography.heading.copyWith(color: theme.text),
        ),
        const SizedBox(height: 8),
        DSSelect<String>(
          value: _selectedFolderId ?? 'all',
          items: [
            DSSelectItem(value: 'all', label: 'notes_allNotes'.tr),
            ..._folders.map((folder) {
              final notesCount =
                  NotesPlugin.instance.controller
                      .getFolderNotes(folder.id)
                      .length;
              final folderPath = _buildFolderPath(folder.id);
              return DSSelectItem(
                value: folder.id,
                label: '$folderPath • $notesCount ${'notes_notesCount'.tr}',
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              if (value == 'all') {
                _selectedFolderId = null;
                _selectedFolderName = null;
              } else {
                _selectedFolderId = value;
                final folder = _folders.firstWhere((f) => f.id == value);
                _selectedFolderName = folder.name;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildTagSelector(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'notes_selectTagsTitle'.tr} (${'notes_optional'.tr})',
          style: DsTypography.heading.copyWith(color: theme.text),
        ),
        const SizedBox(height: 8),
        if (_allTags.isEmpty)
          Text(
            'notes_noTags'.tr,
            style: DsTypography.caption.copyWith(color: theme.textSub),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _allTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return DSChip(
                    label: tag,
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
      ],
    );
  }

  Widget _buildDateRangeSelector(AppThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'notes_selectDateRangeTitle'.tr} (${'notes_optional'.tr})',
          style: DsTypography.heading.copyWith(color: theme.text),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DSButton(
                label:
                    _startDate == null
                        ? 'notes_startDate'.tr
                        : DateFormat('yyyy-MM-dd').format(_startDate!),
                icon: DsIconKind.calendar,
                variant: DSButtonVariant.outline,
                size: DSButtonSize.sm,
                onPressed: () async {
                  final date = await showDSDatePickerDialog(
                    context: context,
                    initial: _startDate ?? DateTime.now(),
                    theme: DSThemeBridge.resolve(context),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DSButton(
                label:
                    _endDate == null
                        ? 'notes_endDate'.tr
                        : DateFormat('yyyy-MM-dd').format(_endDate!),
                icon: DsIconKind.calendar,
                variant: DSButtonVariant.outline,
                size: DSButtonSize.sm,
                onPressed: () async {
                  final date = await showDSDatePickerDialog(
                    context: context,
                    initial: _endDate ?? DateTime.now(),
                    theme: DSThemeBridge.resolve(context),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
            ),
          ],
        ),
        if (_startDate != null || _endDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DSButton(
              label: 'notes_clearDateFilter'.tr,
              icon: DsIconKind.close,
              variant: DSButtonVariant.ghost,
              size: DSButtonSize.sm,
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              },
            ),
          ),
      ],
    );
  }
}
