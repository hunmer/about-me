import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('activity_cross_day_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });
  dynamic ok(Map result) {
    expect(result['success'], isTrue, reason: '$result');
    return result['data'];
  }

  Future<void> create(String id, String start, String end) async => ok(
    await data.call('activity', 'create', {
      'id': id,
      'title': id,
      'startTime': start,
      'endTime': end,
      'tags': ['睡觉'],
      'mood': 4,
    }),
  );
  Future<List<Map>> day(String date) async =>
      (ok(await data.get('activity', 'getList', {'date': date}))['data']
              as List)
          .cast<Map>();
  int minutes(List<Map> rows) => rows.fold(
    0,
    (n, row) =>
        n +
        DateTime.parse(
          row['endTime'],
        ).difference(DateTime.parse(row['startTime'])).inMinutes,
  );

  test('23点到次日1点按日落盘，首日截止午夜、次日从午夜开始', () async {
    await create('sleep', '2026-10-24T23:00:00', '2026-10-25T01:00:00');
    final first = (await day('2026-10-24')).single;
    final second = (await day('2026-10-25')).single;
    expect(DateTime.parse(first['endTime']), DateTime(2026, 10, 25));
    expect(DateTime.parse(second['startTime']), DateTime(2026, 10, 25));
    expect(minutes([first]), 60);
    expect(minutes([second]), 60);
    expect(first['id'], 'sleep');
    expect(second['id'], isNot(first['id']));
    expect(second['tags'], ['睡觉']);
    expect(second['mood'], 4);
    for (final date in ['2026-10-24', '2026-10-25']) {
      final stored = jsonDecode(
        await File(
          '${root.path}/activity/activities_$date.json',
        ).readAsString(),
      );
      expect(stored['activities'], hasLength(1));
    }
  });

  test('跨多日及结束时间恰为午夜，不创建零时长尾段', () async {
    await create('long', '2026-10-24T23:00:00', '2026-10-27T00:00:00');
    expect(minutes(await day('2026-10-24')), 60);
    expect(minutes(await day('2026-10-25')), 1440);
    expect(minutes(await day('2026-10-26')), 1440);
    expect(await day('2026-10-27'), isEmpty);
    final stats = ok(
      await data.get('activity', 'getRangeStats', {
        'startDate': '2026-10-25',
        'endDate': '2026-10-26',
      }),
    );
    expect(stats['durationMinutes'], 2880);
  });

  for (final suffix in ['', 'Z', '+08:00', '-05:00']) {
    test('跨天按输入时区的午夜拆分 $suffix', () async {
      await create(
        'tz',
        '2026-10-24T23:00:00$suffix',
        '2026-10-25T01:00:00$suffix',
      );
      final first = (await day('2026-10-24')).single;
      final second = (await day('2026-10-25')).single;
      expect(
        DateTime.parse(first['endTime']),
        DateTime.parse('2026-10-25T00:00:00$suffix'),
      );
      expect(
        DateTime.parse(second['startTime']),
        DateTime.parse('2026-10-25T00:00:00$suffix'),
      );
      expect(minutes([first, second]), 120);
    });
  }

  test('已有跨天记录只读即可按日展示，次日片段可编辑和删除且首日不受影响', () async {
    final file = File('${root.path}/activity/activities_2026-10-24.json');
    await file.parent.create(recursive: true);
    final original = jsonEncode([
      {
        'id': 'legacy',
        'title': '旧记录',
        'startTime': '2026-10-24T23:00:00',
        'endTime': '2026-10-25T01:00:00',
      },
    ]);
    await file.writeAsString(original);
    final second = (await day('2026-10-25')).single;
    expect(minutes(await day('2026-10-24')), 60);
    expect(minutes([second]), 60);
    expect(await file.readAsString(), original);
    expect(
      await File('${root.path}/activity/activities_2026-10-25.json').exists(),
      isFalse,
    );
    expect(
      ok(
        await data.get('activity', 'getById', {
          'date': '2026-10-25',
          'id': second['id'],
        }),
      )['title'],
      '旧记录',
    );

    ok(
      await data.call('activity', 'update', {
        'date': '2026-10-25',
        'id': second['id'],
        'title': '修改次日',
      }),
    );
    expect((await day('2026-10-25')).single['title'], '修改次日');
    expect((await day('2026-10-24')).single['title'], '旧记录');
    ok(
      await data.call('activity', 'delete', {
        'date': '2026-10-25',
        'id': second['id'],
      }),
    );
    expect(await day('2026-10-25'), isEmpty);
    expect(minutes(await day('2026-10-24')), 60);
  });

  test('跨天创建逐日处理重叠，包括原本从前一天延续的记录', () async {
    await create('old', '2026-10-24T22:00:00', '2026-10-25T02:00:00');
    await create('new', '2026-10-24T23:00:00', '2026-10-25T01:00:00');
    final first = await day('2026-10-24');
    final second = await day('2026-10-25');
    expect(first.map((r) => r['title']), ['old', 'new']);
    expect(second.map((r) => r['title']), ['new', 'old']);
    expect(minutes(first), 120);
    expect(minutes(second), 120);
    expect(DateTime.parse(first.first['endTime']), DateTime(2026, 10, 24, 23));
    expect(DateTime.parse(second.last['startTime']), DateTime(2026, 10, 25, 1));
  });

  test('更新为跨天时段后，两天都能查询', () async {
    await create('updated', '2026-10-24T22:00:00', '2026-10-24T23:00:00');
    ok(
      await data.call('activity', 'update', {
        'date': '2026-10-24',
        'id': 'updated',
        'endTime': '2026-10-25T01:00:00',
      }),
    );
    expect(minutes(await day('2026-10-24')), 120);
    expect(minutes(await day('2026-10-25')), 60);
  });
}
