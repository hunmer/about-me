import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper/index.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/folder_tree_node.dart';
import 'package:aboutme/plugins/notes/widgets/folder_selection_sheet.dart';
import 'notes_route_context.dart';
import 'notes_screen_state.dart';

mixin NotesFiltering on NotesMainViewState, NotesRouteContext {
  /// 处理搜索文本变化
  void handleSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        loadCurrentFolder();
      });
    } else {
      setState(() {
        isSearching = true;
      });
      // 使用基类的搜索方法，然后应用标签和日期过滤
      handleSearch(query);
      // 应用额外的过滤条件
      if (selectedTag != null || selectedDate != null) {
        setState(() {
          notes = plugin.controller.searchNotes(
            query: query,
            tags: selectedTag != null ? [selectedTag!] : null,
            startDate: selectedDate,
            endDate: selectedDate,
          );
        });
      }
    }
    // 更新路由上下文
    updateRouteContext();
  }

  /// 处理搜索提交
  void handleSearchSubmitted(String query) {
    if (query.isNotEmpty) {
      handleSearchChanged(query);
    }
  }

  /// 显示文件夹选择器
  Future<Folder?> _showFolderPicker() async {
    final rootFolder = plugin.controller.getFolder('root')!;
    final allFolders = plugin.controller.getAllFolders();

    // 构建文件夹树
    final folderMap = <String, Folder>{};
    for (var folder in allFolders) {
      folderMap[folder.id] = folder;
    }

    final rootNode = FolderTreeNode.buildTree(rootFolder, folderMap);

    // 显示底部抽屉选择器
    final selectedFolder = await FolderSelectionSheet.show(
      context: context,
      rootNode: rootNode,
      note: null, // 不传递笔记，因为这是过滤而不是移动笔记
    );

    return selectedFolder;
  }

  /// 构建多条件过滤列表
  List<FilterItem> buildFilterItems() {
    // 获取所有标签
    final allTags = <String>{};
    final allNotes = plugin.controller.getAllNotes();

    for (var noteList in allNotes.values) {
      for (var note in noteList) {
        for (var tag in note.tags) {
          allTags.add(tag);
        }
      }
    }

    final tagsList = allTags.toList();

    return [
      // 文件夹选择过滤
      FilterItem(
        id: 'folder',
        title: 'notes_folder'.tr,
        type: FilterType.custom,
        builder: (context, currentValue, onChanged) {
          final selectedFolder = currentValue as Folder?;
          // 第三方过滤栏回调：DS 组件需包 DSThemeBridge
          return DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DSButton(
                      label: selectedFolder?.name ?? 'notes_selectFolder'.tr,
                      icon: DsIconKind.layers,
                      variant: DSButtonVariant.outline,
                      size: DSButtonSize.sm,
                      onPressed: () async {
                        final folder = await _showFolderPicker();
                        if (folder != null) {
                          onChanged(folder);
                        }
                      },
                    ),
                    if (selectedFolder != null)
                      Pressable(
                        onPressed: () => onChanged(null),
                        builder:
                            (context, states) => DsIcon(
                              DsIconKind.close,
                              size: 16,
                              color: theme.textSub,
                            ),
                      ),
                  ],
                );
              },
            ),
          );
        },
        getBadge: (value) {
          if (value is Folder) {
            return value.name;
          }
          return null;
        },
      ),

      // 标签多选过滤
      if (tagsList.isNotEmpty)
        FilterItem(
          id: 'tags',
          title: 'notes_tags'.tr,
          type: FilterType.tagsMultiple,
          builder: (context, currentValue, onChanged) {
            return FilterBuilders.buildTagsFilter(
              context: context,
              currentValue: currentValue,
              onChanged: onChanged,
              availableTags: tagsList,
            );
          },
          getBadge: FilterBuilders.tagsBadge,
        ),

      // 日期过滤
      FilterItem(
        id: 'date',
        title: 'notes_date'.tr,
        type: FilterType.date,
        builder: (context, currentValue, onChanged) {
          return FilterBuilders.buildDateFilter(
            context: context,
            currentValue: currentValue,
            onChanged: onChanged,
          );
        },
        getBadge: FilterBuilders.dateBadge,
      ),
    ];
  }

  /// 应用多条件过滤
  void applyMultiFilters(Map<String, dynamic> filters) {
    setState(() {
      // 提取文件夹过滤
      final folderFilter = filters['folder'] as Folder?;

      // 提取标签过滤
      final tagFilters = filters['tags'] as List<String>?;

      // 提取日期过滤
      final dateFilter = filters['date'] as DateTime?;

      // 如果选择了文件夹过滤，先获取该文件夹的笔记
      List<Note> baseNotes;
      if (folderFilter != null) {
        baseNotes = plugin.controller.getFolderNotes(folderFilter.id);
      } else {
        // 否则使用当前文件夹的笔记
        baseNotes = plugin.controller.getFolderNotes(currentFolderId);
      }
      // 与主列表一致：普通视图排除已归档笔记，已归档视图只看归档
      baseNotes = baseNotes
          .where((note) => note.isArchived == isArchivedView)
          .toList();

      // 应用标签和日期过滤
      if (searchController.text.isNotEmpty ||
          (tagFilters != null && tagFilters.isNotEmpty) ||
          dateFilter != null) {
        // 对基础笔记列表应用额外过滤
        notes =
            baseNotes.where((note) {
              // 搜索文本过滤
              if (searchController.text.isNotEmpty) {
                final query = searchController.text.toLowerCase();
                if (!note.title.toLowerCase().contains(query) &&
                    !note.content.toLowerCase().contains(query)) {
                  return false;
                }
              }

              // 标签过滤
              if (tagFilters != null && tagFilters.isNotEmpty) {
                if (!tagFilters.any((tag) => note.tags.contains(tag))) {
                  return false;
                }
              }

              // 日期过滤
              if (dateFilter != null) {
                final noteDate = DateTime(
                  note.createdAt.year,
                  note.createdAt.month,
                  note.createdAt.day,
                );
                final filterDate = DateTime(
                  dateFilter.year,
                  dateFilter.month,
                  dateFilter.day,
                );
                if (!noteDate.isAtSameMomentAs(filterDate)) {
                  return false;
                }
              }

              return true;
            }).toList();
      } else {
        notes = baseNotes;
      }

      // 更新旧的状态变量（保持兼容性）
      selectedTag =
          tagFilters != null && tagFilters.isNotEmpty ? tagFilters.first : null;
      selectedDate = dateFilter;
    });

    // 更新路由上下文
    updateRouteContext();
  }
}
