import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

// Notes 插件专用处理器（移植自 nodejs handlers/notes.ts）。
//
// 数据格式：
// - data.json: 文件夹列表 {"folders": [...]}（folderCrud 默认数据文件）
// - notes/index.json: 笔记 ID 列表 ["id1", "id2", ...]
// - notes/{id}.json: 单个笔记详情

PluginHandlers createNotesHandlers(PluginData data) {
  // 读取所有笔记（从独立文件中）
  Future<List<Map<String, dynamic>>> readAllNotes() async {
    // 读取笔记 ID 列表
    final indexData = await data.read('notes', 'notes/index.json');
    if (indexData is! List) return [];

    final notes = <Map<String, dynamic>>[];
    for (final id in indexData) {
      final noteData = await data.read('notes', 'notes/$id.json');
      if (noteData is Map) {
        notes.add(Map<String, dynamic>.from(noteData));
      }
    }
    return notes;
  }

  // 保存所有笔记（到独立文件）
  Future<void> saveAllNotes(List<Map<String, dynamic>> notes) async {
    // 保存 index.json
    final noteIds = notes.map((n) => n['id']).toList();
    await data.write('notes', 'notes/index.json', noteIds);

    // 保存每个笔记文件
    for (final note in notes) {
      await data.write('notes', 'notes/${note['id']}.json', note);
    }
  }

  // ===== 文件夹 CRUD（移植自 nodejs crud.ts 的 createCrudHandlers('notes', 'folders')）=====

  // 读取文件夹列表
  Future<List<Map<String, dynamic>>> readFolders() async {
    final content = await data.read('notes', 'data.json');
    if (content is List) return List<Map<String, dynamic>>.from(content);
    if (content is Map) {
      final items = content['folders'];
      if (items is List) return List<Map<String, dynamic>>.from(items);
    }
    return [];
  }

  // 保存文件夹列表
  Future<void> saveFolders(List<Map<String, dynamic>> folders) {
    return data.write('notes', 'data.json', {'folders': folders});
  }

  Future<PluginResult> folderGetList(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final folders = await readFolders();
      return PluginResult.success(
        createPaginatedResult(
          folders,
          offset: params['offset'] as int?,
          count: params['count'] as int?,
        ),
      );
    } catch (e) {
      return PluginResult.failure('读取数据失败: $e');
    }
  }

  Future<PluginResult> folderGetById(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final folders = await readFolders();
      final index = folders.indexWhere((f) => f['id'] == params['id']);
      if (index == -1) {
        return const PluginResult.failure('项目不存在', 'NOT_FOUND');
      }
      return PluginResult.success(folders[index]);
    } catch (e) {
      return PluginResult.failure('读取数据失败: $e');
    }
  }

  Future<PluginResult> folderCreate(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final folders = await readFolders();
      final now = jsIsoDateTime(DateTime.now());

      final newFolder = <String, dynamic>{
        ...params,
        'id':
            params['id'] != null && params['id'].toString().isNotEmpty
            ? params['id']
            : generateUUID(),
        'createdAt': now,
        'updatedAt': now,
      };

      folders.add(newFolder);
      await saveFolders(folders);

      return PluginResult.success(newFolder);
    } catch (e) {
      return PluginResult.failure('创建失败: $e');
    }
  }

  Future<PluginResult> folderUpdate(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final folders = await readFolders();
      final index = folders.indexWhere((f) => f['id'] == params['id']);

      if (index == -1) {
        return const PluginResult.failure('项目不存在', 'NOT_FOUND');
      }

      final updatedFolder = <String, dynamic>{
        ...folders[index],
        ...params,
        'updatedAt': jsIsoDateTime(DateTime.now()),
      };
      folders[index] = updatedFolder;

      await saveFolders(folders);
      return PluginResult.success(updatedFolder);
    } catch (e) {
      return PluginResult.failure('更新失败: $e');
    }
  }

  Future<PluginResult> folderDelete(
    PluginData data,
    Map<String, dynamic> params,
  ) async {
    try {
      final folders = await readFolders();
      final index = folders.indexWhere((f) => f['id'] == params['id']);

      if (index == -1) {
        return const PluginResult.failure('项目不存在', 'NOT_FOUND');
      }

      folders.removeAt(index);
      await saveFolders(folders);

      return PluginResult.success({'id': params['id']});
    } catch (e) {
      return PluginResult.failure('删除失败: $e');
    }
  }

  return {
    // folderCrud 展开后的条目（Folder + 首字母大写的 handler 名）
    'FolderGetList': folderGetList,
    'FolderGetById': folderGetById,
    'FolderCreate': folderCreate,
    'FolderUpdate': folderUpdate,
    'FolderDelete': folderDelete,

    // 获取笔记列表
    'getList': (data, params) async {
      try {
        var notes = await readAllNotes();

        // 按文件夹过滤
        final folderId = params['folderId'];
        if (folderId != null && folderId.toString().isNotEmpty) {
          notes = notes.where((n) => n['folderId'] == folderId).toList();
        }

        return PluginResult.success(
          createPaginatedResult(
            notes,
            offset: params['offset'] as int?,
            count: params['count'] as int?,
          ),
        );
      } catch (e) {
        return PluginResult.failure('获取笔记失败: $e');
      }
    },

    // 根据 ID 获取笔记
    'getById': (data, params) async {
      try {
        final notes = await readAllNotes();
        final index = notes.indexWhere((n) => n['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('笔记不存在', 'NOT_FOUND');
        }

        return PluginResult.success(notes[index]);
      } catch (e) {
        return PluginResult.failure('获取笔记失败: $e');
      }
    },

    // 创建笔记
    'create': (data, params) async {
      try {
        final notes = await readAllNotes();
        final now = jsIsoDateTime(DateTime.now());

        final newNote = <String, dynamic>{
          ...params,
          'id':
              params['id'] != null && params['id'].toString().isNotEmpty
              ? params['id']
              : generateUUID(),
          'createdAt': now,
          'updatedAt': now,
        };

        notes.add(newNote);
        await saveAllNotes(notes);

        return PluginResult.success(newNote);
      } catch (e) {
        return PluginResult.failure('创建笔记失败: $e');
      }
    },

    // 更新笔记
    'update': (data, params) async {
      try {
        final notes = await readAllNotes();
        final index = notes.indexWhere((n) => n['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('笔记不存在', 'NOT_FOUND');
        }

        final updatedNote = <String, dynamic>{
          ...notes[index],
          ...params,
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };
        notes[index] = updatedNote;

        await saveAllNotes(notes);
        return PluginResult.success(updatedNote);
      } catch (e) {
        return PluginResult.failure('更新笔记失败: $e');
      }
    },

    // 删除笔记
    'delete': (data, params) async {
      try {
        final notes = await readAllNotes();
        final filtered = notes.where((n) => n['id'] != params['id']).toList();

        if (filtered.length == notes.length) {
          return const PluginResult.failure('笔记不存在', 'NOT_FOUND');
        }

        await saveAllNotes(filtered);
        return PluginResult.success({'id': params['id']});
      } catch (e) {
        return PluginResult.failure('删除笔记失败: $e');
      }
    },

    // 获取文件夹列表
    'getFolders': folderGetList,

    'getFolderById': folderGetById,

    'createFolder': folderCreate,

    'updateFolder': folderUpdate,

    'deleteFolder': folderDelete,

    // 移动笔记
    'moveNote': (data, params) async {
      try {
        final notes = await readAllNotes();
        final index = notes.indexWhere((n) => n['id'] == params['id']);

        if (index == -1) {
          return const PluginResult.failure('笔记不存在', 'NOT_FOUND');
        }

        notes[index] = <String, dynamic>{
          ...notes[index],
          'folderId': params['folderId'],
          'updatedAt': jsIsoDateTime(DateTime.now()),
        };

        await saveAllNotes(notes);
        return PluginResult.success(notes[index]);
      } catch (e) {
        return PluginResult.failure('移动笔记失败: $e');
      }
    },

    // 获取文件夹的笔记
    'getFolderNotes': (data, params) async {
      try {
        final folderId = params['id'];
        var notes = await readAllNotes();

        notes = notes.where((n) => n['folderId'] == folderId).toList();

        return PluginResult.success({'data': notes, 'total': notes.length});
      } catch (e) {
        return PluginResult.failure('获取笔记失败: $e');
      }
    },

    // 搜索笔记
    'search': (data, params) async {
      try {
        final keyword = params['keyword'];
        final folderId = params['folderId'];
        var notes = await readAllNotes();

        if (folderId != null && folderId.toString().isNotEmpty) {
          notes = notes.where((n) => n['folderId'] == folderId).toList();
        }
        if (keyword != null && keyword.toString().isNotEmpty) {
          final kw = keyword.toString().toLowerCase();
          notes = notes
              .where(
                (n) =>
                    (n['title'] ?? '').toString().toLowerCase().contains(kw) ||
                    (n['content'] ?? '').toString().toLowerCase().contains(kw),
              )
              .toList();
        }

        return PluginResult.success({'data': notes, 'total': notes.length});
      } catch (e) {
        return PluginResult.failure('搜索失败: $e');
      }
    },
  };
}
