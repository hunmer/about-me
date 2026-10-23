import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

/// contact / day / calendar 三域 SDK 契约测试：
/// CRUD 往返、域特色命令、restoreBackup、原始写封闭（426）、损坏数据报错。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('cdc_contract_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  dynamic value(Map<String, dynamic> result) {
    expect(result['success'], isTrue, reason: '$result');
    return result['data'];
  }

  Map<String, dynamic> failure(Map<String, dynamic> result, String code) {
    expect(result['success'], isFalse, reason: '$result');
    expect(result['code'], code, reason: '$result');
    return result;
  }

  // 三域已封闭原始写，损坏数据用磁盘直写注入（参照 checkin_migration_test）。
  Future<void> inject(String domain, String file, dynamic content) async {
    final target = File('${root.path}/$domain/$file');
    await target.parent.create(recursive: true);
    await target.writeAsString(jsonEncode(content));
  }

  group('contact', () {
    test('联系人 CRUD 往返与字段保留', () async {
      final created =
          value(
            await data.call('contact', 'create', {
              'id': 'c1',
              'name': '张三',
              'phone': '13800000000',
              'tags': ['朋友', '同事'],
              'customFields': {'备注': '大学同学'},
              'isFavorite': true,
            }),
          )
          as Map;
      expect(created['name'], '张三');
      expect(created['tags'], ['朋友', '同事']);
      expect(created['customFields'], {'备注': '大学同学'});
      expect(created['isFavorite'], isTrue);
      expect(DateTime.tryParse(created['createdTime'] as String), isNotNull);

      final got =
          value(await data.call('contact', 'getById', {'id': 'c1'})) as Map;
      expect(got['phone'], '13800000000');

      final updated =
          value(
            await data.call('contact', 'update', {
              'id': 'c1',
              'phone': '13900000000',
            }),
          )
          as Map;
      expect(updated['phone'], '13900000000');
      // 未提交字段在 patch 后保留
      final after =
          value(await data.call('contact', 'getById', {'id': 'c1'})) as Map;
      expect(after['name'], '张三');
      expect(after['customFields'], {'备注': '大学同学'});
      expect(after['isFavorite'], isTrue);

      failure(
        await data.call('contact', 'create', {'id': 'c1', 'name': '重复'}),
        'CONFLICT',
      );
      failure(
        await data.call('contact', 'update', {'id': 'missing', 'name': 'x'}),
        'NOT_FOUND',
      );

      await value(
        await data.call('contact', 'create', {'id': 'c2', 'name': '李四'}),
      );
      final list = value(await data.call('contact', 'getList')) as Map;
      expect(list['total'], 2);
      expect(
        (list['data'] as List).map((r) => (r as Map)['id']),
        containsAll(['c1', 'c2']),
      );

      await value(await data.call('contact', 'delete', {'id': 'c1'}));
      failure(
        await data.call('contact', 'getById', {'id': 'c1'}),
        'NOT_FOUND',
      );
      failure(await data.call('contact', 'delete', {'id': 'c1'}), 'NOT_FOUND');
      expect(
        (value(await data.call('contact', 'getList')) as Map)['total'],
        1,
      );
    });

    test('interactions 增删改、联系人级联清理与 preferences', () async {
      await value(
        await data.call('contact', 'create', {'id': 'c1', 'name': '张三'}),
      );
      await value(
        await data.call('contact', 'create', {'id': 'c2', 'name': '李四'}),
      );

      final r1 =
          value(
            await data.call('contact', 'addInteraction', {
              'id': 'r1',
              'contactId': 'c1',
              'date': '2030-01-05T10:00:00.000',
              'notes': '电话',
              'participants': ['c1', 'c2'],
            }),
          )
          as Map;
      expect(r1['notes'], '电话');
      expect(r1['participants'], ['c1', 'c2']);
      // 交互推进联系人 lastContactTime
      final c1row =
          value(await data.call('contact', 'getById', {'id': 'c1'})) as Map;
      expect(c1row['lastContactTime'], '2030-01-05T10:00:00.000');

      final updated =
          value(
            await data.call('contact', 'updateInteraction', {
              'id': 'r1',
              'notes': '视频',
            }),
          )
          as Map;
      expect(updated['notes'], '视频');
      expect(updated['date'], '2030-01-05T10:00:00.000');

      // 引用不存在的联系人 / 参与者
      failure(
        await data.call('contact', 'addInteraction', {
          'id': 'rx',
          'contactId': 'missing',
          'date': '2030-01-01T00:00:00.000',
        }),
        'NOT_FOUND',
      );
      failure(
        await data.call('contact', 'addInteraction', {
          'id': 'rx',
          'contactId': 'c1',
          'date': '2030-01-01T00:00:00.000',
          'participants': ['missing'],
        }),
        'INVALID_PARAMS',
      );

      await value(
        await data.call('contact', 'addInteraction', {
          'id': 'r2',
          'contactId': 'c2',
          'date': '2030-02-01T09:00:00.000',
          'participants': ['c1', 'c2'],
        }),
      );

      // 删除联系人级联：删其交互记录 + 清理其它记录的参与者引用
      await value(await data.call('contact', 'delete', {'id': 'c1'}));
      final left =
          value(
            await data.call('contact', 'getInteractions', {'contactId': 'c2'}),
          )
          as Map;
      final rows = (left['data'] as List).cast<Map>();
      expect(rows, hasLength(1));
      expect(rows.first['id'], 'r2');
      expect(rows.first['participants'], ['c2']);

      final del =
          value(
            await data.call('contact', 'deleteInteraction', {'id': 'r2'}),
          )
          as Map;
      expect(del['deleted'], 1);
      failure(
        await data.call('contact', 'deleteInteraction', {'id': 'r2'}),
        'NOT_FOUND',
      );
      // 按联系人清空：无记录时同样成功
      final cleared =
          value(
            await data.call('contact', 'deleteContactInteractions', {
              'contactId': 'c2',
            }),
          )
          as Map;
      expect(cleared['deleted'], 0);

      final prefs =
          value(await data.call('contact', 'getPreferences')) as Map;
      expect(prefs['filter'], {});
      expect(prefs['sort'], {'type': 0, 'isReverse': false});
      final nextPrefs =
          value(
            await data.call('contact', 'updatePreferences', {
              'filter': {'nameKeyword': '张'},
              'sort': {'type': 3, 'isReverse': true},
            }),
          )
          as Map;
      expect((nextPrefs['sort'] as Map)['type'], 3);
      expect((nextPrefs['filter'] as Map)['nameKeyword'], '张');
      final again =
          value(await data.call('contact', 'getPreferences')) as Map;
      expect((again['sort'] as Map)['isReverse'], true);
      failure(
        await data.call('contact', 'updatePreferences', {
          'sort': {'type': 9},
        }),
        'INVALID_PARAMS',
      );
    });

    test('restoreBackup 恢复迁移备份建立时的状态', () async {
      await value(
        await data.call('contact', 'create', {'id': 'c1', 'name': '原始'}),
      );
      // 首次 interactions/preferences 写入前建立迁移备份（contacts=[c1 原始]）
      await value(
        await data.call('contact', 'addInteraction', {
          'id': 'r1',
          'contactId': 'c1',
          'date': '2030-01-01T00:00:00.000',
        }),
      );
      await value(
        await data.call('contact', 'update', {'id': 'c1', 'name': '改名'}),
      );
      await value(
        await data.call('contact', 'create', {'id': 'c2', 'name': '新增'}),
      );

      final restored =
          value(
            await data.call('contact', 'restoreBackup', {
              'confirmRestore': true,
            }),
          )
          as Map;
      expect(restored['restored'], isTrue);
      expect(restored['schemaVersion'], 1);

      final list = value(await data.call('contact', 'getList')) as Map;
      final rows = (list['data'] as List).cast<Map>();
      expect(rows, hasLength(1));
      expect(rows.first['name'], '原始');
      expect(
        (value(await data.call('contact', 'getInteractions')) as Map)['total'],
        0,
      );
      final prefs =
          value(await data.call('contact', 'getPreferences')) as Map;
      expect((prefs['sort'] as Map)['type'], 0);
    });

    test('损坏数据返回 CORRUPT_DATA', () async {
      await inject('contact', 'contacts.json', {
        'contacts': [
          {'name': '缺ID'},
        ],
      });
      failure(await data.call('contact', 'getList'), 'CORRUPT_DATA');
      await inject('contact', 'interactions.json', {
        'records': [
          {'id': 'a', 'contactId': 'x', 'date': '2030-01-01T00:00:00.000'},
          {'id': 'a', 'contactId': 'x', 'date': '2030-01-01T00:00:00.000'},
        ],
      });
      failure(await data.call('contact', 'getInteractions'), 'CORRUPT_DATA');
    });
  });

  group('day', () {
    test('纪念日 CRUD 往返与字段保留', () async {
      final created =
          value(
            await data.call('day', 'create', {
              'id': 'd1',
              'title': '生日',
              'targetDate': '2030-05-01T00:00:00.000',
              'notes': ['蛋糕'],
              'noteDates': ['2030-04-01T08:00:00.000'],
              'backgroundColor': 0xffef9a9a,
              'recurrenceUnit': 'years',
              'recurrenceInterval': 1,
            }),
          )
          as Map;
      expect(created['notes'], ['蛋糕']);
      expect(created['noteDates'], ['2030-04-01T08:00:00.000']);
      expect(created['backgroundColor'], 0xffef9a9a);
      expect(DateTime.tryParse(created['creationDate'] as String), isNotNull);

      final got = value(await data.call('day', 'getById', {'id': 'd1'})) as Map;
      expect(got['targetDate'], '2030-05-01T00:00:00.000');

      final updated =
          value(
            await data.call('day', 'update', {'id': 'd1', 'title': '生日(改)'}),
          )
          as Map;
      expect(updated['title'], '生日(改)');
      final after =
          value(await data.call('day', 'getById', {'id': 'd1'})) as Map;
      expect(after['notes'], ['蛋糕']);
      expect(after['targetDate'], '2030-05-01T00:00:00.000');

      failure(
        await data.call('day', 'create', {
          'id': 'd1',
          'title': 'x',
          'targetDate': '2030-05-01T00:00:00.000',
        }),
        'CONFLICT',
      );
      failure(
        await data.call('day', 'update', {'id': 'missing', 'title': 'x'}),
        'NOT_FOUND',
      );

      await value(
        await data.call('day', 'create', {
          'id': 'd2',
          'title': '旅行',
          'targetDate': '2030-07-01T00:00:00.000',
        }),
      );
      final searched =
          value(await data.call('day', 'search', {'keyword': '生日'})) as Map;
      expect(searched['total'], 1);
      expect(
        ((searched['data'] as List).first as Map)['title'],
        '生日(改)',
      );

      await value(await data.call('day', 'delete', {'id': 'd2'}));
      failure(await data.call('day', 'getById', {'id': 'd2'}), 'NOT_FOUND');
      expect((value(await data.call('day', 'getList')) as Map)['total'], 1);
    });

    test('reorder 重排 sortIndex 与 preferences 校验', () async {
      for (final row in [
        {'id': 'd1', 'title': '一', 'targetDate': '2030-01-01T00:00:00.000'},
        {'id': 'd2', 'title': '二', 'targetDate': '2030-02-01T00:00:00.000'},
        {'id': 'd3', 'title': '三', 'targetDate': '2030-03-01T00:00:00.000'},
      ]) {
        await value(await data.call('day', 'create', row));
      }

      // ids 允许为子集，未列出的排在已列出的之后
      final reordered =
          value(
            await data.call('day', 'reorder', {'ids': ['d3', 'd1']}),
          )
          as Map;
      expect((reordered['data'] as List), hasLength(3));
      final manual =
          value(
            await data.call('day', 'getList', {'sortMode': 'manual'}),
          )
          as Map;
      expect(
        (manual['data'] as List).map((r) => (r as Map)['id']).toList(),
        ['d3', 'd1', 'd2'],
      );

      failure(
        await data.call('day', 'reorder', {'ids': ['missing']}),
        'INVALID_PARAMS',
      );
      failure(
        await data.call('day', 'reorder', {'ids': ['d1', 'd1']}),
        'INVALID_PARAMS',
      );
      failure(await data.call('day', 'reorder', {'ids': 'd1'}), 'INVALID_PARAMS');

      final prefs = value(await data.call('day', 'getPreferences')) as Map;
      expect(prefs['isCardView'], isTrue);
      expect(prefs['sortMode'], 'upcoming');
      final next =
          value(
            await data.call('day', 'updatePreferences', {
              'isCardView': false,
              'sortMode': 'manual',
            }),
          )
          as Map;
      expect(next['isCardView'], isFalse);
      final again = value(await data.call('day', 'getPreferences')) as Map;
      expect(again['sortMode'], 'manual');
      failure(
        await data.call('day', 'updatePreferences', {'sortMode': 'bad'}),
        'INVALID_PARAMS',
      );
      failure(
        await data.call('day', 'updatePreferences', {'isCardView': 'yes'}),
        'INVALID_PARAMS',
      );
    });

    test('restoreBackup 恢复迁移备份建立时的状态', () async {
      await value(
        await data.call('day', 'create', {
          'id': 'd1',
          'title': '原始',
          'targetDate': '2030-01-01T00:00:00.000',
        }),
      );
      // 首次 preferences 写入前建立迁移备份（days=[d1 原始]，无偏好文件）
      await value(
        await data.call('day', 'updatePreferences', {'sortMode': 'manual'}),
      );
      await value(
        await data.call('day', 'update', {'id': 'd1', 'title': '改名'}),
      );
      await value(
        await data.call('day', 'create', {
          'id': 'd2',
          'title': '新增',
          'targetDate': '2030-02-01T00:00:00.000',
        }),
      );

      final restored =
          value(
            await data.call('day', 'restoreBackup', {
              'confirmRestore': true,
            }),
          )
          as Map;
      expect(restored['restored'], isTrue);

      final list = value(await data.call('day', 'getList')) as Map;
      final rows = (list['data'] as List).cast<Map>();
      expect(rows, hasLength(1));
      expect(rows.first['title'], '原始');
      final prefs = value(await data.call('day', 'getPreferences')) as Map;
      expect(prefs['sortMode'], 'upcoming');
      expect(prefs['isCardView'], isTrue);
    });

    test('损坏数据返回 CORRUPT_DATA', () async {
      await inject('day', 'memorial_days.json', {
        'days': [
          {'title': '缺ID'},
        ],
      });
      failure(await data.call('day', 'getList'), 'CORRUPT_DATA');
      await inject('day', 'view_preference.json', [1, 2]);
      failure(await data.call('day', 'getPreferences'), 'CORRUPT_DATA');
    });
  });

  group('calendar', () {
    test('日程 CRUD 往返与未知扩展字段保留', () async {
      final created =
          value(
            await data.call('calendar', 'create', {
              'id': 'e1',
              'title': '团队周会',
              'startTime': '2030-01-10T10:00:00.000',
              'endTime': '2030-01-10T11:00:00.000',
              'description': '例会',
              'reminderMinutes': 15,
              'repeatRule': {'freq': 'weekly'},
            }),
          )
          as Map;
      expect(created['description'], '例会');
      expect(created['reminderMinutes'], 15);
      // 未知扩展字段（如重复规则）原样保留
      expect(created['repeatRule'], {'freq': 'weekly'});
      expect(created['source'], 'default');

      final got =
          value(await data.call('calendar', 'getById', {'id': 'e1'})) as Map;
      expect(got['endTime'], '2030-01-10T11:00:00.000');

      final updated =
          value(
            await data.call('calendar', 'update', {'id': 'e1', 'title': '周会(改)'}),
          )
          as Map;
      expect(updated['title'], '周会(改)');
      final after =
          value(await data.call('calendar', 'getById', {'id': 'e1'})) as Map;
      expect(after['description'], '例会');
      expect(after['repeatRule'], {'freq': 'weekly'});

      failure(
        await data.call('calendar', 'create', {
          'id': 'e1',
          'title': 'x',
          'startTime': '2030-01-10T10:00:00.000',
        }),
        'CONFLICT',
      );
      failure(
        await data.call('calendar', 'update', {'id': 'missing', 'title': 'x'}),
        'NOT_FOUND',
      );
      failure(
        await data.call('calendar', 'create', {
          'id': 'ex',
          'title': '坏区间',
          'startTime': '2030-01-10T10:00:00.000',
          'endTime': '2030-01-10T09:00:00.000',
        }),
        'INVALID_PARAMS',
      );
      failure(
        await data.call('calendar', 'create', {
          'id': 'ex',
          'startTime': '2030-01-10T10:00:00.000',
        }),
        'INVALID_PARAMS',
      );

      expect(
        (value(await data.call('calendar', 'getList')) as Map)['total'],
        1,
      );
      await value(await data.call('calendar', 'delete', {'id': 'e1'}));
      failure(
        await data.call('calendar', 'getById', {'id': 'e1'}),
        'NOT_FOUND',
      );
    });

    test('completeEvent/restoreEvent 在双列表间流转', () async {
      await value(
        await data.call('calendar', 'create', {
          'id': 'e1',
          'title': '甲',
          'startTime': '2030-01-10T10:00:00.000',
        }),
      );
      await value(
        await data.call('calendar', 'create', {
          'id': 'e2',
          'title': '乙',
          'startTime': '2030-01-11T10:00:00.000',
        }),
      );

      final done =
          value(
            await data.call('calendar', 'completeEvent', {'id': 'e2'}),
          )
          as Map;
      expect(DateTime.tryParse(done['completedTime'] as String), isNotNull);

      final active =
          value(await data.call('calendar', 'getList')) as Map;
      expect(
        (active['data'] as List).map((r) => (r as Map)['id']).toList(),
        ['e1'],
      );
      final completed =
          value(
            await data.call('calendar', 'getList', {'completed': true}),
          )
          as Map;
      expect(
        (completed['data'] as List).map((r) => (r as Map)['id']).toList(),
        ['e2'],
      );

      // 已完成/不存在的日程不能再次完成
      failure(
        await data.call('calendar', 'completeEvent', {'id': 'e2'}),
        'NOT_FOUND',
      );
      failure(
        await data.call('calendar', 'completeEvent', {'id': 'missing'}),
        'NOT_FOUND',
      );

      final restoredEvent =
          value(
            await data.call('calendar', 'restoreEvent', {'id': 'e2'}),
          )
          as Map;
      expect(restoredEvent['completedTime'], isNull);
      final activeAgain =
          value(await data.call('calendar', 'getList')) as Map;
      expect(
        (activeAgain['data'] as List).map((r) => (r as Map)['id']).toList(),
        containsAll(['e1', 'e2']),
      );
      // 未完成日程不在完成列表，无法 restore
      failure(
        await data.call('calendar', 'restoreEvent', {'id': 'e1'}),
        'NOT_FOUND',
      );
      failure(
        await data.call('calendar', 'restoreEvent', {'id': 'missing'}),
        'NOT_FOUND',
      );
    });

    test('import/export 往返与 resetData', () async {
      await value(
        await data.call('calendar', 'create', {
          'id': 'e1',
          'title': '甲',
          'startTime': '2030-01-10T10:00:00.000',
        }),
      );
      await value(
        await data.call('calendar', 'create', {
          'id': 'e2',
          'title': '乙',
          'startTime': '2030-01-11T10:00:00.000',
        }),
      );
      await value(await data.call('calendar', 'completeEvent', {'id': 'e1'}));
      await value(
        await data.call('calendar', 'updatePreferences', {'view': 'month'}),
      );

      final exported =
          value(await data.call('calendar', 'exportData')) as Map;
      expect(exported['schemaVersion'], 1);
      expect(
        (exported['events'] as List).map((r) => (r as Map)['id']).toList(),
        ['e2'],
      );
      final completedRows =
          (exported['completedEvents'] as List).cast<Map>();
      expect(completedRows.map((r) => r['id']).toList(), ['e1']);
      final completedTime = completedRows.first['completedTime'];
      expect(completedTime, isNotNull);

      final cleared =
          value(await data.call('calendar', 'resetData')) as Map;
      expect(cleared['cleared'], isTrue);
      final snapshot =
          value(await data.call('calendar', 'getSnapshot')) as Map;
      expect(snapshot['events'], isEmpty);
      expect(snapshot['completedEvents'], isEmpty);
      final prefs =
          value(await data.call('calendar', 'getPreferences')) as Map;
      expect(prefs, {});

      // 导回后恢复原状（含完成态），重复导入幂等
      final payload = {
        'events': exported['events'],
        'completedEvents': exported['completedEvents'],
      };
      final imported =
          value(await data.call('calendar', 'importData', payload)) as Map;
      expect(imported['inserted'], 2);
      final again =
          value(await data.call('calendar', 'importData', payload)) as Map;
      expect(again['inserted'], 0);

      final back =
          value(await data.call('calendar', 'getById', {'id': 'e1'})) as Map;
      expect(back['completedTime'], completedTime);
      final active =
          value(await data.call('calendar', 'getList')) as Map;
      expect(
        (active['data'] as List).map((r) => (r as Map)['id']).toList(),
        ['e2'],
      );
    });

    test('restoreBackup 恢复首写前状态，且 resetData 不改写初始备份', () async {
      // 首次写入即建立迁移备份（此时为空状态）
      await value(
        await data.call('calendar', 'create', {
          'id': 'e1',
          'title': '甲',
          'startTime': '2030-01-10T10:00:00.000',
        }),
      );
      await value(
        await data.call('calendar', 'create', {
          'id': 'e2',
          'title': '乙',
          'startTime': '2030-01-11T10:00:00.000',
        }),
      );
      await value(await data.call('calendar', 'completeEvent', {'id': 'e1'}));
      await value(
        await data.call('calendar', 'updatePreferences', {'view': 'month'}),
      );

      final restored =
          value(
            await data.call('calendar', 'restoreBackup', {
              'confirmRestore': true,
            }),
          )
          as Map;
      expect(restored['restored'], isTrue);
      final snapshot =
          value(await data.call('calendar', 'getSnapshot')) as Map;
      expect(snapshot['events'], isEmpty);
      expect(snapshot['completedEvents'], isEmpty);
      final prefs =
          value(await data.call('calendar', 'getPreferences')) as Map;
      expect(prefs, {});

      // resetData 之后备份仍是首写前状态，restoreBackup 再次清空
      await value(
        await data.call('calendar', 'create', {
          'id': 'e3',
          'title': '丙',
          'startTime': '2030-01-12T10:00:00.000',
        }),
      );
      await value(await data.call('calendar', 'resetData'));
      await value(
        await data.call('calendar', 'create', {
          'id': 'e4',
          'title': '丁',
          'startTime': '2030-01-13T10:00:00.000',
        }),
      );
      await value(
        await data.call('calendar', 'restoreBackup', {
          'confirmRestore': true,
        }),
      );
      final snapshotAgain =
          value(await data.call('calendar', 'getSnapshot')) as Map;
      expect(snapshotAgain['events'], isEmpty);
      expect(snapshotAgain['completedEvents'], isEmpty);
    });

    test('损坏数据返回 CORRUPT_DATA', () async {
      await inject('calendar', 'calendar_events.json', {'events': 'bad'});
      failure(await data.call('calendar', 'getList'), 'CORRUPT_DATA');
      await inject('calendar', 'calendar_events.json', {
        'events': [
          {'title': '缺ID'},
        ],
        'completedEvents': <Map>[],
      });
      failure(await data.call('calendar', 'getSnapshot'), 'CORRUPT_DATA');
    });
  });

  test('三域原始文件写入封闭（426 / unsupported）', () async {
    // writeFile 的策略检查是同步抛出，用 Future.sync 统一转为 rejected Future
    Future<void> expect426(Future<void> Function() op) => expectLater(
      Future.sync(op),
      throwsA(
        isA<StorageException>()
            .having((e) => e.statusCode, 'status', 426)
            .having((e) => e.kind, 'kind', StorageErrorKind.unsupported),
      ),
    );
    for (final op in <Future<void> Function()>[
      () => data.writeFile('contact', 'contacts.json', []),
      () => data.writePath('contact/interactions.json', []),
      () => data.deleteFile('contact', 'filter_config'),
      () => data.writePath('day/memorial_days.json', []),
      () => data.writePath('day/view_preference.json', {}),
      () => data.writePath('calendar/calendar_events.json', {}),
      () => data.deletePath('calendar/calendar_last_view.json'),
      // Windows 大小写等价路径同样不可绕过
      () => data.writePath('Contact/x.json', {}),
      () => data.clearPathPrefix('contact'),
      () => data.clearPathPrefix('day/'),
      () => data.clearPathPrefix('calendar'),
    ]) {
      await expect426(op);
    }
  });

  test('restoreBackup 缺 confirmRestore 拒绝（与记录域语义一致）', () async {
    for (final domain in ['contact', 'day', 'calendar']) {
      final failed = await data.call(domain, 'restoreBackup', {});
      expect(failed['success'], isFalse, reason: '$domain: $failed');
      expect(failed['code'], 'INVALID_PARAMS', reason: '$domain: $failed');
    }
  });

  test('calendar resetData 空库首调后备份格式可恢复', () async {
    // 空库直接 resetData：备份须为 files 格式（可 restoreBackup），而非 snapshot 格式
    await value(await data.call('calendar', 'resetData'));
    await value(await data.call('calendar', 'create', {
      'id': 'e1',
      'title': '甲',
      'startTime': '2030-01-01T10:00:00.000',
    }));
    final restored =
        value(
          await data.call('calendar', 'restoreBackup', {
            'confirmRestore': true,
          }),
        )
        as Map;
    expect(restored['restored'], isTrue);
    final snapshot =
        value(await data.call('calendar', 'getSnapshot')) as Map;
    expect(snapshot['events'], isEmpty);
  });
}
