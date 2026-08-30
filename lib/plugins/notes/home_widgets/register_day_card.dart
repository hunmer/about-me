/// 笔记插件 - 笔记日卡小组件注册（按日期聚合）
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:Memento/screens/home_screen/managers/home_widget_registry.dart';
import 'package:Memento/screens/home_screen/managers/home_date_controller.dart';
import 'package:Memento/screens/home_screen/models/home_widget_size.dart';
import 'package:Memento/screens/home_screen/widgets/home_widget.dart';
import 'package:Memento/widgets/event_listener_container.dart';
import 'package:Memento/core/navigation/navigation_helper.dart';
import 'package:Memento/plugins/notes/notes_plugin.dart';
import 'package:Memento/plugins/notes/models/note.dart';
import 'package:Memento/plugins/notes/screens/note_edit_screen.dart';
import 'package:Memento/plugins/notes/widgets/note_day_card.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// 获取指定日期创建/修改的笔记（按修改时间倒序）
List<Note> _notesForDate(DateTime date) {
  final notes =
      NotesPlugin.instance.controller.getAllNotes().values
          .expand((notes) => notes)
          .where(
            (note) =>
                _isSameDay(note.updatedAt, date) ||
                _isSameDay(note.createdAt, date),
          )
          .toList();
  notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return notes;
}

/// 打开笔记编辑页（与插件页 note_operations 一致）
void _editNote(BuildContext context, Note note) {
  final controller = NotesPlugin.instance.controller;
  NavigationHelper.push(
    context,
    NoteEditScreen(
      note: note,
      onSave: (title, content) async {
        final updatedNote = Note(
          id: note.id,
          title: title,
          content: content,
          folderId: note.folderId,
          createdAt: note.createdAt,
          updatedAt: DateTime.now(),
          tags: note.tags,
        );
        await controller.updateNote(updatedNote);
      },
    ),
  );
}

/// 打开新建笔记页（保存到根目录）
void _createNote(BuildContext context) {
  final controller = NotesPlugin.instance.controller;
  NavigationHelper.push(
    context,
    NoteEditScreen(
      onSave: (title, content) async {
        await controller.createNote(title, content, 'root');
      },
    ),
  );
}

/// 注册笔记日卡小组件（展示主页选中日期创建/修改的笔记）
void registerDayCardWidget(HomeWidgetRegistry registry) {
  registry.register(
    HomeWidget(
      id: 'notes_day_card',
      pluginId: 'notes',
      name: 'notes_dayCardName'.tr,
      description: 'notes_dayCardDesc'.tr,
      icon: Icons.note,
      color: const Color.fromARGB(255, 61, 204, 185),
      defaultSize: const LargeSize(),
      supportedSizes: const [
        LargeSize(),
        Large3Size(),
        Wide2Size(),
        Wide3Size(),
      ],
      category: 'home_categoryRecord'.tr,
      isDateDriven: true,
      hasDateData: (date) async {
        try {
          return _notesForDate(date).isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      builder: (context, config) => const _NotesDayCardHomeWidget(),
    ),
  );
}

/// 笔记日卡内容：读取主页选中日期的笔记并用 NoteDayCard 渲染
class _NotesDayCardHomeWidget extends StatefulWidget {
  const _NotesDayCardHomeWidget();

  @override
  State<_NotesDayCardHomeWidget> createState() =>
      _NotesDayCardHomeWidgetState();
}

class _NotesDayCardHomeWidgetState extends State<_NotesDayCardHomeWidget> {
  @override
  void initState() {
    super.initState();
    HomeDateController().addListener(_reload);
  }

  @override
  void dispose() {
    HomeDateController().removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerContainer(
      events: const [
        'note_added',
        'note_updated',
        'note_deleted',
        'notes_refresh',
      ],
      onEvent: _reload,
      child: Builder(
        builder: (context) {
          try {
            return NoteDayCard(
              date: HomeDateController().date,
              notes: _notesForDate(HomeDateController().date),
              onNoteTap: (note) => _editNote(context, note),
              onAddNote: () => _createNote(context),
            );
          } catch (e) {
            return HomeWidget.buildErrorWidget(context, e.toString());
          }
        },
      ),
    );
  }
}
