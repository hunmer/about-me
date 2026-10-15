import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/note_style_selection.dart';
import 'package:aboutme/plugins/notes/models/todo_item.dart';
import 'package:aboutme/plugins/notes/screens/note_edit_screen.dart';
import 'package:aboutme/plugins/notes/screens/todo_edit_screen.dart';
import 'notes_screen_state.dart';

mixin NoteOperations on NotesMainViewState {
  Future<void> createNewNote() async {
    await NavigationHelper.push(
      context,
      NoteEditScreen(
        onSave: (title, content, tags) async {
          await plugin.controller.createNote(
            title,
            content,
            currentFolderId,
            tags: tags,
          );
        },
      ),
    );
    loadCurrentFolder();
  }

  Future<void> editNote(Note note) async {
    // 待办类型使用专用编辑抽屉
    if (note.isTodo) {
      await TodoEditSheet.show(
        context: context,
        note: note,
        onSave: (title, items, meta, style) async {
          // 直接更新原对象字段（copyWith 无法把已有颜色清回 null）
          note.title = title;
          note.content = TodoItem.encodeList(items);
          note.meta = meta.toJson();
          note.color = style.color;
          note.bgStyle = style.bgStyle;
          note.icon = style.icon;
          note.updatedAt = DateTime.now();
          await plugin.controller.updateNote(note);
        },
      );
      loadCurrentFolder();
      return;
    }
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
            // 编辑保存不改变归档状态
            isArchived: note.isArchived,
          );
          await plugin.controller.updateNote(updatedNote);
        },
      ),
    );
    loadCurrentFolder();
  }

  /// 修改笔记样式（标记色/背景风格/水印图标）并持久化（长按菜单入口）
  Future<void> updateNoteStyle(Note note, NoteStyleSelection style) async {
    note.color = style.color;
    note.bgStyle = style.bgStyle;
    note.icon = style.icon;
    note.updatedAt = DateTime.now();
    await plugin.controller.updateNote(note);
    loadCurrentFolder();
  }

  /// 切换待办条目勾选状态并持久化（同步记录完成时间到 meta）
  Future<void> toggleTodoItem(Note note, int index) async {
    final items = TodoItem.parseList(note.content);
    if (index < 0 || index >= items.length) return;
    items[index].checked = !items[index].checked;

    final meta = TodoMeta.parse(note.meta);
    final text = items[index].text;
    if (items[index].checked) {
      meta.markDone(text, DateTime.now());
    } else {
      meta.doneAt.remove(text);
    }

    await plugin.controller.updateNote(
      note.copyWith(
        content: TodoItem.encodeList(items),
        meta: meta.toJson(),
        updatedAt: DateTime.now(),
      ),
    );
    loadCurrentFolder();
  }

  /// 切换笔记归档状态并持久化（长按菜单入口，笔记与待办共用）
  Future<void> toggleNoteArchive(Note note) async {
    await plugin.controller.toggleNoteArchive(note);
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
