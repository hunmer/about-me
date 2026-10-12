import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/controllers/notes_controller.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/screens/note_edit_screen.dart';
import 'package:aboutme/core/services/toast_service.dart';

// 创建新笔记
Future<void> createNewNote(
  BuildContext context,
  NotesController controller,
  String currentFolderId,
  VoidCallback onReload,
) async {
  await NavigationHelper.push(
    context,
    NoteEditScreen(
      onSave: (title, content, tags) async {
        await controller.createNote(title, content, currentFolderId, tags: tags);
      },
    ),
  );
  onReload();
}

// 编辑笔记
Future<void> editNote(
  BuildContext context,
  NotesController controller,
  Note note,
  VoidCallback onReload,
) async {
  await NavigationHelper.push(
    context,
    NoteEditScreen(
      note: note,
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
        await controller.updateNote(updatedNote);
      },
    ),
  );
  onReload();
}

// 移动笔记
Future<void> moveNoteDialog(
  BuildContext context,
  NotesController controller,
  Note note,
  VoidCallback onReload,
  Future<Folder?> Function(Note?, {Folder? parentFolder})
  onShowFolderSelectionDialog,
) async {
  final targetFolder = await onShowFolderSelectionDialog(note);
  if (targetFolder != null) {
    await controller.moveNote(note.id, targetFolder.id);
    onReload();
    if (context.mounted) {
      toastService.showToast(
        'notes_movedToFolder'.trParams({'folderName': targetFolder.name}),
      );
    }
  }
}

// 删除笔记
Future<void> deleteNoteDialog(
  BuildContext context,
  NotesController controller,
  Note note,
  VoidCallback onReload,
) async {
  final confirmed = await showDSDialog<bool>(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder:
        (_) => DSThemeBridge(
          child: Builder(
            builder:
                (context) => DSDialog(
                  title: 'notes_deleteNote'.tr,
                  message: 'notes_deleteNoteConfirmation'.tr,
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
    await controller.deleteNote(note.id);
    onReload();
  }
}
