import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skribble/skribble.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/filter_models.dart';
import 'package:aboutme/widgets/form_fields/circle_icon_picker_field.dart';
import 'package:aboutme/widgets/tag_folder_card.dart';
import '../models/models.dart';
import 'tags_list.dart';
import '../utils/json_storage.dart';

/// 排序方式文案
String _sortTypeLabel(TagsSortType type) => switch (type) {
  TagsSortType.createdAt => 'app_tags_sortCreatedAt'.tr,
  TagsSortType.lastUsedAt => 'app_tags_sortLastUsedAt'.tr,
  TagsSortType.name => 'app_tags_sortName'.tr,
};

/// 自定义标签项渲染器
///
/// 返回的 widget 替换标签格子默认内容（点击/长按/批量编辑交互壳由列表保留），
/// [isSelected] 为当前选中态，由渲染器自行呈现。
typedef TagsItemBuilder = Widget Function(
  BuildContext context,
  TagItem tag,
  bool isSelected,
);

/// 标签管理对话框
///
/// 支持的功能：
/// - 传入 JSON 文件路径自动读取/保存
/// - 或直接传入分组和标签数据
/// - 搜索功能（标题、注释搜索）
/// - 多条件过滤（分组过滤、排序）
/// - 长按弹出底部抽屉（编辑、删除）
/// - 批量编辑功能
/// - 单击选择模式（单选/多选）
/// - 嵌入/对话框两种显示模式
class TagsDialog extends StatefulWidget {
  /// JSON 文件路径（传入后自动读取/保存）
  final String? jsonFilePath;

  /// 标签分组列表（支持新格式 TagGroupWithTags 或旧格式 TagGroup）
  final List<dynamic>? groups;

  /// 已选择的标签名称列表
  final List<String> selectedTags;

  /// 配置选项
  final TagsDialogConfig config;

  /// 显示模式
  final TagsDisplayMode displayMode;

  /// 标签选择变更回调
  final Function(List<String>)? onTagsSelected;

  /// 标签分组变更回调
  final Function(List<TagGroupWithTags>)? onGroupsChanged;

  /// 添加标签回调
  final Future<TagItem?> Function(String group, {TagItem? tag})? onAddTag;

  /// 删除标签回调
  final Future<bool> Function(TagItem tag)? onDeleteTag;

  /// 编辑标签回调
  final Future<TagItem?> Function(TagItem oldTag, TagItem newTag)? onEditTag;

  /// 自定义标签项渲染（null 时用默认胶囊）
  final TagsItemBuilder? tagItemBuilder;

  const TagsDialog({
    super.key,
    this.jsonFilePath,
    this.groups,
    this.selectedTags = const [],
    this.config = const TagsDialogConfig(),
    this.displayMode = TagsDisplayMode.dialog,
    this.onTagsSelected,
    this.onGroupsChanged,
    this.onAddTag,
    this.onDeleteTag,
    this.onEditTag,
    this.tagItemBuilder,
  });

  /// 兼容旧版 TagGroup 的工厂构造函数
  factory TagsDialog.fromLegacy({
    Key? key,
    required List<dynamic> legacyGroups,
    List<String> selectedTags = const [],
    TagsDialogConfig config = const TagsDialogConfig(),
    TagsDisplayMode displayMode = TagsDisplayMode.dialog,
    Function(List<String>)? onTagsSelected,
    Function(List<TagGroupWithTags>)? onGroupsChanged,
    Future<TagItem?> Function(String group, {TagItem? tag})? onAddTag,
    Future<bool> Function(TagItem tag)? onDeleteTag,
    Future<TagItem?> Function(TagItem oldTag, TagItem newTag)? onEditTag,
    TagsItemBuilder? tagItemBuilder,
  }) {
    return TagsDialog(
      key: key,
      groups: legacyGroups,
      selectedTags: selectedTags,
      config: config,
      displayMode: displayMode,
      onTagsSelected: onTagsSelected,
      onGroupsChanged: onGroupsChanged,
      onAddTag: onAddTag,
      onDeleteTag: onDeleteTag,
      onEditTag: onEditTag,
      tagItemBuilder: tagItemBuilder,
    );
  }

  @override
  State<TagsDialog> createState() => _TagsDialogState();

  /// 显示对话框
  static Future<List<String>?> show(
    BuildContext context, {
    String? jsonFilePath,
    List<dynamic>? groups, // 支持新格式 TagGroupWithTags 或旧格式 TagGroup
    List<String> selectedTags = const [],
    TagsDialogConfig config = const TagsDialogConfig(),
    Function(List<TagGroupWithTags>)? onGroupsChanged,
    Future<TagItem?> Function(String group, {TagItem? tag})? onAddTag,
    Future<bool> Function(TagItem tag)? onDeleteTag,
    Future<TagItem?> Function(TagItem oldTag, TagItem newTag)? onEditTag,
    TagsItemBuilder? tagItemBuilder,
  }) {
    return SmoothBottomSheet.show<List<String>>(
      context: context,
      builder: (context) => TagsDialog(
        jsonFilePath: jsonFilePath,
        groups: groups,
        selectedTags: selectedTags,
        config: config,
        onGroupsChanged: onGroupsChanged,
        onAddTag: onAddTag,
        onDeleteTag: onDeleteTag,
        onEditTag: onEditTag,
        tagItemBuilder: tagItemBuilder,
      ),
    );
  }
}

class _TagsDialogState extends State<TagsDialog> {
  /// 标签分组列表
  late List<TagGroupWithTags> _groups;

  /// 已选择的标签
  List<String> _selectedTags = [];

  /// 搜索关键词
  String _searchQuery = '';

  /// 多条件过滤状态
  late MultiFilterState _filterState;

  /// JSON 存储工具
  JsonStorage? _jsonStorage;

  @override
  void initState() {
    super.initState();
    _filterState = MultiFilterState();
    _initializeData();
  }

  /// 初始化数据
  Future<void> _initializeData() async {
    _selectedTags = List.from(widget.selectedTags);

    // 优先使用 JSON 文件
    if (widget.jsonFilePath != null) {
      _jsonStorage = JsonStorage(widget.jsonFilePath!);
      final loadedGroups = await _jsonStorage!.load();
      if (loadedGroups != null) {
        _groups = loadedGroups;
        return;
      }
    }

    // 使用传入的分组数据（支持新旧格式）
    if (widget.groups != null && widget.groups!.isNotEmpty) {
      _groups = _convertGroupsToNewFormat(widget.groups!);
    } else {
      _groups = [];
    }

    setState(() {});
  }

  /// 转换分组数据为新格式（兼容旧版 TagGroup）
  List<TagGroupWithTags> _convertGroupsToNewFormat(List<dynamic> groups) {
    return groups.map((group) {
      // 如果已经是新格式，直接返回
      if (group is TagGroupWithTags) {
        return group;
      }
      // 否则使用兼容性方法转换
      return TagGroupWithTags.fromLegacyTagGroup(group);
    }).toList();
  }

  /// 获取过滤后的标签列表
  List<TagItem> get _filteredTags {
    List<TagItem> result = [];

    // 按分组收集所有标签
    for (var group in _groups) {
      result.addAll(group.tags);
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((tag) {
        return tag.name.toLowerCase().contains(query) ||
            (tag.comment?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // 分组过滤
    final selectedGroup = _filterState.getValue('group') as String?;
    if (selectedGroup != null && selectedGroup.isNotEmpty) {
      result = result.where((tag) => tag.group == selectedGroup).toList();
    }

    // 跨分组同名标签去重（如"最近使用"与原分组并存），保留首个出现的
    final seen = <String>{};
    result = result.where((tag) => seen.add(tag.name)).toList();

    // 排序
    final sortType = _filterState.getValue('sort') as TagsSortType? ??
        TagsSortType.createdAt;
    result = _sortTags(result, sortType);

    return result;
  }

  /// 排序标签
  List<TagItem> _sortTags(List<TagItem> tags, TagsSortType sortType) {
    switch (sortType) {
      case TagsSortType.createdAt:
        // 先按创建时间降序，时间相同时按名称升序（保证稳定排序）
        tags.sort((a, b) {
          final timeCompare = b.createdAt.compareTo(a.createdAt);
          if (timeCompare != 0) return timeCompare;
          return a.name.compareTo(b.name);
        });
        return tags;
      case TagsSortType.lastUsedAt:
        return tags..sort((a, b) {
          final aTime = a.lastUsedAt ?? a.createdAt;
          final bTime = b.lastUsedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
      case TagsSortType.name:
        return tags..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  /// 保存数据
  Future<void> _saveData() async {
    // 保存到 JSON 文件
    if (_jsonStorage != null) {
      await _jsonStorage!.save(_groups);
    }

    // 回调通知
    widget.onGroupsChanged?.call(_groups);
  }

  /// 搜索变更
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  /// 过滤变更
  void _onFilterChanged(Map<String, dynamic> filters) {
    _filterState.initializeFromMap(filters);
    // 使用 addPostFrameCallback 避免 build 期间调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 选择标签
  void _selectTag(String tagName) {
    setState(() {
      switch (widget.config.selectionMode) {
        case TagsSelectionMode.single:
          _selectedTags = [tagName];
          break;
        case TagsSelectionMode.multiple:
          if (_selectedTags.contains(tagName)) {
            _selectedTags.remove(tagName);
          } else {
            _selectedTags.add(tagName);
          }
          break;
        case TagsSelectionMode.none:
          break;
      }
      widget.onTagsSelected?.call(_selectedTags);
    });

    // 单选模式：选中即确认返回，由调用方处理（如打开标签文件夹）
    if (widget.config.selectionMode == TagsSelectionMode.single) {
      _confirmSelection();
    }
  }

  /// 显示标签底部抽屉
  void _showTagBottomSheet(TagItem tag) {
    SmoothBottomSheet.showWithTitle(
      context: context,
      title: tag.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmoothSheetAction(
            icon: DsIconKind.edit,
            label: widget.config.editButtonText,
            onTap: () {
              Navigator.pop(context);
              _editTag(tag);
            },
          ),
          SmoothSheetAction(
            icon: DsIconKind.trash,
            label: widget.config.deleteButtonText,
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              _deleteTag(tag);
            },
          ),
        ],
      ),
    );
  }

  /// 编辑标签
  Future<void> _editTag(TagItem oldTag) async {
    // 先调用内置编辑对话框获取编辑后的数据
    TagItem? newTag = await _showEditTagDialog(oldTag);

    // 如果外部提供了 onEditTag 回调，让它处理编辑后的数据
    if (newTag != null && widget.onEditTag != null) {
      newTag = await widget.onEditTag!(oldTag, newTag);
    }

    if (newTag != null) {
      setState(() {
        // 先从原分组中移除旧标签
        for (var group in _groups) {
          final index = group.tags.indexWhere((t) => t.name == oldTag.name);
          if (index != -1) {
            group.tags.removeAt(index);
            break;
          }
        }

        // 再将新标签添加到新分组（支持跨分组移动）
        final newGroupIndex = _groups.indexWhere(
          (g) => g.name == newTag?.group,
        );
        if (newGroupIndex != -1) {
          _groups[newGroupIndex].tags.add(newTag!);
        }
      });
      await _saveData();
    }
  }

  /// 删除标签
  Future<void> _deleteTag(TagItem tag) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'app_confirmDelete'.tr,
        message: 'app_tags_deleteTagConfirm'.trParams({'name': tag.name}),
        cancelText: 'app_cancel'.tr,
        confirmText: 'app_delete'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      if (widget.onDeleteTag != null) {
        final success = await widget.onDeleteTag!(tag);
        if (success) {
          setState(() {
            for (var group in _groups) {
              group.tags.removeWhere((t) => t.name == tag.name);
            }
            _selectedTags.remove(tag.name);
          });
          await _saveData();
        }
      } else {
        setState(() {
          for (var group in _groups) {
            group.tags.removeWhere((t) => t.name == tag.name);
          }
          _selectedTags.remove(tag.name);
        });
        await _saveData();
      }
    }
  }

  /// 批量删除选中的标签
  Future<void> _batchDeleteSelected() async {
    if (_selectedTags.isEmpty) return;

    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder: (context) => DSDialog(
        title: 'app_confirmDelete'.tr,
        message: 'app_tags_deleteSelectedConfirm'.trParams(
          {'count': _selectedTags.length.toString()},
        ),
        cancelText: 'app_cancel'.tr,
        confirmText: 'app_delete'.tr,
        confirmVariant: DSButtonVariant.destructive,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      setState(() {
        for (var tagName in _selectedTags) {
          for (var group in _groups) {
            group.tags.removeWhere((t) => t.name == tagName);
          }
        }
        _selectedTags.clear();
      });
      await _saveData();
    }
  }

  /// 添加标签
  Future<void> _addTag(String group) async {
    final newTag =
        widget.onAddTag != null
            ? await widget.onAddTag!(group)
            : await _showAddTagDialog(group);

    if (newTag != null) {
      setState(() {
        final groupIndex = _groups.indexWhere((g) => g.name == group);
        if (groupIndex != -1) {
          _groups[groupIndex].tags.add(newTag);
        } else {
          _groups.add(TagGroupWithTags(name: group, tags: [newTag]));
        }
      });
      await _saveData();
    }
  }

  /// 确认选择
  void _confirmSelection() {
    Navigator.of(context).pop(_selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (widget.displayMode == TagsDisplayMode.dialog) {
      // sheet 面板（DsSketchPanel）已提供纸底背景，这里只约束高度。
      // 弹层顶部不处于状态栏下方，须清掉 top inset：否则内嵌
      // SuperCupertinoNavigationWrapper 的 SuperAppBar header 仍会
      // 读 MediaQuery.padding.top 叠出一块状态栏高度的空白
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildContent() {
    // 构建多条件过滤项
    final filterItems = _buildFilterItems();

    return SuperCupertinoNavigationWrapper(
      title: Text(widget.config.title),
      largeTitle: widget.config.largeTitle,
      enableLargeTitle: true,
      enableSearchBar: true,
      searchPlaceholder: widget.config.searchPlaceholder,
      onSearchChanged: _onSearchChanged,
      enableMultiFilter: true,
      multiFilterItems: filterItems,
      multiFilterBarHeight: 50,
      onMultiFilterChanged: _onFilterChanged,
      multiFilterToggleable: true,
      actions: _buildActions(),
      body: Column(
        children: [
          Expanded(
            child: TagsList(
              tags: _filteredTags,
              selectedTags: _selectedTags,
              config: widget.config,
              selectionMode: widget.config.selectionMode,
              tagItemBuilder: widget.tagItemBuilder ?? _defaultFolderTagItem,
              onSelectTag: _selectTag,
              onLongPress: widget.config.enableLongPressMenu
                  ? _showTagBottomSheet
                  : null,
              onDeleteTap: widget.config.enableEditing ? _deleteTag : null,
              onEditTap: widget.config.enableEditing ? _editTag : null,
              onAddTag: widget.config.enableEditing ? _addTag : null,
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  /// 底部操作栏：选中标签后显示删除图标 + 确定按钮
  Widget _buildBottomActions() {
    final canBatchDelete =
        widget.config.enableBatchEdit && _selectedTags.isNotEmpty;
    final canConfirm =
        widget.config.selectionMode != TagsSelectionMode.none &&
        _selectedTags.isNotEmpty;

    if (!canBatchDelete && !canConfirm) return const SizedBox.shrink();

    final theme = DSThemeBridge.resolve(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
      child: Row(
        children: [
          // 批量删除选中标签
          if (canBatchDelete) ...[
            DSIconButton(
              icon: DsIconKind.trash,
              size: 44,
              color: theme.surfaceAlt,
              iconColor: theme.danger,
              tooltip: 'app_delete'.tr,
              onPressed: _batchDeleteSelected,
            ),
            const SizedBox(width: 12),
          ],
          // 确认选择（选择模式下）
          if (canConfirm)
            Expanded(
              child: DSButton(
                label:
                    '${widget.config.confirmButtonText}(${_selectedTags.length})',
                onPressed: _confirmSelection,
              ),
            ),
        ],
      ),
    );
  }

  /// 默认标签项渲染：手绘文件夹卡片（无图片源，空文件夹）+ 选中态角标
  Widget _defaultFolderTagItem(
    BuildContext context,
    TagItem tag,
    bool isSelected,
  ) {
    final theme = DSThemeBridge.resolve(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // TagFolderCard 内部依赖有界高度（Expanded），用 AspectRatio 撑出格子尺寸
        AspectRatio(
          aspectRatio: 0.8,
          child: TagFolderCard(tag: tag.name, imageUrls: const [], count: 0),
        ),
        if (isSelected)
          Positioned(
            right: 0,
            top: 0,
            child: JellyBox(
              width: 22,
              height: 22,
              radius: theme.radii.circle,
              color: theme.primary,
              child: DsIcon(DsIconKind.check, size: 14, color: theme.onPrimary),
            ),
          ),
      ],
    );
  }

  /// 构建操作按钮
  List<Widget> _buildActions() {
    final actions = <Widget>[];

    // 添加标签按钮
    if (widget.config.enableEditing) {
      actions.add(
        DSIconButton(
          icon: DsIconKind.plus,
          size: 34,
          tooltip: widget.config.addTagText,
          onPressed: _showAddTagUI,
        ),
      );
    }

    return actions;
  }

  /// 显示添加标签对话框
  void _showAddTagUI() {
    // 分组可在编辑表单里选择，默认取第一个分组
    final defaultGroup = _groups.isNotEmpty ? _groups.first.name : 'default';
    _addTag(defaultGroup);
  }

  /// 内置添加标签对话框（返回 TagItem）
  Future<TagItem?> _showAddTagDialog(String group) async {
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _TagEditDialog(
            group: group,
            groups: _groups.map((g) => g.name).toList(),
            defaultIcon: widget.config.defaultIcon,
            defaultColor: DSThemeBridge.resolve(context).primary,
          ),
    );

    if (result != null) {
      return TagItem(
        name: result['name'] as String,
        icon: result['icon'] as IconData? ?? widget.config.defaultIcon,
        color: result['color'] as Color?,
        group: result['group'] as String,
        comment: result['comment'] as String?,
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// 内置编辑标签对话框（返回 TagItem）
  Future<TagItem?> _showEditTagDialog(TagItem oldTag) async {
    final result = await showDSDialog<Map<String, dynamic>>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (context) => _TagEditDialog(
            tag: oldTag,
            groups: _groups.map((g) => g.name).toList(),
            defaultIcon: widget.config.defaultIcon,
            defaultColor: DSThemeBridge.resolve(context).primary,
          ),
    );

    if (result != null) {
      return TagItem(
        name: result['name'] as String,
        icon: result['icon'] as IconData? ?? oldTag.icon,
        color: result['color'] as Color? ?? oldTag.color,
        group: result['group'] as String,
        comment: result['comment'] as String?,
        createdAt: oldTag.createdAt,
        lastUsedAt: DateTime.now(),
      );
    }
    return null;
  }

  /// 构建过滤项
  List<FilterItem> _buildFilterItems() {
    final groups = _groups.map((g) => g.name).toList();

    return [
      // 分组过滤
      FilterItem(
        id: 'group',
        title: 'app_tags_group'.tr,
        type: FilterType.tagsSingle,
        builder: (context, value, onChanged) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DSChip(
                label: 'app_tags_all'.tr,
                selected: value == null || value == '',
                onSelected: (selected) {
                  if (selected) onChanged('');
                },
              ),
              ...groups.map((group) {
                return DSChip(
                  label: group,
                  selected: value == group,
                  onSelected: (selected) {
                    if (selected) onChanged(group);
                  },
                );
              }),
            ],
          );
        },
        getBadge: (value) {
          if (value == null || value == '') return null;
          return value as String;
        },
      ),

      // 排序方式
      FilterItem(
        id: 'sort',
        title: 'app_tags_sort'.tr,
        type: FilterType.tagsSingle,
        initialValue: TagsSortType.createdAt,
        builder: (context, value, onChanged) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TagsSortType.values.map((type) {
              return DSChip(
                label: _sortTypeLabel(type),
                selected: value == type,
                onSelected: (selected) {
                  if (selected) onChanged(type);
                },
              );
            }).toList(),
          );
        },
        getBadge: (value) {
          if (value == null) return null;
          return _sortTypeLabel(value as TagsSortType);
        },
      ),
    ];
  }
}

/// 标签编辑对话框（用于添加和编辑）
class _TagEditDialog extends StatefulWidget {
  /// 要编辑的标签（null 表示添加新标签）
  final TagItem? tag;

  /// 默认分组（添加时使用）
  final String? group;

  /// 可选分组列表
  final List<String> groups;

  /// 默认图标
  final IconData defaultIcon;

  /// 默认颜色
  final Color defaultColor;

  const _TagEditDialog({
    this.tag,
    this.group,
    required this.groups,
    required this.defaultIcon,
    required this.defaultColor,
  });

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  late IconData _selectedIcon;
  late Color _selectedColor;
  late String _selectedGroup;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.tag?.name ?? '';
    _commentController.text = widget.tag?.comment ?? '';
    _selectedIcon = widget.tag?.icon ?? widget.defaultIcon;
    _selectedColor = widget.tag?.color ?? widget.defaultColor;
    _selectedGroup =
        widget.tag?.group ??
        widget.group ??
        (widget.groups.isNotEmpty ? widget.groups.first : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;
    final theme = AppTheme.of(context);
    // showDSDialog 外层已包 WiredDraw，面板墨线随描画动画入场
    final progress = WiredDrawTransition.progressOf(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.xl),
        progress: progress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEditing ? 'app_tags_editTag'.tr : 'app_tags_addTag'.tr,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            SizedBox(height: theme.spacing.lg),

            // 图标和颜色选择
            CircleIconPickerField(
              currentIcon: _selectedIcon,
              currentBackgroundColor: _selectedColor,
              onValueChanged: (value) {
                setState(() {
                  _selectedIcon = value['icon'] as IconData;
                  _selectedColor = value['color'] as Color;
                });
              },
            ),
            SizedBox(height: theme.spacing.md),

            // 标签名称
            DSInput(
              controller: _nameController,
              label: 'app_tags_name'.tr,
              hint: 'app_tags_nameHint'.tr,
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            SizedBox(height: theme.spacing.md),

            // 分组选择
            if (widget.groups.isNotEmpty) ...[
              Text(
                'app_tags_group'.tr,
                style: DsTypography.caption.copyWith(color: theme.textSub),
              ),
              SizedBox(height: theme.spacing.sm),
              DSSelect<String>(
                items: widget.groups
                    .map((group) => DSSelectItem(label: group, value: group))
                    .toList(),
                value: _selectedGroup,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGroup = value);
                  }
                },
              ),
              SizedBox(height: theme.spacing.md),
            ],

            // 注释
            DSInput(
              controller: _commentController,
              label: 'app_tags_comment'.tr,
              hint: 'app_tags_commentHint'.tr,
              maxLines: 3,
            ),
            SizedBox(height: theme.spacing.lg),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: DSButton(
                    label: 'app_cancel'.tr,
                    variant: DSButtonVariant.outline,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: DSButton(
                    label: 'app_ok'.tr,
                    onPressed: _confirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 确认提交
  void _confirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'app_tags_nameHint'.tr);
      return;
    }

    final comment = _commentController.text.trim();
    Navigator.pop(context, {
      'name': name,
      'group': _selectedGroup,
      'icon': _selectedIcon,
      'color': _selectedColor,
      'comment': comment.isEmpty ? null : comment,
    });
  }
}
