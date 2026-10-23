import '../plugin_data.dart';
import '../types.dart';
import '../utils.dart';
import 'structured_support.dart';

PluginHandlers createContactHandlers(PluginData data) {
  Future<List<Map<String, dynamic>>> contacts() async => entityList(
    await data.read('contact', 'contacts.json'),
    key: 'contacts',
  ).map(_contact).toList();
  Future<List<Map<String, dynamic>>> interactions() async => entityList(
    await data.read('contact', 'interactions.json'),
    key: 'records',
  ).map(_interaction).toList();
  Future<void> saveContacts(List<Map<String, dynamic>> rows) =>
      writeEntityList(data, 'contact', 'contacts.json', rows, key: 'contacts');
  Future<void> saveInteractions(List<Map<String, dynamic>> rows) async {
    await ensureDomainBackup(data, 'contact');
    await writeEntityList(
      data,
      'contact',
      'interactions.json',
      rows,
      key: 'records',
    );
  }

  Future<Map<String, dynamic>> preferences() async => {
    'filter': entityObject(await data.read('contact', 'filter_config')),
    'sort': {
      'type': 0,
      'isReverse': false,
      ...entityObject(await data.read('contact', 'sort_config')),
    },
  };
  Future<Map<String, dynamic>> snapshot() async => {
    'contacts': await contacts(),
    'interactions': await interactions(),
    'preferences': await preferences(),
  };
  Future<void> updateLastContact(
    List<Map<String, dynamic>> cs,
    List<Map<String, dynamic>> records,
    String id,
  ) async {
    final i = cs.indexWhere((r) => r['id'] == id);
    if (i < 0) return;
    final dates =
        records
            .where((r) => r['contactId'] == id)
            .map((r) => validDate(r['date'], 'date'))
            .toList()
          ..sort();
    cs[i]['lastContactTime'] = dates.isEmpty
        ? cs[i]['createdTime']
        : dates.last.toIso8601String();
  }

  Future<PluginResult> list(Map<String, dynamic> p) async {
    var rows = await contacts();
    final records = await interactions();
    final prefs = await preferences();
    final filter = entityObject(
      p['filter'] ?? (p['filtered'] == true ? prefs['filter'] : null),
    );
    final sort = entityObject(p['sort'] ?? prefs['sort']);
    rows = rows.where((r) {
      final keyword = (p['keyword'] ?? filter['nameKeyword'] ?? '')
          .toString()
          .toLowerCase();
      if (keyword.isNotEmpty &&
          !'${r['name']} ${r['phone']} ${r['email'] ?? ''}'
              .toLowerCase()
              .contains(keyword))
        return false;
      if (filter['startDate'] != null &&
          validDate(
            r['createdTime'],
            'createdTime',
          ).isBefore(validDate(filter['startDate'], 'startDate')))
        return false;
      if (filter['endDate'] != null &&
          !validDate(r['createdTime'], 'createdTime').isBefore(
            validDate(
              filter['endDate'],
              'endDate',
            ).add(const Duration(days: 1)),
          ))
        return false;
      if (filter['uncontactedDays'] != null &&
          DateTime.now()
                  .difference(
                    validDate(r['lastContactTime'], 'lastContactTime'),
                  )
                  .inDays <
              (filter['uncontactedDays'] as int))
        return false;
      final tags = filter['selectedTags'] as List? ?? [];
      return tags.isEmpty || tags.any((t) => (r['tags'] as List).contains(t));
    }).toList();
    final counts = <String, int>{};
    for (final r in records) {
      final id = r['contactId'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    rows.sort((a, b) {
      final field = switch (sort['type']) {
        1 => 'createdTime',
        2 => 'lastContactTime',
        _ => 'name',
      };
      var n = sort['type'] == 3
          ? (counts[a['id']] ?? 0).compareTo(counts[b['id']] ?? 0)
          : a[field].toString().compareTo(b[field].toString());
      if (sort['isReverse'] == true) n = -n;
      return n == 0 ? (a['id'] as String).compareTo(b['id'] as String) : n;
    });
    return PluginResult.success(pageEntities(rows, p));
  }

  Future<PluginResult> put(Map<String, dynamic> p, bool create) async {
    final rows = await contacts();
    final id = p['id'] ?? generateUUID();
    final i = rows.indexWhere((r) => r['id'] == id);
    if (create && i >= 0)
      return const PluginResult.failure('联系人已存在', 'CONFLICT');
    if (!create && i < 0)
      return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
    final next = _contact({
      ...?(i < 0 ? null : rows[i]),
      ...changedFields(p),
      'id': id,
    });
    if (i < 0)
      rows.add(next);
    else
      rows[i] = next;
    await saveContacts(rows);
    return PluginResult.success(next);
  }

  Future<PluginResult> interactionPut(
    Map<String, dynamic> p,
    bool create,
  ) async {
    final cs = await contacts();
    final rows = await interactions();
    final id = p['id'] ?? generateUUID();
    final i = rows.indexWhere((r) => r['id'] == id);
    if (create && i >= 0)
      return const PluginResult.failure('交互记录已存在', 'CONFLICT');
    if (!create && i < 0)
      return const PluginResult.failure('交互记录不存在', 'NOT_FOUND');
    final old = i < 0 ? null : rows[i];
    final next = _interaction({...?old, ...changedFields(p), 'id': id});
    if (!cs.any((c) => c['id'] == next['contactId']))
      return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
    if ((next['participants'] as List).any(
      (id) => !cs.any((c) => c['id'] == id),
    ))
      throw const FormatException('参与联系人不存在');
    if (i < 0)
      rows.add(next);
    else
      rows[i] = next;
    await saveInteractions(rows);
    if (old != null)
      await updateLastContact(cs, rows, old['contactId'] as String);
    await updateLastContact(cs, rows, next['contactId'] as String);
    await saveContacts(cs);
    return PluginResult.success(next);
  }

  Future<PluginResult> interactionDelete(
    Map<String, dynamic> p, {
    bool byContact = false,
  }) async {
    final cs = await contacts();
    final rows = await interactions();
    final affected = <String>{};
    rows.removeWhere((r) {
      final remove = byContact
          ? r['contactId'] == p['contactId']
          : r['id'] == p['id'];
      if (remove) affected.add(r['contactId'] as String);
      return remove;
    });
    if (!byContact && affected.isEmpty)
      return const PluginResult.failure('交互记录不存在', 'NOT_FOUND');
    await saveInteractions(rows);
    for (final id in affected) {
      await updateLastContact(cs, rows, id);
    }
    await saveContacts(cs);
    return PluginResult.success({'deleted': affected.length});
  }

  return {
    'restoreBackup': (_, p) async {
      if (p['confirmRestore'] != true) {
        throw const FormatException('confirmRestore required');
      }
      return PluginResult.success(await restoreDomainBackup(data, 'contact'));
    },
    'getList': (_, p) => list(p),
    'search': (_, p) => list(p),
    'getSnapshot': (_, p) async => PluginResult.success(await snapshot()),
    'getById': (_, p) async {
      for (final r in await contacts()) {
        if (r['id'] == p['id']) return PluginResult.success(r);
      }
      return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
    },
    'create': (_, p) => put(p, true),
    'update': (_, p) => put(p, false),
    'delete': (_, p) async {
      final cs = await contacts();
      final n = cs.length;
      cs.removeWhere((r) => r['id'] == p['id']);
      if (n == cs.length)
        return const PluginResult.failure('联系人不存在', 'NOT_FOUND');
      final rows = await interactions();
      rows.removeWhere((r) => r['contactId'] == p['id']);
      for (final r in rows) {
        (r['participants'] as List).remove(p['id']);
      }
      await saveContacts(cs);
      await saveInteractions(rows);
      return PluginResult.success({'id': p['id']});
    },
    'getInteractions': (_, p) async {
      var rows = await interactions();
      if (p['contactId'] != null)
        rows = rows.where((r) => r['contactId'] == p['contactId']).toList();
      rows.sort((a, b) {
        final n = (b['date'] as String).compareTo(a['date'] as String);
        return n == 0 ? (a['id'] as String).compareTo(b['id'] as String) : n;
      });
      return PluginResult.success(pageEntities(rows, p));
    },
    'addInteraction': (_, p) => interactionPut(p, true),
    'updateInteraction': (_, p) => interactionPut(p, false),
    'deleteInteraction': (_, p) => interactionDelete(p),
    'deleteContactInteractions': (_, p) =>
        interactionDelete(p, byContact: true),
    'getPreferences': (_, p) async => PluginResult.success(await preferences()),
    'updatePreferences': (_, p) async {
      await ensureDomainBackup(data, 'contact');
      final old = await preferences();
      for (final key in ['filter', 'sort']) {
        if (p.containsKey(key)) {
          final patch = entityObject(p[key]);
          final next = {...entityObject(old[key]), ...patch};
          if (key == 'sort' &&
              (next['type'] is! int ||
                  (next['type'] as int) < 0 ||
                  (next['type'] as int) > 3 ||
                  next['isReverse'] is! bool))
            throw const FormatException('无效联系人排序');
          await data.write(
            'contact',
            key == 'filter' ? 'filter_config' : 'sort_config',
            next,
          );
          old[key] = next;
        }
      }
      return PluginResult.success(old);
    },
    'getStats': (_, p) async => PluginResult.success({
      'totalContacts': (await contacts()).length,
      'totalInteractions': (await interactions()).length,
    }),
    'exportData': (_, p) async =>
        PluginResult.success({'schemaVersion': 1, ...await snapshot()}),
    'importData': (_, p) async {
      final cs = entityList(p['contacts']).map(_contact).toList();
      final rs = entityList(p['interactions']).map(_interaction).toList();
      await ensureDomainBackup(data, 'contact');
      final current = await contacts();
      final records = await interactions();
      var inserted = 0;
      for (final row in cs) {
        if (!current.any((r) => r['id'] == row['id'])) {
          current.add(row);
          inserted++;
        }
      }
      for (final row in rs) {
        if (!current.any((r) => r['id'] == row['contactId']))
          throw const FormatException('交互记录引用不存在的联系人');
        if (!records.any((r) => r['id'] == row['id'])) records.add(row);
      }
      for (final c in current) {
        await updateLastContact(current, records, c['id'] as String);
      }
      await saveContacts(current);
      await saveInteractions(records);
      return PluginResult.success({'inserted': inserted});
    },
    'seedExamples': (_, p) async {
      if (p['templateVersion'] != null && p['templateVersion'] != 1)
        return const PluginResult.failure('未知示例版本', 'UNSUPPORTED');
      if (await data.read('contact', 'sdk_examples_v1.json') != null)
        return PluginResult.success({'inserted': 0, 'templateVersion': 1});
      final cs = await contacts();
      var inserted = 0;
      for (final row in [
        {
          'id': 'seed_contact_v1_friend',
          'name': '示例朋友',
          'phone': '13800000000',
          'tags': ['朋友'],
        },
        {
          'id': 'seed_contact_v1_colleague',
          'name': '示例同事',
          'phone': '13900000000',
          'tags': ['同事'],
        },
      ]) {
        if (!cs.any((r) => r['id'] == row['id'])) {
          cs.add(_contact(row));
          inserted++;
        }
      }
      await saveContacts(cs);
      await data.write('contact', 'sdk_examples_v1.json', {
        'templateVersion': 1,
      });
      return PluginResult.success({'inserted': inserted, 'templateVersion': 1});
    },
  };
}

Map<String, dynamic> _contact(Map<String, dynamic> raw) {
  final now = DateTime.now().toIso8601String();
  final row = <String, dynamic>{
    'phone': '',
    'icon': 0xe7fd,
    'iconColor': 0xff2196f3,
    'tags': <String>[],
    'customFields': <String, String>{},
    'customActivityEvents': [],
    'createdTime': raw['createdAt'] ?? now,
    'lastContactTime': raw['createdTime'] ?? raw['createdAt'] ?? now,
    'isFavorite': false,
    ...raw,
  };
  requiredText(row, 'id');
  requiredText(row, 'name');
  validDate(row['createdTime'], 'createdTime');
  validDate(row['lastContactTime'], 'lastContactTime');
  if (row['phone'] is! String ||
      row['icon'] is! int ||
      row['iconColor'] is! int ||
      row['isFavorite'] is! bool ||
      row['tags'] is! List ||
      (row['tags'] as List).any((v) => v is! String) ||
      row['customFields'] is! Map ||
      (row['customFields'] as Map).values.any((v) => v is! String) ||
      row['customActivityEvents'] is! List)
    throw const FormatException('联系人字段类型无效');
  return row;
}

Map<String, dynamic> _interaction(Map<String, dynamic> raw) {
  final row = <String, dynamic>{
    'notes': '',
    'participants': <String>[],
    ...raw,
  };
  requiredText(row, 'id');
  requiredText(row, 'contactId');
  validDate(row['date'], 'date');
  if (row['notes'] is! String ||
      row['participants'] is! List ||
      (row['participants'] as List).any((v) => v is! String))
    throw const FormatException('交互记录字段无效');
  return row;
}
