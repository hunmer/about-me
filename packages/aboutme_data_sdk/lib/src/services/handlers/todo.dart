import '../migrations/record_domains_migration.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'record_domain_support.dart';

PluginHandlers createTodoHandlers(PluginData data) {
  Future<Map<String, dynamic>> read() =>
      readDomainFile(data, 'todo', 'tasks.json', ['tasks', 'completedTasks']);
  Future<void> save(Map<String, dynamic> file) =>
      data.write('todo', 'tasks.json', file);
  bool done(Map task) =>
      task['status'] == 2 ||
      task['completed'] == true ||
      task['isCompleted'] == true;
  void setStatus(Map<String, dynamic> task, int status) {
    if (status < 0 || status > 2) throw ArgumentError('Invalid status');
    final now = DateTime.now();
    final previous = task['status'];
    final start = DateTime.tryParse('${task['startTime']}');
    if (previous == 1 && status != 1 && start != null) {
      task['duration'] =
          domainNumber(task['duration']) +
          now.difference(start).inMilliseconds.clamp(0, 1 << 53);
      task['startTime'] = null;
    }
    if (status == 1 && previous != 1) task['startTime'] = now.toIso8601String();
    task['status'] = status;
    task['completed'] = task['isCompleted'] = status == 2;
    task['completedAt'] = task['completedDate'] = status == 2
        ? now.toIso8601String()
        : null;
    task['updatedAt'] = now.toIso8601String();
    if (status == 2) {
      for (final subtask in (task['subtasks'] as List? ?? [])) {
        subtask['isCompleted'] = true;
      }
    }
  }

  Future<dynamic> mutate(
    Map<String, dynamic> p,
    void Function(Map<String, dynamic>, List<Map<String, dynamic>>, int) change,
  ) async {
    final file = await read();
    final rows = domainRows(file, 'tasks');
    final i = domainIndex(rows, p['id']);
    change(file, rows, i);
    await save(file);
    return i < rows.length ? rows[i] : {'id': p['id']};
  }

  Future<dynamic> list(Map<String, dynamic> p, {String? mode}) async {
    final file = await read();
    final today = formatDate(DateTime.now());
    var rows = domainRows(file, 'tasks').where((task) {
      final due = '${task['dueDate'] ?? ''}';
      final start = '${task['startDate'] ?? ''}';
      final completed = p['completed'] ?? p['isCompleted'];
      if (completed != null &&
          done(task) != (completed == true || completed == 'true'))
        return false;
      if (p['priority'] != null &&
          task['priority'].toString() != p['priority'].toString())
        return false;
      if (p['category'] != null && task['category'] != p['category'])
        return false;
      final keyword = '${p['keyword'] ?? ''}'.toLowerCase();
      if (keyword.isNotEmpty &&
          !'${task['title']} ${task['description']} ${task['tags']}'
              .toLowerCase()
              .contains(keyword))
        return false;
      if (p['tags'] is List &&
          !(p['tags'] as List).every(
            (tag) => (task['tags'] as List? ?? []).contains(tag),
          ))
        return false;
      if (p['dueBefore'] != null &&
          (due.isEmpty || due.compareTo('${p['dueBefore']}') > 0))
        return false;
      if (p['dueAfter'] != null &&
          (due.isEmpty || due.compareTo('${p['dueAfter']}') < 0))
        return false;
      if (p['field'] != null && p['value'] != null) {
        final actual = '${task[p['field']] ?? ''}';
        final wanted = '${p['value']}';
        if (p['fuzzy'] == true
            ? !actual.toLowerCase().contains(wanted.toLowerCase())
            : actual != wanted)
          return false;
      }
      if (mode == 'overdue')
        return !done(task) &&
            due.isNotEmpty &&
            due.substring(0, 10).compareTo(today) < 0;
      if (mode == 'today')
        return (start.isNotEmpty || due.isNotEmpty) &&
            (start.isEmpty || start.substring(0, 10).compareTo(today) <= 0) &&
            (due.isEmpty || due.substring(0, 10).compareTo(today) >= 0);
      return true;
    }).toList();
    rows.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    if (p['findAll'] == false && rows.length > 1) rows = rows.take(1).toList();
    return createPaginatedResult(
      rows,
      offset: p['offset'] as int?,
      count: p['count'] as int? ?? rows.length,
    );
  }

  return withRecordDomainMigration(data, 'todo', {
    'getSnapshot': domainAction((_) => read()),
    'getList': domainAction((p) => list(p)),
    'search': domainAction((p) => list(p)),
    'getTodayTasks': domainAction((p) => list(p, mode: 'today')),
    'getOverdueTasks': domainAction((p) => list(p, mode: 'overdue')),
    'getById': domainAction((p) async {
      final rows = domainRows(await read(), 'tasks');
      return rows[domainIndex(rows, p['id'])];
    }),
    'create': domainAction((p) async {
      if ('${p['title'] ?? ''}'.trim().isEmpty)
        throw ArgumentError('Title required');
      final file = await read();
      final rows = domainRows(file, 'tasks');
      final id = p['id'] ?? generateUUID();
      if (rows.any((e) => e['id'] == id))
        throw const DomainFailure('CONFLICT', 'Task already exists');
      final task = <String, dynamic>{
        'createdAt': DateTime.now().toIso8601String(),
        'status': 0,
        'priority': 1,
        'tags': [],
        'subtasks': [],
        'reminders': [],
        ...domainPatch(p),
        'id': id,
      };
      if (task['isCompleted'] == true || task['completed'] == true)
        setStatus(task, 2);
      rows.add(task);
      await save(file);
      return task;
    }),
    'update': domainAction(
      (p) => mutate(p, (file, rows, i) {
        final patch = domainPatch(p)..remove('createdAt');
        final oldStatus = rows[i]['status'];
        rows[i] = {...rows[i], ...patch};
        if (patch.containsKey('status') && patch['status'] != oldStatus) {
          rows[i]['status'] = oldStatus;
          setStatus(rows[i], patch['status'] as int);
        } else if (patch.containsKey('isCompleted') ||
            patch.containsKey('completed'))
          setStatus(
            rows[i],
            (patch['isCompleted'] ?? patch['completed']) == true ? 2 : 0,
          );
        rows[i]['updatedAt'] = DateTime.now().toIso8601String();
      }),
    ),
    'setStatus': domainAction(
      (p) => mutate(p, (_, rows, i) => setStatus(rows[i], p['status'] as int)),
    ),
    'completeTask': domainAction(
      (p) => mutate(p, (_, rows, i) => setStatus(rows[i], 2)),
    ),
    'delete': domainAction((p) async {
      final file = await read();
      final rows = domainRows(file, 'tasks');
      final task = rows.removeAt(domainIndex(rows, p['id']));
      if (done(task)) {
        domainRows(file, 'completedTasks').add({
          ...task,
          'completedDate':
              task['completedDate'] ?? DateTime.now().toIso8601String(),
        });
      }
      await save(file);
      return {'id': p['id']};
    }),
    'addSubtask': domainAction(
      (p) => mutate(p, (_, rows, i) {
        if ('${p['title'] ?? ''}'.trim().isEmpty)
          throw ArgumentError('Title required');
        final subs = List<dynamic>.from(rows[i]['subtasks'] as List? ?? []);
        subs.add({
          'id': p['subtaskId'] ?? generateUUID(),
          'title': p['title'],
          'isCompleted': false,
        });
        rows[i]['subtasks'] = subs;
      }),
    ),
    'setSubtaskStatus': domainAction(
      (p) => mutate(p, (_, rows, i) {
        final subs = List<Map<String, dynamic>>.from(
          rows[i]['subtasks'] as List? ?? [],
        );
        final si = domainIndex(subs, p['subtaskId']);
        subs[si]['isCompleted'] = p['isCompleted'] == true;
        rows[i]['subtasks'] = subs;
        final all =
            subs.isNotEmpty && subs.every((e) => e['isCompleted'] == true);
        if (all)
          setStatus(rows[i], 2);
        else if (done(rows[i]))
          setStatus(rows[i], 1);
      }),
    ),
    'changeTag': domainAction(
      (p) => mutate(p, (_, rows, i) {
        final tags = List<dynamic>.from(rows[i]['tags'] as List? ?? []);
        final tag = p['tag'];
        if (tag is! String || tag.isEmpty) throw ArgumentError('Tag required');
        if (p['remove'] == true) {
          tags.remove(tag);
        } else if (!tags.contains(tag)) {
          tags.add(tag);
        }
        rows[i]['tags'] = tags;
      }),
    ),
    'updateSettings': domainAction((p) async {
      final file = await read();
      if (p.containsKey('viewMode')) file['viewMode'] = p['viewMode'];
      await save(file);
      return {'viewMode': file['viewMode']};
    }),
    'removeHistory': domainAction((p) async {
      final file = await read();
      domainRows(file, 'completedTasks').removeWhere((e) => e['id'] == p['id']);
      await save(file);
      return {'id': p['id']};
    }),
    'clearHistory': domainAction((p) async {
      final file = await read();
      file['completedTasks'] = <dynamic>[];
      await save(file);
      return {'cleared': true};
    }),
    'seedExamples': domainAction((p) async {
      final file = await read();
      if (file['exampleTemplateVersion'] != null ||
          domainRows(file, 'tasks').isNotEmpty ||
          domainRows(file, 'completedTasks').isNotEmpty)
        return {'inserted': 0};
      file['tasks'] = [
        {
          'id': 'seed:todo:welcome:v1',
          'title': '创建你的第一个任务',
          'status': 0,
          'priority': 1,
          'createdAt': DateTime.now().toIso8601String(),
          'tags': [],
          'subtasks': [],
          'reminders': [],
        },
      ];
      file['exampleTemplateVersion'] = 1;
      await save(file);
      return {'inserted': 1};
    }),
    'getStats': domainAction((p) async {
      final rows = domainRows(await read(), 'tasks');
      final completed = rows.where(done).length;
      final overdue = await list({}, mode: 'overdue') as Map;
      final today = await list({}, mode: 'today') as Map;
      return {
        'total': rows.length,
        'completed': completed,
        'pending': rows.length - completed,
        'overdue': overdue['total'],
        'dueToday': today['total'],
        'completionRate': rows.isEmpty
            ? 0
            : (completed * 100 / rows.length).round(),
      };
    }),
  });
}
