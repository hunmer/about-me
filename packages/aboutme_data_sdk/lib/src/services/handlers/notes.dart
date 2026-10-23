import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

/// Index, note and folder changes execute in the shared SDK transaction.
PluginHandlers createNotesHandlers(PluginData data) {
  Map<String, dynamic> object(dynamic v) {
    if (v is! Map)
      throw const StorageException(StorageErrorKind.invalidData, '笔记数据损坏');
    return Map<String, dynamic>.from(v);
  }

  Future<List<Map<String, dynamic>>> folders() async {
    List<Map<String, dynamic>> decode(dynamic v) {
      if (v == null) return [];
      final xs = v is Map ? v['folders'] : v;
      if (xs is! List)
        throw const StorageException(StorageErrorKind.invalidData, '文件夹数据损坏');
      return xs.map(object).toList();
    }

    final merged = <String, Map<String, dynamic>>{};
    for (final f in [
      ...decode(await data.read('notes', 'data.json')),
      ...decode(await data.read('notes', 'folders.json')),
    ]) {
      final id = f['id'];
      if (id is! String || id.isEmpty) throw const FormatException('文件夹缺少ID');
      merged[id] = {...?merged[id], ...f};
    }
    return merged.values.toList();
  }

  Future<List<Map<String, dynamic>>> notes() async {
    final ids = await data.read('notes', 'notes/index.json');
    if (ids == null) return [];
    if (ids is! List)
      throw const StorageException(StorageErrorKind.invalidData, '笔记索引损坏');
    final result = <Map<String, dynamic>>[], seen = <String>{};
    for (final id in ids) {
      if (id is! String ||
          id.contains('/') ||
          id.contains('\\') ||
          !seen.add(id))
        throw const FormatException('笔记索引ID无效或重复');
      final n = object(await data.read('notes', 'notes/$id.json'));
      if (n['id'] != id)
        throw const StorageException(
          StorageErrorKind.invalidData,
          '笔记与索引ID不一致',
        );
      result.add(n);
    }
    return result;
  }

  Future<void> backup() async {
    if (await data.read('notes', 'migration_v1_backup.json') != null) return;
    await data.write('notes', 'migration_v1_backup.json', {
      'schemaVersion': 1,
      'folders': await folders(),
      'notes': await notes(),
      'originalFolders': await data.read('notes', 'folders.json'),
      'originalData': await data.read('notes', 'data.json'),
    });
  }

  void target(List<Map<String, dynamic>> fs, dynamic id) {
    if (id != null && id != 'root' && !fs.any((f) => f['id'] == id))
      throw const FormatException('目标文件夹不存在');
  }

  Future<PluginResult> list(Map<String, dynamic> p) async {
    var ns = await notes();
    if (p['folderId'] != null)
      ns = ns.where((n) => n['folderId'] == p['folderId']).toList();
    final q = (p['keyword'] ?? '').toString().toLowerCase();
    ns = ns
        .where(
          (n) => (n['title'].toString() + ' ' + n['content'].toString())
              .toLowerCase()
              .contains(q),
        )
        .toList();
    ns.sort((a, b) => a['id'].toString().compareTo(b['id'].toString()));
    return PluginResult.success(
      createPaginatedResult(
        ns,
        offset: p['offset'] as int?,
        count: p['count'] as int?,
      ),
    );
  }

  Future<PluginResult> save(
    Map<String, dynamic> p,
    bool folder,
    bool create,
  ) async {
    final fs = await folders(), ns = await notes(), items = folder ? fs : ns;
    final id = p['id'] ?? generateUUID();
    if (id is! String ||
        id.isEmpty ||
        id.contains('/') ||
        id.contains('\\') ||
        {'index', '.', '..'}.contains(id))
      throw const FormatException('ID无效');
    final i = items.indexWhere((x) => x['id'] == id);
    if (create && i >= 0)
      return const PluginResult.failure('ID已存在', 'CONFLICT');
    if (!create && i < 0)
      return const PluginResult.failure('项目不存在', 'NOT_FOUND');
    final patch = Map<String, dynamic>.from(p)
      ..remove('id')
      ..remove('createdAt')
      ..remove('updatedAt');
    final now = jsIsoDateTime(DateTime.now());
    final next = <String, dynamic>{
      if (i >= 0) ...items[i],
      ...patch,
      'id': id,
      'createdAt': i >= 0 ? items[i]['createdAt'] : now,
      'updatedAt': now,
    };
    if (next[folder ? 'name' : 'title'] is! String)
      throw const FormatException('标题必须为字符串');
    if (folder) {
      target(fs, next['parentId']);
      final visited = <dynamic>{id};
      dynamic parent = next['parentId'];
      while (parent != null && parent != 'root') {
        if (!visited.add(parent))
          throw const FormatException('文件夹不能移动到自身或子文件夹');
        parent = fs.firstWhere((f) => f['id'] == parent)['parentId'];
      }
    } else {
      target(fs, next['folderId']);
      next.putIfAbsent('content', () => '');
      next.putIfAbsent('tags', () => []);
      if (next['content'] is! String || next['tags'] is! List)
        throw const FormatException('笔记内容或标签无效');
    }
    await backup();
    if (i < 0) {
      items.add(next);
    } else {
      items[i] = next;
    }
    if (folder) {
      await data.write('notes', 'folders.json', fs);
    } else {
      await data.write('notes', 'notes/$id.json', next);
      if (create)
        await data.write(
          'notes',
          'notes/index.json',
          ns.map((n) => n['id']).toList(),
        );
    }
    return PluginResult.success(next);
  }

  Future<PluginResult> remove(Map<String, dynamic> p, bool folder) async {
    final fs = await folders(), ns = await notes(), id = p['id'];
    if (!(folder ? fs : ns).any((x) => x['id'] == id))
      return const PluginResult.failure('项目不存在', 'NOT_FOUND');
    final removed = <dynamic>{id};
    if (folder) {
      bool changed = true;
      while (changed) {
        changed = false;
        for (final f in fs) {
          if (removed.contains(f['parentId']) && removed.add(f['id']))
            changed = true;
        }
      }
    }
    await backup();
    final deleted = ns
        .where((n) => folder ? removed.contains(n['folderId']) : n['id'] == id)
        .toList();
    for (final n in deleted) {
      await data.delete('notes', 'notes/' + n['id'].toString() + '.json');
    }
    ns.removeWhere((n) => deleted.contains(n));
    await data.write(
      'notes',
      'notes/index.json',
      ns.map((n) => n['id']).toList(),
    );
    if (folder) {
      fs.removeWhere((f) => removed.contains(f['id']));
      await data.write('notes', 'folders.json', fs);
      final old = await data.read('notes', 'data.json');
      if (old != null)
        await data.write('notes', 'data.json', {
          if (old is Map) ...Map<String, dynamic>.from(old),
          'folders': fs,
        });
    }
    return PluginResult.success({'id': id});
  }

  Future<PluginResult> folderList(Map<String, dynamic> p) async =>
      PluginResult.success(
        createPaginatedResult(
          await folders(),
          offset: p['offset'] as int?,
          count: p['count'] as int?,
        ),
      );
  Future<PluginResult> byId(Map<String, dynamic> p, bool folder) async {
    for (final x in folder ? await folders() : await notes()) {
      if (x['id'] == p['id']) return PluginResult.success(x);
    }
    return const PluginResult.failure('项目不存在', 'NOT_FOUND');
  }

  final handlers = <String, PluginHandler>{
    'getSnapshot': (_, p) async => PluginResult.success({
      'folders': await folders(),
      'notes': await notes(),
    }),
    'getList': (_, p) => list(p),
    'search': (_, p) => list(p),
    'getById': (_, p) => byId(p, false),
    'create': (_, p) => save(p, false, true),
    'update': (_, p) => save(p, false, false),
    'delete': (_, p) => remove(p, false),
    'moveNote': (_, p) =>
        save({'id': p['id'], 'folderId': p['folderId']}, false, false),
    'getFolders': (_, p) => folderList(p),
    'getFolderById': (_, p) => byId(p, true),
    'createFolder': (_, p) => save(p, true, true),
    'updateFolder': (_, p) => save(p, true, false),
    'deleteFolder': (_, p) => remove(p, true),
    'getFolderNotes': (_, p) => list({...p, 'folderId': p['id']}),
    'seedExamples': (_, p) async {
      const id = 'notes-example-welcome-v1', noteId = 'notes-example-intro-v1';
      if (!(await folders()).any((f) => f['id'] == id))
        await save({'id': id, 'name': '示例笔记'}, true, true);
      if (!(await notes()).any((n) => n['id'] == noteId))
        await save(
          {
            'id': noteId,
            'folderId': id,
            'title': '欢迎使用笔记',
            'content': '记录想法，支持文件夹、标签与待办清单。',
            'seedKey': noteId,
          },
          false,
          true,
        );
      return const PluginResult.success({'templateVersion': 1});
    },
  };
  for (final e in {
    'FolderGetList': 'getFolders',
    'FolderGetById': 'getFolderById',
    'FolderCreate': 'createFolder',
    'FolderUpdate': 'updateFolder',
    'FolderDelete': 'deleteFolder',
  }.entries) {
    handlers[e.key] = handlers[e.value]!;
  }
  return handlers;
}
