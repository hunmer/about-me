import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

class NotesAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Folder? currentFolder;
  final bool isSearching;
  final TextEditingController searchController;
  final VoidCallback onNavigateBack;
  final VoidCallback onSearchToggle;
  final Function(String) onSearch;
  final VoidCallback onCreateNewNote;
  final VoidCallback onCreateNewFolder;

  const NotesAppBar({
    super.key,
    required this.currentFolder,
    required this.isSearching,
    required this.searchController,
    required this.onNavigateBack,
    required this.onSearchToggle,
    required this.onSearch,
    required this.onCreateNewNote,
    required this.onCreateNewFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return AppBar(
      leading:
          currentFolder?.parentId != null
              ? IconButton(
                icon: DsIcon(DsIconKind.chevronLeft, color: theme.text),
                onPressed: onNavigateBack,
              )
              : null,
      title:
          isSearching
              ? TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: '搜索笔记...',
                  border: InputBorder.none,
                ),
                onChanged: onSearch,
              )
              : Text(currentFolder?.name ?? 'Notes'),
      actions: [
        IconButton(
          icon: DsIcon(
            isSearching ? DsIconKind.close : DsIconKind.search,
            color: theme.text,
          ),
          onPressed: onSearchToggle,
        ),
        // 菜单气泡经根 Overlay 展示，需包主题桥
        DSThemeBridge(
          child: Builder(
            builder: (context) {
              final theme = DSThemeBridge.resolve(context);
              return DSPopover(
                width: 180,
                contentBuilder: (context, close) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SmoothSheetAction(
                        icon: DsIconKind.book,
                        label: 'notes_newNote'.tr,
                        onTap: () {
                          close();
                          onCreateNewNote();
                        },
                      ),
                      SmoothSheetAction(
                        icon: DsIconKind.layers,
                        label: 'notes_newFolder'.tr,
                        onTap: () {
                          close();
                          onCreateNewFolder();
                        },
                      ),
                    ],
                  );
                },
                child: DsIcon(DsIconKind.more, color: theme.text),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
