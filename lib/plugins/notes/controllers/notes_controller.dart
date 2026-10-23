import 'dart:convert';
import 'dart:async';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:aboutme/core/event/item_event_args.dart';
import 'package:aboutme/core/services/plugin_widget_sync_helper.dart';
import 'package:aboutme/plugins/notes/models/folder.dart';
import 'package:aboutme/plugins/notes/models/note.dart';

/// Notes 缓存更新事件参数
class NotesCacheUpdatedEventArgs extends EventArgs {
  final List<Map<String, dynamic>> folders;
  final List<String> noteIds;
  final DateTime cacheDate;

  NotesCacheUpdatedEventArgs({
    required this.folders,
    required this.noteIds,
    required this.cacheDate,
  }) : super('notes_cache_updated');
}

class NotesController {
  final StorageManager _storage; // ignore: unused_field
  final _rawNotes = <String, Map<String, dynamic>>{};
  final _rawFolders = <String, Map<String, dynamic>>{};
  StreamSubscription<QuerySnapshot>? _watch;
  QueryStatus queryStatus = QueryStatus.loading;
  Object? queryError;
  int? _version;
  AboutmeData get _data => AboutmeDataService.instance.data;
  final Map<String, Folder> _folders = {};
  final Map<String, List<Note>> _notes = {};
  final Set<String> _noteIds = {}; // 内存中的笔记ID集合，用于快速访问

  // 发送事件通知
  void _notifyEvent(String action, Note note) {
    final eventArgs = ItemEventArgs(
      eventName: 'note_$action',
      itemId: note.id,
      title: note.title,
      action: action,
    );
    EventManager.instance.broadcast('note_$action', eventArgs);
  }

  NotesController(this._storage);

  Future<void> initialize() async {
    await reloadData();
    _watch ??= _data.watch('notes', 'getSnapshot').listen((snapshot) {
      queryStatus = snapshot.status;
      queryError = snapshot.error;
      if (snapshot.result != null) _apply(snapshot.result!);
      _notifyCacheUpdatedEvent();
    });
  }

  void _apply(Map<String, dynamic> response) {
    final value = response['data'] as Map;
    _version = response['version'] as int?;
    _folders.clear();
    _notes.clear();
    _noteIds.clear();
    _rawNotes.clear();
    _rawFolders.clear();
    for (final raw in value['folders'] as List) {
      final json = Map<String, dynamic>.from(raw as Map);
      final f = Folder.fromJson({...json, '_sdkVersion': _version});
      _folders[f.id] = f;
      _rawFolders[f.id] = json;
    }
    for (final raw in value['notes'] as List) {
      final json = Map<String, dynamic>.from(raw as Map);
      final n = Note.fromJson({...json, '_sdkVersion': _version});
      _notes.putIfAbsent(n.folderId ?? 'root', () => []).add(n);
      _noteIds.add(n.id);
      _rawNotes[n.id] = json;
    }
  }

  Future<void> reloadData() async {
    queryStatus = QueryStatus.loading;
    try {
      _apply(await _data.query('notes', 'getSnapshot'));
      queryStatus = QueryStatus.data;
      queryError = null;
      _notifyCacheUpdatedEvent();
    } catch (e) {
      queryError = e;
      queryStatus = _rawNotes.isEmpty && _rawFolders.isEmpty
          ? QueryStatus.error
          : QueryStatus.stale;
      _notifyCacheUpdatedEvent();
      rethrow;
    }
  }

  Map<String, dynamic> _diff(
    Map<String, dynamic> next,
    Map<String, dynamic>? old,
  ) => {
    for (final e in next.entries)
      if (e.key != 'createdAt' &&
          e.key != 'updatedAt' &&
          (old == null || jsonEncode(old[e.key]) != jsonEncode(e.value)))
        e.key: e.value,
  };
  Future<Map<String, dynamic>> _command(
    String action,
    Map<String, dynamic> params, {
    bool edit = false,
    int? editingVersion,
  }) async {
    final response = await _data.call('notes', action, {
      ...params,
      if (edit && _version != null)
        'expectedVersion': editingVersion ?? _version,
    });
    if (response['success'] != true) throw QueryFailure(response);
    await reloadData();
    await _syncWidget();
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<void> loadSampleFolders() async {
    await _command('seedExamples', {'templateVersion': 1});
  }

  void dispose() {
    _watch?.cancel();
  }

  // 获取文件夹
  Folder? getFolder(String id) {
    return _folders[id];
  }

  // 获取所有文件夹
  List<Folder> getAllFolders() {
    return _folders.values.toList();
  }

  // 获取所有笔记
  Map<String, List<Note>> getAllNotes() {
    return _notes;
  }

  // 获取指定文件夹的子文件夹
  List<Folder> getFolderChildren(String parentId) {
    return _folders.values
        .where((folder) => folder.parentId == parentId)
        .toList();
  }

  /// 获取文件夹的完整路径(从根文件夹到当前文件夹)
  /// 返回包含所有祖先文件夹的列表,顺序为:根 -> ... -> 父 -> 当前
  List<Folder> getFolderPath(String folderId) {
    final path = <Folder>[];
    String? currentId = folderId;

    // 向上遍历,直到根文件夹
    while (currentId != null) {
      final folder = _folders[currentId];
      if (folder == null) break;

      path.insert(0, folder); // 在开头插入,保证顺序正确
      currentId = folder.parentId;
    }

    return path;
  }

  // 获取文件夹中的笔记
  List<Note> getFolderNotes(String folderId) {
    return _notes[folderId] ?? [];
  }

  // 获取所有已归档文件夹
  List<Folder> getArchivedFolders() {
    return _folders.values.where((folder) => folder.isArchived).toList();
  }

  // 获取所有已归档笔记（平铺展示；位于已归档文件夹内的笔记不重复列出，进入文件夹查看）
  List<Note> getArchivedNotes() {
    final archivedFolderIds = _folders.values
        .where((folder) => folder.isArchived)
        .map((folder) => folder.id)
        .toSet();
    return _notes.values
        .expand((notes) => notes)
        .where(
          (note) =>
              note.isArchived &&
              !archivedFolderIds.contains(note.folderId ?? 'root'),
        )
        .toList();
  }

  /// 切换笔记归档状态
  Future<void> toggleNoteArchive(Note note) async {
    await _command(
      'update',
      {'id': note.id, 'isArchived': !note.isArchived},
      edit: true,
      editingVersion: note.sdkVersion,
    );
  }

  /// 切换文件夹归档状态
  Future<void> toggleFolderArchive(Folder folder) async {
    await _command(
      'updateFolder',
      {'id': folder.id, 'isArchived': !folder.isArchived},
      edit: true,
      editingVersion: folder.sdkVersion,
    );
  }

  /// 通过 ID 获取笔记
  Note? getNoteById(String noteId) {
    for (var noteList in _notes.values) {
      for (var note in noteList) {
        if (note.id == noteId) {
          return note;
        }
      }
    }
    return null;
  }

  // 创建新文件夹
  Future<Folder> createFolder(
    String name,
    String? parentId, {
    String? customId,
    Color? color,
  }) async {
    final raw = await _command('createFolder', {
      'id': customId ?? const Uuid().v4(),
      'name': name,
      'parentId': parentId,
      'color': (color ?? Colors.blue).value,
    });
    EventManager.instance.broadcast(
      'note_folder_added',
      EventArgs('note_folder_added'),
    );
    return getFolder(raw['id'] as String)!;
  }

  // 创建新笔记
  Future<Note> createNote(
    String title,
    String content,
    String folderId, {
    String? customId,
    List<String> tags = const [],
    String type = Note.typeText,
    String? meta,
    Color? color,
    int bgStyle = 0,
    String? icon,
  }) async {
    final raw = await _command('create', {
      'id': customId ?? const Uuid().v4(),
      'title': title,
      'content': content,
      'folderId': folderId,
      'tags': tags,
      'type': type,
      'meta': meta,
      'color': color?.value,
      'bgStyle': bgStyle,
      'icon': icon,
    });
    final note = getNoteById(raw['id'] as String)!;
    _notifyEvent('added', note);
    return note;
  }

  // 更新笔记
  Future<void> updateNote(Note note) async {
    await _command(
      'update',
      {'id': note.id, ..._diff(note.toJson(), _rawNotes[note.id])},
      edit: true,
      editingVersion: note.sdkVersion,
    );
    _notifyEvent('updated', getNoteById(note.id) ?? note);
  }

  // 删除笔记
  Future<void> deleteNote(String noteId) async {
    final previous = getNoteById(noteId);
    await _command('delete', {'id': noteId}, edit: true);
    if (previous != null) _notifyEvent('deleted', previous);
  }

  // 通过Note对象删除笔记
  Future<void> deleteNoteObject(Note note) async {
    await deleteNote(note.id);
  }

  // 移动笔记到其他文件夹
  Future<void> moveNote(String noteId, String targetFolderId) async {
    await _command('moveNote', {
      'id': noteId,
      'folderId': targetFolderId,
    }, edit: true);
  }

  // 重命名文件夹（可同时更新标记色）
  Future<void> renameFolder(
    String folderId,
    String newName, {
    Color? color,
  }) async {
    await _command('updateFolder', {
      'id': folderId,
      'name': newName,
      if (color != null) 'color': color.value,
    }, edit: true);
  }

  // 删除文件夹
  // 搜索笔记
  List<Note> searchNotes({
    required String query,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final allNotes = _notes.values.expand((notes) => notes).toList();
    return allNotes.where((note) {
      // 标题和内容匹配
      if (!note.title.toLowerCase().contains(query.toLowerCase()) &&
          !note.content.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }

      // 标签匹配
      if (tags != null && tags.isNotEmpty) {
        if (!tags.any((tag) => note.tags.contains(tag))) {
          return false;
        }
      }

      // 日期范围匹配
      if (startDate != null && note.createdAt.isBefore(startDate)) {
        return false;
      }
      if (endDate != null) {
        final endOfDay = DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
        );
        if (note.createdAt.isAfter(endOfDay)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> deleteFolder(String folderId) async {
    await _command('deleteFolder', {'id': folderId}, edit: true);
  }

  // 同步小组件数据
  Future<void> _syncWidget() async {
    await PluginWidgetSyncHelper.instance.syncNotes();
  }

  /// 触发缓存更新事件（携带最新数据）
  void _notifyCacheUpdatedEvent() {
    final eventArgs = NotesCacheUpdatedEventArgs(
      folders: _folders.values.map((f) => f.toJson()).toList(),
      noteIds: _noteIds.toList(),
      cacheDate: DateTime.now(),
    );
    EventManager.instance.broadcast('notes_cache_updated', eventArgs);
  }
}
