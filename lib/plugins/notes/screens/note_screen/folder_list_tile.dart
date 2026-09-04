import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'folder_operations.dart';

class FolderListTile extends StatelessWidget {
  final Folder folder;
  final NotesController controller;
  final Function(Folder) onNavigateToFolder;
  final VoidCallback onReload;

  const FolderListTile({
    super.key,
    required this.folder,
    required this.controller,
    required this.onNavigateToFolder,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSListItem(
            leading: DsIcon(DsIconKind.layers, color: theme.primary),
            title: folder.name,
            onTap: () => onNavigateToFolder(folder),
            trailing: DSIconButton(
              icon: DsIconKind.more,
              size: 34,
              color: theme.surface,
              iconColor: theme.text,
              onPressed: () {
                SmoothBottomSheet.show(
                  context: context,
                  builder:
                      (context) => DSThemeBridge(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DSSheetAction(
                              icon: DsIconKind.edit,
                              label: 'app_rename'.tr,
                              onTap: () async {
                                Navigator.pop(context);
                                await renameFolderDialog(
                                  context,
                                  controller,
                                  folder,
                                  onReload,
                                );
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.trash,
                              label: '删除',
                              destructive: true,
                              onTap: () async {
                                Navigator.pop(context);
                                await deleteFolderDialog(
                                  context,
                                  controller,
                                  folder,
                                  onReload,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
