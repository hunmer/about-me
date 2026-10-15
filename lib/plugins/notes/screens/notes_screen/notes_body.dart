import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/folder_breadcrumbs.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'folder_card.dart';
import 'folder_operations.dart';
import 'note_card.dart';
import 'note_operations.dart';
import 'notes_fab.dart';
import 'notes_screen_state.dart';

mixin NotesBody
    on NotesMainViewState, NoteOperations, NotesFab, FolderOperations {
  /// 构建面包屑导航项
  List<FolderBreadcrumbItem> _buildBreadcrumbItems() {
    // 已归档视图是虚拟目录，不在文件夹树内，单独渲染面包屑
    if (isArchivedView) {
      return [FolderBreadcrumbItem(id: kArchivedFolderId, name: 'notes_archived'.tr)];
    }
    final path = plugin.controller.getFolderPath(currentFolderId);
    return path.map((folder) {
      return FolderBreadcrumbItem(id: folder.id, name: folder.name);
    }).toList();
  }

  /// 根目录是否插入"已归档"固定入口卡片
  bool get _showArchivedEntry => currentFolderId == 'root' && !isSearching;

  Widget buildBody() {
    return Builder(
      builder: (context) {
        final theme = DSThemeBridge.resolve(context);
        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Folder Breadcrumbs (显示当前文件夹路径)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16, top: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FolderBreadcrumbs(
                      folders: _buildBreadcrumbItems(),
                      onFolderTap: (folderId) {
                        // 点击面包屑导航到对应文件夹
                        setState(() {
                          currentFolderId = folderId;
                          loadCurrentFolder();
                        });
                      },
                    ),
                  ),
                ),

                // Folders & Notes Grid（子文件夹卡片插在网格最前，笔记随后）
                if (subFolders.isNotEmpty ||
                    notes.isNotEmpty ||
                    _showArchivedEntry)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childCount:
                          subFolders.length +
                          notes.length +
                          (_showArchivedEntry ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 手绘便签倾斜(卡片自带贴条,关掉组件贴条);
                        // 挂载时墨线描画入场
                        if (_showArchivedEntry && index == 0) {
                          // "已归档"固定入口：展示归档的文件夹与笔记总数
                          final archivedCount =
                              plugin.controller.getArchivedFolders().length +
                              plugin.controller.getArchivedNotes().length;
                          return HandDrawnStickyItem(
                            tiltKey: 'folder_$kArchivedFolderId',
                            showTape: false,
                            child: WiredDraw(
                              child: FolderCard(
                                folder: Folder(
                                  id: kArchivedFolderId,
                                  name: 'notes_archived'.tr,
                                  parentId: 'root',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                  color: Colors.blueGrey,
                                ),
                                noteCount: archivedCount,
                                onTap: () {
                                  setState(() {
                                    currentFolderId = kArchivedFolderId;
                                    loadCurrentFolder();
                                  });
                                },
                              ),
                            ),
                          );
                        }
                        final folderIndex =
                            index - (_showArchivedEntry ? 1 : 0);
                        if (folderIndex < subFolders.length) {
                          final folder = subFolders[folderIndex];
                          return HandDrawnStickyItem(
                            tiltKey: 'folder_${folder.id}',
                            showTape: false,
                            child: WiredDraw(
                              child: FolderCard(
                                folder: folder,
                                // 文件夹计数不含已归档笔记
                                noteCount: plugin.controller
                                    .getFolderNotes(folder.id)
                                    .where((note) => !note.isArchived)
                                    .length,
                                onTap: () => navigateToFolder(folder),
                                onEdit: () => renameFolder(folder),
                                onDelete: () => deleteFolder(folder),
                                onToggleArchive: () =>
                                    toggleFolderArchive(folder),
                              ),
                            ),
                          );
                        }
                        final note = notes[folderIndex - subFolders.length];
                        return HandDrawnStickyItem(
                          tiltKey: 'note_${note.id}',
                          showTape: false,
                          child: WiredDraw(
                            child: NoteCard(
                              note: note,
                              onTap: () => editNote(note),
                              onDelete: () => deleteNote(note),
                              onToggle:
                                  note.isTodo
                                      ? (i) => toggleTodoItem(note, i)
                                      : null,
                              onEditStyle:
                                  (style) => updateNoteStyle(note, style),
                              onToggleArchive: () => toggleNoteArchive(note),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Empty State
                if (subFolders.isEmpty && notes.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DsIcon(
                            DsIconKind.book,
                            size: 64,
                            color: theme.disabled,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSearching
                                ? 'notes_noSearchResults'.tr
                                : 'notes_emptyFolder'.tr,
                            style: DsTypography.body.copyWith(
                              color: theme.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
            // FAB（已归档视图为虚拟目录，禁止新建）
            if (!isArchivedView)
              Positioned(bottom: 16, right: 16, child: buildExpandableFab()),
          ],
        );
      },
    );
  }
}
