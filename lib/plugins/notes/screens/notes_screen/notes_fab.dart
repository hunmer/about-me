import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/notes/models/note.dart';
import 'package:aboutme/plugins/notes/models/todo_item.dart';
import 'package:aboutme/plugins/notes/screens/todo_edit_screen.dart';
import 'package:aboutme/widgets/expandable_fab.dart';
import 'folder_operations.dart';
import 'note_operations.dart';
import 'notes_screen_state.dart';

/// Notes 首页展开式 FAB（新建文件夹 / 笔记 / 待办），视觉与交互由
/// 公共组件 [ExpandableFab] 提供
mixin NotesFab on NotesMainViewState, NoteOperations, FolderOperations {
  Widget buildExpandableFab() {
    return ExpandableFab(
      icon: DsIconKind.plus,
      actions: [
        ExpandableFabAction(
          icon: DsIconKind.layers,
          label: 'notes_newFolder'.tr,
          onPressed: createNewFolder,
        ),
        ExpandableFabAction(
          icon: DsIconKind.book,
          label: 'notes_newNote'.tr,
          // 新建笔记直接进入全屏富文本编辑器
          onPressed: createNewNote,
        ),
        ExpandableFabAction(
          icon: DsIconKind.check,
          label: 'notes_newTodo'.tr,
          onPressed: () {
            TodoEditSheet.show(
              context: context,
              onSave: (title, items, meta, style) async {
                await plugin.controller.createNote(
                  title,
                  TodoItem.encodeList(items),
                  currentFolderId,
                  type: Note.typeTodo,
                  meta: meta.toJson(),
                  color: style.color,
                  bgStyle: style.bgStyle,
                  icon: style.icon,
                );
                loadCurrentFolder();
              },
            );
          },
        ),
      ],
    );
  }
}
