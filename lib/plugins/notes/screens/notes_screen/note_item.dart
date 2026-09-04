import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'folder_selection_dialog.dart';
import 'note_operations.dart';
import 'notes_screen_state.dart';

mixin NoteItem on NotesMainViewState, NoteOperations, FolderSelectionDialog {
  Widget buildNoteItem(Note note, int index) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return DSListItem(
            key: Key('note_${note.id}'),
            leading: DsIcon(DsIconKind.book, color: theme.primary),
            title: note.title,
            subtitle: note.content,
            onTap: () => editNote(note),
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
                                editNote(note);
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.layers,
                              label: 'notes_moveTo'.tr,
                              onTap: () {
                                Navigator.pop(context);
                                moveNote(note);
                              },
                            ),
                            DSSheetAction(
                              icon: DsIconKind.trash,
                              label: '删除',
                              destructive: true,
                              onTap: () {
                                Navigator.pop(context);
                                deleteNote(note);
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
