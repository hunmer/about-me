import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'note_operations.dart';

class NoteListTile extends StatelessWidget {
  final Note note;
  final NotesController controller;
  final VoidCallback onReload;
  final Future<Folder?> Function(Note?, {Folder? parentFolder})
  onShowFolderSelectionDialog;

  const NoteListTile({
    super.key,
    required this.note,
    required this.controller,
    required this.onReload,
    required this.onShowFolderSelectionDialog,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSListItem(
            leading: DsIcon(DsIconKind.book, color: theme.primary),
            title: note.title,
            subtitle: note.content,
            onTap: () => editNote(context, controller, note, onReload),
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
                              label: 'app_edit'.tr,
                              onTap: () {
                                Navigator.pop(context);
                                editNote(context, controller, note, onReload);
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.layers,
                              label: 'notes_moveTo'.tr,
                              onTap: () async {
                                Navigator.pop(context);
                                await moveNoteDialog(
                                  context,
                                  controller,
                                  note,
                                  onReload,
                                  onShowFolderSelectionDialog,
                                );
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.trash,
                              label: '删除',
                              destructive: true,
                              onTap: () async {
                                Navigator.pop(context);
                                await deleteNoteDialog(
                                  context,
                                  controller,
                                  note,
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
