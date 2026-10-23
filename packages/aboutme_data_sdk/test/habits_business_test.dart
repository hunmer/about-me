import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('habits_sdk_');
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
    await f.writeAsString(jsonEncode(value));
  }

  test(
    'habits/skills CRUD, records append/remove, settings, stats and backup',
    () async {
      // 旧客户端顶层 List 格式直接可读
      await fixture('habits/habits.json', [
        {'id': 'h1', 'title': '晨跑', 'group': '健康', 'totalDurationMinutes': 0},
      ]);
      ok(
        await data.call('habits', 'create', {
          'id': 'h2',
          'title': '冥想',
          'durationMinutes': 15,
          'tags': ['专注'],
          'skillId': 's1',
        }),
      );
      expect(
        (await data.call('habits', 'create', {
          'id': 'h2',
          'title': '重复',
        }))['code'],
        'CONFLICT',
      );
      expect(
        (await data.call('habits', 'create', {'id': 'x'}))['code'],
        'INVALID_PARAMS',
      );
      expect(
        ok(await data.call('habits', 'update', {'id': 'h1', 'title': '跑步'}))[
            'title'],
        '跑步',
      );
      expect(
        (await data.call('habits', 'update', {'id': 'nope', 'title': 'x'}))[
            'code'],
        'NOT_FOUND',
      );
      expect(
        (ok(await data.get('habits', 'getById', {'id': 'h2'})) as Map)['skillId'],
        's1',
      );
      expect(
        ((ok(await data.get('habits', 'getList', {'group': '健康'})) as Map)[
                'data'] as List)
            .length,
        1,
      );
      ok(await data.call('habits', 'delete', {'id': 'h2'}));

      // skills CRUD
      ok(
        await data.call('habits', 'createSkill', {
          'id': 's1',
          'title': '健康生活',
          'targetMinutes': 60000,
        }),
      );
      expect(
        (await data.call('habits', 'createSkill', {
          'id': 's1',
          'title': '重复',
        }))['code'],
        'CONFLICT',
      );
      expect(
        ok(await data.call('habits', 'updateSkill', {
          'id': 's1',
          'description': '运动与冥想',
        }))['description'],
        '运动与冥想',
      );
      expect(
        ((ok(await data.get('habits', 'getSkills')) as Map)['data'] as List)
            .length,
        1,
      );
      expect(
        ok(await data.get('habits', 'getSkillById', {'id': 's1'}))['title'],
        '健康生活',
      );
      ok(await data.call('habits', 'deleteSkill', {'id': 's1'}));

      // records：追加、读取、删除、清空；联动习惯总时长
      final r1 = ok(
        await data.call('habits', 'addRecord', {
          'parentId': 'h1',
          'duration': 1800,
          'date': '2026-10-01T00:00:00.000Z',
          'notes': '5公里',
        }),
      ) as Map;
      ok(
        await data.call('habits', 'addRecord', {
          'parentId': 'h1',
          'duration': 900,
          'date': '2026-10-02T00:00:00.000Z',
        }),
      );
      expect(
        (await data.call('habits', 'addRecord', {
          'id': r1['id'],
          'parentId': 'h1',
          'duration': 60,
        }))['code'],
        'CONFLICT',
      );
      final records = ok(
        await data.get('habits', 'getRecords', {'parentId': 'h1'}),
      ) as Map;
      expect((records['data'] as List).length, 2);
      final stats = ok(
        await data.get('habits', 'getStats', {'habitId': 'h1'}),
      ) as Map;
      expect(stats['totalDurationMinutes'], 45);
      expect(stats['completionCount'], 2);
      expect(
        ok(await data.get('habits', 'getById', {'id': 'h1'}))[
            'totalDurationMinutes'],
        45,
      );

      final removed = ok(
        await data.call('habits', 'deleteRecord', {'id': r1['id']}),
      ) as Map;
      expect(removed['parentId'], 'h1');
      expect(
        ((ok(
          await data.get('habits', 'getRecords', {'parentId': 'h1'}),
        ) as Map)['data'] as List)
            .length,
        1,
      );
      expect(
        ok(await data.get('habits', 'getStats', {'habitId': 'h1'}))[
            'totalDurationMinutes'],
        15,
      );
      ok(await data.call('habits', 'clearRecords', {'parentId': 'h1'}));
      expect(
        ((ok(
          await data.get('habits', 'getRecords', {'parentId': 'h1'}),
        ) as Map)['data'] as List)
            .isEmpty,
        true,
      );
      expect(
        ok(await data.get('habits', 'getById', {'id': 'h1'}))[
            'totalDurationMinutes'],
        0,
      );

      // view_settings
      ok(
        await data.call('habits', 'updateSettings', {'heatmapView': true}),
      );
      expect(
        ok(await data.get('habits', 'getSettings'))['heatmapView'],
        true,
      );

      // 首写备份：保留原始主集合内容
      final backup = jsonDecode(
        await File(root.path + '/habits/migration_v1_backup.json')
            .readAsString(),
      ) as Map;
      expect(backup['schemaVersion'], 1);
      expect((backup['habits'] as List).length, 1);
      expect((backup['habits'] as List).first['title'], '晨跑');

      final snapshot = ok(await data.get('habits', 'getSnapshot')) as Map;
      expect((snapshot['habits'] as List).length, 1);
      expect(snapshot['settings'], {'heatmapView': true});
    },
  );

  test('seedExamples inserts only empty collections and stays idempotent', () async {
    final res = ok(
      await data.call('habits', 'seedExamples', {
        'habits': [
          {'id': 'demo', 'title': '示例', 'durationMinutes': 10},
        ],
        'skills': [
          {'id': 'demo-skill', 'title': '示例技能'},
        ],
        'records': {
          'demo': [
            {'id': 'rec1', 'parentId': 'demo', 'duration': 600},
          ],
        },
      }),
    ) as Map;
    expect(res['insertedHabits'], 1);
    expect(res['insertedSkills'], 1);
    expect(res['insertedRecords'], 1);
    final again = ok(
      await data.call('habits', 'seedExamples', {
        'habits': [
          {'id': 'demo2', 'title': '再种'},
        ],
      }),
    ) as Map;
    expect(again['insertedHabits'], 0);
    expect(
      ((ok(await data.get('habits', 'getSnapshot')) as Map)['habits'] as List)
          .length,
      1,
    );
    expect(
      ((ok(await data.get('habits', 'getRecords', {'parentId': 'demo'}))
              as Map)['data'] as List)
          .length,
      1,
    );
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await fixture('habits/habits.json', {'habits': 'broken'});
    expect(
      (await data.call('habits', 'create', {'id': 'x', 'title': 't'}))['code'],
      'CORRUPT_DATA',
    );
    expect((await data.get('habits', 'getSnapshot'))['code'], 'CORRUPT_DATA');
    await fixture('habits/skills.json', 'broken');
    expect(
      (await data.call('habits', 'createSkill', {'id': 's', 'title': 't'}))[
          'code'],
      'CORRUPT_DATA',
    );
    await fixture('habits/records/h1.json', {'x': 1});
    expect(
      (await data.get('habits', 'getRecords', {'parentId': 'h1'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.get('habits', 'getStats', {'habitId': 'h1'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      jsonDecode(
        await File(root.path + '/habits/habits.json').readAsString(),
      ),
      {'habits': 'broken'},
    );
    expect(
      await File(root.path + '/habits/migration_v1_backup.json').exists(),
      false,
    );
  });

  test('two SDK instances append habits and records without losing data', () async {
    final second = AboutmeData.local(root.path);
    try {
      await Future.wait(
        List.generate(20, (i) async {
          ok(
            await (i.isEven ? data : second).call('habits', 'create', {
              'id': 'h$i',
              'title': '$i',
              'clientMutationId': 'habit-$i',
            }),
          );
        }),
      );
      expect(
        ((ok(await data.get('habits', 'getSnapshot')) as Map)['habits'] as List)
            .length,
        20,
      );
      await Future.wait(
        List.generate(20, (i) async {
          ok(
            await (i.isEven ? data : second).call('habits', 'addRecord', {
              'id': 'r$i',
              'parentId': 'h0',
              'duration': 60,
              'date': '2026-01-0${(i % 9) + 1}T00:00:00.000Z',
            }),
          );
        }),
      );
      expect(
        ((ok(
          await second.get('habits', 'getRecords', {'parentId': 'h0'}),
        ) as Map)['data'] as List)
            .length,
        20,
      );
    } finally {
      await second.dispose();
    }
  });
}
