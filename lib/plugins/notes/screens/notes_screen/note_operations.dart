import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/screens/note_edit_screen.dart';
import 'package:aboutme/widgets/rich_editor_screen.dart';
import 'notes_screen_state.dart';

mixin NoteOperations on NotesMainViewState {
  Future<void> createNewNote() async {
    await NavigationHelper.push(
      context,
      NoteEditScreen(
        onSave: (title, content) async {
          await plugin.controller.createNote(title, content, currentFolderId);
        },
      ),
    );
    loadCurrentFolder();
  }

  Future<void> editNote(Note note) async {
    await NavigationHelper.push(
      context,
      RichEditorScreen(
        initialTitle: note.title,
        initialContent: note.content,
        initialTags: note.tags,
        eyebrow: DateFormat.yMMMMd(
          Localizations.localeOf(context).toString(),
        ).format(note.updatedAt),
        texts: RichEditorTexts(
          untitled: 'notes_untitled'.tr,
          emptyContent: 'notes_emptyContent'.tr,
          editTooltip: 'app_edit'.tr,
          deleteTooltip: 'notes_delete'.tr,
          confirmDeleteTitle: 'notes_deleteNote'.tr,
          confirmDeleteMessage: 'notes_deleteNoteConfirm'.tr,
          confirmDelete: 'notes_delete'.tr,
          save: 'app_save'.tr,
          titleHint: 'notes_titleHint'.tr,
          contentHint: 'notes_contentHint'.tr,
        ),
        onSave: (title, content, tags) async {
          final updatedNote = Note(
            id: note.id,
            title: title,
            content: content,
            folderId: note.folderId,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            tags: tags,
          );
          await plugin.controller.updateNote(updatedNote);
        },
        onDelete: () => plugin.controller.deleteNote(note.id),
      ),
    );
    loadCurrentFolder();
  }

  Future<void> deleteNote(Note note) async {
    final confirmed = await showDSDialog<bool>(
      context: context,
      theme: DSThemeBridge.resolve(context),
      builder:
          (_) => DSThemeBridge(
            child: Builder(
              builder:
                  (context) => DSDialog(
                    title: 'notes_deleteNote'.tr,
                    message: 'notes_deleteNoteConfirm'.tr,
                    cancelText: 'app_cancel'.tr,
                    confirmText: 'notes_delete'.tr,
                    confirmVariant: DSButtonVariant.destructive,
                    onCancel: () => Navigator.of(context).pop(false),
                    onConfirm: () => Navigator.of(context).pop(true),
                  ),
            ),
          ),
    );

    if (confirmed == true) {
      await plugin.controller.deleteNote(note.id);
      loadCurrentFolder();
    }
  }
}
