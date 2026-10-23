import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('activity_sdk_');
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

  test('分日活动 CRUD：兼容数组/对象格式、按日期文件读写、排序', () async {
    // 旧客户端顶层数组格式直接可读
    await fixture('activity/activities_2026-10-01.json', [
      {
        'id': 'a1',
        'startTime': '2026-10-01T09:00:00.000',
        'endTime': '2026-10-01T10:00:00.000',
        'title': '晨跑',
        'tags': ['运动'],
      },
    ]);
    // 对象格式 {"activities": [...]} 可读
    await fixture('activity/activities_2026-10-02.json', {
      'activities': [
        {
          'id': 'a2',
          'startTime': '2026-10-02T09:00:00.000',
          'endTime': '2026-10-02T10:00:00.000',
          'title': '阅读',
          'tags': ['学习'],
        },
      ],
    });

    // getList 按日期读取（缺省日期为今天，无数据为空）
    final day1 = ok(
      await data.get('activity', 'getList', {'date': '2026-10-01'}),
    ) as Map;
    expect(day1['total'], 1);
    expect((day1['data'] as List).first['id'], 'a1');

    // create：按 startTime 定位日期文件，插入后按开始时间排序
    final created = ok(
      await data.call('activity', 'create', {
        'id': 'a0',
        'startTime': '2026-10-01T07:00:00.000',
        'endTime': '2026-10-01T08:00:00.000',
        'title': '早读',
        'tags': ['学习'],
      }),
    ) as Map;
    expect(created['id'], 'a0');
    final day1After = ((ok(
      await data.get('activity', 'getList', {'date': '2026-10-01'}),
    ) as Map)['data'] as List);
    expect(day1After.map((a) => a['id']), ['a0', 'a1']);

    // getById / update / delete 均按 date + id 定位
    expect(
      (ok(
        await data.get('activity', 'getById', {
          'id': 'a1',
          'date': '2026-10-01',
        }),
      ))['title'],
      '晨跑',
    );
    expect(
      (await data.get('activity', 'getById', {
        'id': 'nope',
        'date': '2026-10-01',
      }))['code'],
      'NOT_FOUND',
    );
    expect(
      (ok(
        await data.call('activity', 'update', {
          'id': 'a1',
          'date': '2026-10-01',
          'title': '晨跑2',
        }),
      ))['title'],
      '晨跑2',
    );
    ok(
      await data.call('activity', 'delete', {'id': 'a0', 'date': '2026-10-01'}),
    );
    expect(
      (ok(
        await data.get('activity', 'getList', {'date': '2026-10-01'}),
      ))['total'],
      1,
    );

    // 落盘为对象格式，其他日期文件不受影响
    final saved = jsonDecode(
      await File(root.path + '/activity/activities_2026-10-01.json')
          .readAsString(),
    ) as Map;
    expect((saved['activities'] as List).length, 1);
    expect((saved['activities'] as List).first['title'], '晨跑2');
    final day2 = jsonDecode(
      await File(root.path + '/activity/activities_2026-10-02.json')
          .readAsString(),
    ) as Map;
    expect((day2['activities'] as List).length, 1, reason: '未被触碰的文件不被重写');
  });

  test('getRange / getRangeStats：枚举分日文件按区间聚合（含两端）', () async {
    await fixture('activity/activities_2026-10-01.json', [
      {
        'id': 'a1',
        'startTime': '2026-10-01T09:00:00.000',
        'endTime': '2026-10-01T10:00:00.000',
        'title': '晨跑',
        'tags': ['运动'],
      },
      {
        'id': 'a2',
        'startTime': '2026-10-01T10:00:00.000',
        'endTime': '2026-10-01T11:30:00.000',
        'title': '复盘',
        'tags': ['运动', '学习'],
      },
    ]);
    await fixture('activity/activities_2026-10-03.json', [
      {
        'id': 'a3',
        'startTime': '2026-10-03T20:00:00.000',
        'endTime': '2026-10-03T20:30:00.000',
        'title': '阅读',
        'tags': ['学习'],
      },
    ]);
    await fixture('activity/activities_2026-10-05.json', [
      {
        'id': 'a4',
        'startTime': '2026-10-05T09:00:00.000',
        'endTime': '2026-10-05T10:00:00.000',
        'title': '区间外',
        'tags': ['运动'],
      },
    ]);

    // 区间列表：含两端、跨日按开始时间升序、排除区间外文件
    final range = ok(
      await data.get('activity', 'getRange', {
        'startDate': '2026-10-01',
        'endDate': '2026-10-03',
      }),
    ) as Map;
    expect(range['total'], 3);
    expect(
      (range['data'] as List).map((a) => a['id']),
      ['a1', 'a2', 'a3'],
    );
    // 支持分页
    final paged = ok(
      await data.get('activity', 'getRange', {
        'startDate': '2026-10-01',
        'endDate': '2026-10-03',
        'offset': 1,
        'count': 1,
      }),
    ) as Map;
    expect((paged['data'] as List).map((a) => a['id']), ['a2']);
    expect(paged['hasMore'], true);

    // 区间统计：活动数、总分钟数、按标签聚合分钟数
    final stats = ok(
      await data.get('activity', 'getRangeStats', {
        'startDate': '2026-10-01',
        'endDate': '2026-10-03',
      }),
    ) as Map;
    expect(stats['activityCount'], 3);
    expect(stats['durationMinutes'], 180);
    expect(stats['tagStats'], {'运动': 150, '学习': 120});

    // 起止颠倒与同日区间
    final reversed = ok(
      await data.get('activity', 'getRange', {
        'startDate': '2026-10-03',
        'endDate': '2026-10-01',
      }),
    ) as Map;
    expect(reversed['total'], 0);
    final singleDay = ok(
      await data.get('activity', 'getRangeStats', {
        'startDate': '2026-10-03',
        'endDate': '2026-10-03',
      }),
    ) as Map;
    expect(singleDay['durationMinutes'], 30);

    // 非法参数
    expect(
      (await data.get('activity', 'getRange', {'startDate': '2026-10-01'}))[
          'code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.get('activity', 'getRangeStats', {
        'startDate': '2026-10-01',
        'endDate': 'not-a-date',
      }))['code'],
      'INVALID_PARAMS',
    );
  });

  test('标签分组 / 最近标签 / 最近心情：整文件读写与参数校验', () async {
    // 缺文件：分组 exists=false、三个集合均为空
    final emptyGroups = ok(await data.get('activity', 'getTagGroups')) as Map;
    expect(emptyGroups['exists'], false);
    expect((emptyGroups['data'] as List), isEmpty);
    expect(ok(await data.get('activity', 'getRecentTags')), isEmpty);
    expect(ok(await data.get('activity', 'getRecentMoods')), isEmpty);

    // 整体写入（分组内标签兼容对象与字符串旧格式）
    ok(
      await data.call('activity', 'updateTagGroups', {
        'groups': [
          {
            'name': '工作',
            'tags': [
              {
                'name': '会议',
                'group': '工作',
                'icon': '58721',
                'color': 4280391411,
                'createdAt': '2026-10-01T00:00:00.000',
              },
            ],
          },
          {'name': '生活', 'tags': ['吃饭']},
        ],
      }),
    );
    ok(
      await data.call('activity', 'updateRecentTags', {'tags': ['会议', '复盘']}),
    );
    ok(
      await data.call('activity', 'updateRecentMoods', {'moods': ['😄', '😴']}),
    );

    final groups = ok(await data.get('activity', 'getTagGroups')) as Map;
    expect(groups['exists'], true);
    expect((groups['data'] as List).length, 2);
    expect((groups['data'] as List).first['name'], '工作');
    expect(ok(await data.get('activity', 'getRecentTags')), ['会议', '复盘']);
    expect(ok(await data.get('activity', 'getRecentMoods')), ['😄', '😴']);

    // 落盘为旧客户端一致的顶层数组格式
    expect(
      jsonDecode(
        await File(root.path + '/activity/recent_tags.json').readAsString(),
      ),
      ['会议', '复盘'],
    );

    // 参数校验
    expect(
      (await data.call('activity', 'updateTagGroups', {'groups': 'x'}))[
          'code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('activity', 'updateTagGroups', {
        'groups': [
          {'name': 123},
        ],
      }))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('activity', 'updateRecentTags', {'tags': [1]}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('activity', 'updateRecentMoods', {'moods': 3}))['code'],
      'INVALID_PARAMS',
    );

    // 覆盖写（清空后 exists 仍为 true）
    ok(await data.call('activity', 'updateRecentTags', {'tags': []}));
    expect(ok(await data.get('activity', 'getRecentTags')), isEmpty);
    final afterClear = ok(await data.get('activity', 'getTagGroups')) as Map;
    expect(afterClear['exists'], true);
  });

  test('损坏数据返回 CORRUPT_DATA 且文件保持原样', () async {
    await fixture('activity/activities_2026-10-01.json', {
      'activities': 'broken',
    });
    expect(
      (await data.get('activity', 'getList', {'date': '2026-10-01'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('activity', 'create', {
        'startTime': '2026-10-01T08:00:00.000',
        'endTime': '2026-10-01T09:00:00.000',
        'title': 'x',
      }))['code'],
      'CORRUPT_DATA',
    );
    await fixture('activity/activities_2026-10-02.json', ['not-a-map']);
    expect(
      (await data.get('activity', 'getRange', {
        'startDate': '2026-10-01',
        'endDate': '2026-10-03',
      }))['code'],
      'CORRUPT_DATA',
    );

    await fixture('activity/tag_groups.json', {'name': 'x'});
    expect(
      (await data.get('activity', 'getTagGroups'))['code'],
      'CORRUPT_DATA',
    );
    await fixture('activity/recent_tags.json', [1, 2]);
    expect(
      (await data.get('activity', 'getRecentTags'))['code'],
      'CORRUPT_DATA',
    );
    await fixture('activity/recent_moods.json', 'broken');
    expect(
      (await data.get('activity', 'getRecentMoods'))['code'],
      'CORRUPT_DATA',
    );

    // 失败不落盘：原文件内容不被改写
    expect(
      jsonDecode(
        await File(root.path + '/activity/activities_2026-10-01.json')
            .readAsString(),
      ),
      {'activities': 'broken'},
    );
    expect(
      jsonDecode(
        await File(root.path + '/activity/recent_moods.json').readAsString(),
      ),
      'broken',
    );
  });
}
