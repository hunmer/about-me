import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';

/// Tree commands always read the latest notebook; entity edits never replace children.
PluginHandlers createNodesHandlers(PluginData data) {
  Future<Map<String, dynamic>> state() async {
    final value = await data.read('nodes', 'nodes_notebooks.json');
    if (value == null) return {'notebooks': <Map<String, dynamic>>[]};
    if (value is! Map || value['notebooks'] is! List)
      throw const StorageException(StorageErrorKind.invalidData, '笔记本数据损坏');
    final result = Map<String, dynamic>.from(value);
    final ids = <String>{};
    void validate(List xs, String parent) {
      for (final x in xs) {
        if (x is! Map<String, dynamic> ||
            x['id'] is! String ||
            !ids.add(x['id'] as String) ||
            x['children'] is! List)
          throw const StorageException(
            StorageErrorKind.invalidData,
            '节点结构或ID损坏',
          );
        if ((x['parentId'] ?? '') != parent)
          throw const StorageException(
            StorageErrorKind.invalidData,
            '节点父引用与树结构不一致',
          );
        validate(x['children'] as List, x['id'] as String);
      }
    }

    final notebooks = <String>{};
    for (final nb in result['notebooks'] as List) {
      if (nb is! Map<String, dynamic> ||
          nb['id'] is! String ||
          !notebooks.add(nb['id']) ||
          nb['nodes'] is! List)
        throw const StorageException(StorageErrorKind.invalidData, '笔记本结构损坏');
      validate(nb['nodes'] as List, '');
    }
    return result;
  }

  Future<void> persist(Map<String, dynamic> s) async {
    if (await data.read('nodes', 'migration_v1_backup.json') == null) {
      await data.write('nodes', 'migration_v1_backup.json', {
        'schemaVersion': 1,
        'original': await data.read('nodes', 'nodes_notebooks.json'),
      });
    }
    await data.write('nodes', 'nodes_notebooks.json', s);
  }

  Map<String, dynamic> notebook(Map<String, dynamic> s, dynamic id) {
    for (final nb in s['notebooks'] as List) {
      if (nb['id'] == id) return nb as Map<String, dynamic>;
    }
    throw const _Missing();
  }

  Map<String, dynamic>? find(List xs, dynamic id) {
    for (final n in xs) {
      if (n['id'] == id) return n as Map<String, dynamic>;
      final child = find(n['children'] as List, id);
      if (child != null) return child;
    }
    return null;
  }

  Map<String, dynamic>? detach(List xs, dynamic id) {
    for (var i = 0; i < xs.length; i++) {
      final n = xs[i] as Map<String, dynamic>;
      if (n['id'] == id) {
        xs.removeAt(i);
        return n;
      }
      final found = detach(n['children'] as List, id);
      if (found != null) return found;
    }
    return null;
  }

  Map<String, dynamic> patch(Map<String, dynamic> p) =>
      Map<String, dynamic>.from(p)
        ..remove('notebookId')
        ..remove('id')
        ..remove('nodes')
        ..remove('children')
        ..remove('createdAt')
        ..remove('index');
  Future<PluginResult> command(String action, Map<String, dynamic> p) async {
    final s = await state();
    final nbs = s['notebooks'] as List;
    final id = p['id'] ?? generateUUID();
    if (id is! String || id.isEmpty) throw const FormatException('ID无效');
    dynamic result;
    if (action == 'createNotebook') {
      if (nbs.any((x) => x['id'] == id))
        return const PluginResult.failure('ID已存在', 'CONFLICT');
      if (p['title'] is! String) throw const FormatException('标题必须为字符串');
      result = {
        'id': id,
        ...patch(p),
        'nodes': <dynamic>[],
        'icon': p['icon'] ?? 0xe0ef,
        'color': p['color'] ?? 0xff2196f3,
      };
      nbs.add(result);
    } else if (action == 'reorderNotebooks') {
      final ids = p['ids'];
      if (ids is! List ||
          ids.length != nbs.length ||
          ids.toSet().length != ids.length ||
          !ids.every((id) => nbs.any((n) => n['id'] == id)))
        throw const FormatException('排序必须包含全部笔记本ID');
      s['notebooks'] = ids
          .map((id) => nbs.firstWhere((n) => n['id'] == id))
          .toList();
      result = {'ids': ids};
    } else if (action == 'seedExamples') {
      const sampleId = 'nodes-example-welcome-v1';
      if (!nbs.any((n) => n['id'] == sampleId))
        nbs.add({
          'id': sampleId,
          'title': '示例笔记本',
          'icon': 0xe0ef,
          'color': 0xff2196f3,
          'seedKey': sampleId,
          'nodes': [
            {
              'id': 'nodes-example-intro-v1',
              'title': '欢迎使用节点',
              'createdAt': jsIsoDateTime(DateTime.now()),
              'tags': [],
              'status': 0,
              'customFields': [],
              'notes': '使用子节点整理想法和任务。',
              'parentId': '',
              'children': [],
              'pathValue': '',
              'color': 0xff9e9e9e,
            },
          ],
        });
      result = {'templateVersion': 1};
    } else {
      final nb = notebook(s, p['notebookId'] ?? id);
      final roots = nb['nodes'] as List;
      switch (action) {
        case 'updateNotebook':
          if (p.containsKey('title') && p['title'] is! String)
            throw const FormatException('标题必须为字符串');
          nb.addAll(patch(p));
          result = nb;
        case 'deleteNotebook':
          nbs.remove(nb);
          result = {'id': id};
        case 'clearNodes':
          roots.clear();
          result = {'notebookId': nb['id']};
        case 'createNode':
          if (nbs.any((b) => find(b['nodes'] as List, id) != null))
            return const PluginResult.failure('节点ID已存在', 'CONFLICT');
          final parent = p['parentId'] ?? '';
          final parentNode = parent == '' ? null : find(roots, parent);
          if (parent != '' && parentNode == null)
            throw const FormatException('父节点不存在');
          if (p['title'] is! String) throw const FormatException('标题必须为字符串');
          result = {
            'id': id,
            'title': p['title'],
            'createdAt': jsIsoDateTime(DateTime.now()),
            'tags': [],
            'status': 0,
            'customFields': [],
            'notes': '',
            'pathValue': '',
            'color': 0xff9e9e9e,
            ...patch(p),
            'parentId': parent,
            'children': <dynamic>[],
          };
          (parentNode == null ? roots : parentNode['children'] as List).add(
            result,
          );
        case 'updateNode':
          final n = find(roots, id);
          if (n == null) throw const _Missing();
          if (p.containsKey('title') && p['title'] is! String)
            throw const FormatException('标题必须为字符串');
          final parent = p.containsKey('parentId')
              ? p['parentId']
              : n['parentId'];
          if (parent is! String) throw const FormatException('parentId必须为字符串');
          if (parent != n['parentId']) {
            if (parent == id || find(n['children'] as List, parent) != null)
              throw const FormatException('不能移动到自身或子节点');
            final destination = parent == '' ? null : find(roots, parent);
            if (parent != '' && destination == null)
              throw const FormatException('父节点不存在');
            detach(roots, id);
            (destination == null ? roots : destination['children'] as List).add(
              n,
            );
          }
          n.addAll(patch(p));
          n['parentId'] = parent;
          result = n;
        case 'deleteNode':
          if (detach(roots, id) == null) throw const _Missing();
          result = {'id': id};
        default:
          throw const FormatException('未知节点命令');
      }
    }
    await persist(s);
    return PluginResult.success(result);
  }

  final handlers = <String, PluginHandler>{
    'getSnapshot': (_, p) async => PluginResult.success(await state()),
    'getNotebooks': (_, p) async => PluginResult.success(
      createPaginatedResult(
        List<Map<String, dynamic>>.from((await state())['notebooks'] as List),
        offset: p['offset'] as int?,
        count: p['count'] as int?,
      ),
    ),
    'getNotebook': (_, p) async {
      try {
        return PluginResult.success(notebook(await state(), p['id']));
      } on _Missing {
        return const PluginResult.failure('笔记本不存在', 'NOT_FOUND');
      }
    },
  };
  for (final action in [
    'createNotebook',
    'updateNotebook',
    'deleteNotebook',
    'reorderNotebooks',
    'createNode',
    'updateNode',
    'deleteNode',
    'clearNodes',
    'seedExamples',
  ]) {
    handlers[action] = (_, p) async {
      try {
        return await command(action, p);
      } on _Missing {
        return const PluginResult.failure('笔记本或节点不存在', 'NOT_FOUND');
      }
    };
  }
  return handlers;
}

class _Missing implements Exception {
  const _Missing();
}
