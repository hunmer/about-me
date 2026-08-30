/// 笔记插件 - 快速创建项注册
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/quick_create_registry.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/notes/notes_plugin.dart';
import 'package:Memento/plugins/notes/screens/note_edit_screen.dart';

/// 注册笔记的快速创建项（主页底部 ＋ 按钮）
///
/// 笔记无日期字段，不预填日期，保存到根目录。
void registerQuickCreate(QuickCreateRegistry registry) {
  registry.register(
    QuickCreateItem(
      id: 'notes_note',
      pluginId: 'notes',
      name: 'notes_newNote'.tr,
      icon: Icons.note,
      color: const Color.fromARGB(255, 61, 204, 185),
      onCreate: (context, date) {
        final controller = NotesPlugin.instance.controller;
        NavigationHelper.push(
          context,
          NoteEditScreen(
            onSave: (title, content) async {
              await controller.createNote(title, content, 'root');
            },
          ),
        );
      },
    ),
  );
}
