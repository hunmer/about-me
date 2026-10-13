import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/folder_breadcrumbs.dart';
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
    final path = plugin.controller.getFolderPath(currentFolderId);
    return path.map((folder) {
      return FolderBreadcrumbItem(id: folder.id, name: folder.name);
    }).toList();
  }

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
                if (subFolders.isNotEmpty || notes.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childCount: subFolders.length + notes.length,
                      itemBuilder: (context, index) {
                        // 列表项挂载时墨线描画入场
                        if (index < subFolders.length) {
                          final folder = subFolders[index];
                          return WiredDraw(
                            child: FolderCard(
                              folder: folder,
                              noteCount:
                                  plugin.controller
                                      .getFolderNotes(folder.id)
                                      .length,
                              onTap: () => navigateToFolder(folder),
                              onEdit: () => renameFolder(folder),
                              onDelete: () => deleteFolder(folder),
                            ),
                          );
                        }
                        final note = notes[index - subFolders.length];
                        return WiredDraw(
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
            // FAB
            Positioned(bottom: 16, right: 16, child: buildExpandableFab()),
          ],
        );
      },
    );
  }
}
