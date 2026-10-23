import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('database_sdk_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });
  dynamic ok(Map<String, dynamic> r) {
    expect(r['success'], true, reason: '$r');
    return r['data'];
  }

  Future<void> fixture(String path, dynamic value) async {
    final f = File(root.path + '/' + path);
    await f.parent.create(recursive: true);
    await f.writeAsString(value is String ? value : jsonEncode(value));
  }

  Map<String, dynamic> db(String id, String name) => {
    'id': id,
    'name': name,
    'description': null,
    'coverImage': null,
    'fields': <dynamic>[],
    'createdAt': '2026-10-01T00:00:00.000Z',
    'updatedAt': '2026-10-01T00:00:00.000Z',
  };

  test(
    'legacy top-level records_<id> and databases/databases.json migrate on first write',
    () async {
      // 旧客户端数据：根目录顶层 records_default_db + databases/databases.json
      await fixture('databases/databases.json', [db('default_db', '默认库')]);
      await fixture('records_default_db', [
        {
          'id': 'r1',
          'tableId': 'default_db',
          'fields': {'title': '旧记录'},
          'createdAt': '2026-10-01T00:00:00.000Z',
          'updatedAt': '2026-10-01T00:00:00.000Z',
        },
      ]);

      // 查询只读回退：迁移前旧数据可见
      final before = ok(
        await data.get('database', 'getRecords', {'databaseId': 'default_db'}),
      ) as Map;
      expect(before['total'], 1);
      expect(
        ((ok(await data.get('database', 'getList')) as Map)['data'] as List)
            .length,
        1,
      );
      // 查询不得写入：搬家未发生
      expect(
        await File(root.path + '/database/records_default_db.json').exists(),
        false,
      );

      // 首次写命令触发搬家（读旧→写新→删旧，单事务）
      final created = ok(
        await data.call('database', 'createRecord', {
          'databaseId': 'default_db',
          'fields': {'title': '新记录'},
        }),
      ) as Map;
      expect(created['tableId'], 'default_db');
      final newFile = File(root.path + '/database/records_default_db.json');
      expect(await newFile.exists(), true);
      expect(
        await File(root.path + '/records_default_db').exists(),
        false,
        reason: '旧顶层记录文件必须删除',
      );
      expect(
        ((jsonDecode(await newFile.readAsString()) as List)).length,
        2,
      );

      // 库定义搬家：写命令后旧根目录文件删除、新分区文件生效
      ok(
        await data.call('database', 'create', {
          'id': 'db2',
          'name': '第二个库',
        }),
      );
      expect(
        await File(root.path + '/databases/databases.json').exists(),
        false,
        reason: '旧库定义文件必须删除',
      );
      final migratedDatabases = jsonDecode(
        await File(root.path + '/database/databases/databases.json')
            .readAsString(),
      ) as List;
      expect(migratedDatabases.length, 2);

      // 首写备份保留搬入前的原始库定义
      final backup = jsonDecode(
        await File(root.path + '/database/migration_v1_backup.json')
            .readAsString(),
      ) as Map;
      expect(backup['schemaVersion'], 1);
      expect((backup['databases'] as List).length, 1);
      expect((backup['databases'] as List).first['id'], 'default_db');
    },
  );

  test('database CRUD with cascade record deletion, record CRUD and paging', () async {
    ok(await data.call('database', 'create', {'id': 'a', 'name': 'A'}));
    expect(
      (await data.call('database', 'create', {'id': 'a', 'name': '重复'}))[
          'code'],
      'CONFLICT',
    );
    expect(
      (await data.call('database', 'create', {'id': 'x'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      ok(await data.get('database', 'getById', {'id': 'a'}))['name'],
      'A',
    );
    expect(
      ok(
        await data.call('database', 'update', {
          'id': 'a',
          'name': 'A2',
          'description': '备注',
        }),
      )['description'],
      '备注',
    );
    expect(
      (await data.call('database', 'update', {'id': 'nope', 'name': 'x'}))[
          'code'],
      'NOT_FOUND',
    );
    expect(((ok(await data.get('database', 'getList')) as Map)['total']), 1);

    // 记录 CRUD + 分页
    for (var i = 0; i < 5; i++) {
      ok(
        await data.call('database', 'createRecord', {
          'databaseId': 'a',
          'id': 'r$i',
          'fields': {'title': '记录$i'},
        }),
      );
    }
    expect(
      (await data.call('database', 'createRecord', {
        'databaseId': 'a',
        'id': 'r0',
        'fields': {},
      }))['code'],
      'CONFLICT',
    );
    final page = ok(
      await data.get('database', 'getRecords', {
        'databaseId': 'a',
        'offset': 1,
        'count': 2,
      }),
    ) as Map;
    expect(page['total'], 5);
    expect((page['data'] as List).length, 2);
    expect(page['hasMore'], true);
    expect((page['data'] as List).first['id'], 'r1');
    final filtered = ok(
      await data.get('database', 'getRecords', {
        'databaseId': 'a',
        'keyword': '记录4',
      }),
    ) as Map;
    expect(filtered['total'], 1);

    expect(
      ok(
        await data.call('database', 'updateRecord', {
          'databaseId': 'a',
          'id': 'r1',
          'fields': {'title': '改'},
        }),
      )['fields'],
      {'title': '改'},
    );
    expect(
      (await data.call('database', 'updateRecord', {
        'databaseId': 'a',
        'id': 'nope',
        'fields': {},
      }))['code'],
      'NOT_FOUND',
    );
    ok(
      await data.call('database', 'deleteRecord', {
        'databaseId': 'a',
        'id': 'r2',
      }),
    );
    expect(
      ((ok(
        await data.get('database', 'getRecords', {'databaseId': 'a'}),
      ) as Map)['data'] as List)
          .length,
      4,
    );

    // 级联删除：删库时记录文件一并删除
    ok(await data.call('database', 'delete', {'id': 'a'}));
    expect(
      await File(root.path + '/database/records_a.json').exists(),
      false,
      reason: '删库必须级联删除记录文件',
    );
    expect(((ok(await data.get('database', 'getList')) as Map)['total']), 0);
    expect(
      ((ok(
        await data.get('database', 'getRecords', {'databaseId': 'a'}),
      ) as Map)['data'] as List)
          .isEmpty,
      true,
    );
  });

  test('seedExamples seeds default_db only when empty and stays idempotent', () async {
    final first = ok(await data.call('database', 'seedExamples')) as Map;
    expect(first['insertedDatabases'], 1);
    expect(first['insertedRecords'], 0);
    expect(
      ok(await data.get('database', 'getById', {'id': 'default_db'}))['name'],
      'Default Database',
    );

    // 已有库时不再强建，种子记录仅空文件时种入
    final second = ok(
      await data.call('database', 'seedExamples', {
        'databases': [db('other', '其他库')],
        'records': {
          'default_db': [
            {
              'id': 'seed-r1',
              'fields': {'title': '示例'},
            },
          ],
        },
      }),
    ) as Map;
    expect(second['insertedDatabases'], 0);
    expect(second['insertedRecords'], 1);
    expect(((ok(await data.get('database', 'getList')) as Map)['total']), 1);

    final third = ok(
      await data.call('database', 'seedExamples', {
        'records': {
          'default_db': [
            {'id': 'seed-r2', 'fields': {}},
          ],
        },
      }),
    ) as Map;
    expect(third['insertedDatabases'], 0);
    expect(third['insertedRecords'], 0);
    expect(
      ((ok(
        await data.get('database', 'getRecords', {'databaseId': 'default_db'}),
      ) as Map)['data'] as List)
          .length,
      1,
    );
  });

  test('exportData/importData round-trip merges by id', () async {
    ok(await data.call('database', 'create', {'id': 'a', 'name': 'A'}));
    ok(
      await data.call('database', 'createRecord', {
        'databaseId': 'a',
        'id': 'r1',
        'fields': {'title': 't'},
      }),
    );
    final exported = ok(await data.get('database', 'exportData')) as Map;
    expect((exported['databases'] as List).length, 1);
    expect((exported['records'] as Map)['a'], isA<List>());

    final imported = ok(
      await data.call('database', 'importData', {
        'databases': [
          db('a', 'A-改名'),
          db('b', 'B'),
        ],
        'records': {
          'b': [
            {'id': 'rb1', 'fields': {'title': 'x'}},
          ],
        },
      }),
    ) as Map;
    expect(imported['importedDatabases'], 2);
    expect(imported['importedRecords'], 1);
    expect(ok(await data.get('database', 'getById', {'id': 'a'}))['name'], 'A-改名');
    expect(
      ((ok(
        await data.get('database', 'getRecords', {'databaseId': 'b'}),
      ) as Map)['total']),
      1,
    );
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await fixture('database/databases/databases.json', {'databases': 'broken'});
    expect(
      (await data.get('database', 'getList'))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('database', 'create', {'id': 'x', 'name': 't'}))[
          'code'],
      'CORRUPT_DATA',
    );

    await fixture('database/records_a.json', {'x': 1});
    expect(
      (await data.get('database', 'getRecords', {'databaseId': 'a'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('database', 'createRecord', {
        'databaseId': 'a',
        'fields': {},
      }))['code'],
      'CORRUPT_DATA',
    );

    // 旧顶层记录文件损坏同样明确报错（不得伪装为空）
    await fixture('records_b', 'not-json{{{');
    expect(
      (await data.get('database', 'getRecords', {'databaseId': 'b'}))['code'],
      'CORRUPT_DATA',
    );

    // 损坏时原文件保持原样
    expect(
      jsonDecode(
        await File(root.path + '/database/records_a.json').readAsString(),
      ),
      {'x': 1},
    );
    expect(
      await File(root.path + '/database/migration_v1_backup.json').exists(),
      false,
    );
  });
}
