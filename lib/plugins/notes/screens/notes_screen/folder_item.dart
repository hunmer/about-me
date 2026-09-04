import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'folder_operations.dart';
import 'notes_screen_state.dart';

mixin FolderItem on NotesMainViewState, FolderOperations {
  Widget buildFolderItem(Folder folder, int index) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSListItem(
            key: Key('folder_${folder.id}'),
            leading: DsIcon(DsIconKind.layers, color: theme.primary),
            title: folder.name,
            onTap: () => navigateToFolder(folder),
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
                              onTap: () {
                                Navigator.pop(context);
                                renameFolder(folder);
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.trash,
                              label: '删除',
                              destructive: true,
                              onTap: () {
                                Navigator.pop(context);
                                deleteFolder(folder);
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
