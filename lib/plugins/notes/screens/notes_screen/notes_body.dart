import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skribble/skribble.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/folder_breadcrumbs.dart';
import 'note_card.dart';
import 'note_operations.dart';
import 'notes_fab.dart';
import 'notes_screen_state.dart';

mixin NotesBody on NotesMainViewState, NoteOperations, NotesFab {
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

                // Subfolders Horizontal List (子文件夹列表)
                if (subFolders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: subFolders.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final folder = subFolders[index];
                          return Center(
                            child: DSChip(
                              label: folder.name,
                              icon: DsIconKind.layers,
                              onSelected: (_) => navigateToFolder(folder),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Notes Grid
                if (notes.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        // 列表项挂载时墨线描画入场
                        return WiredDraw(
                          child: NoteCard(
                            note: note,
                            onTap: () => editNote(note),
                            onDelete: () => deleteNote(note),
                            onToggle: note.isTodo
                                ? (i) => toggleTodoItem(note, i)
                                : null,
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
