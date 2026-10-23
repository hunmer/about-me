import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

/// calendar_album 域业务测试：条目 CRUD（日期键结构）、按月查询、
/// tags 三文件读写（沿用 data/ 顶层原路径）、import/export 往返、
/// 损坏 CORRUPT_DATA、首写备份、seedExamples 幂等。
void main() {
  late Directory root;
  late AboutmeData data;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('album_biz_');
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

  // 损坏数据用磁盘直写注入（参照 contact_day_calendar_contract_test）。
  Future<void> inject(String path, dynamic content) async {
    final target = File('${root.path}/$path');
    await target.parent.create(recursive: true);
    await target.writeAsString(jsonEncode(content));
  }

  const day1 = '2026-05-10';
  const day2 = '2026-05-20';
  const day3 = '2026-06-01';
  String keyOf(String day) =>
      DateTime.parse(day).toIso8601String(); // 2026-05-10T00:00:00.000

  Future<Map<String, dynamic>> snapshot() async =>
      value(await data.call('calendar_album', 'getSnapshot'))
          as Map<String, dynamic>;

  group('条目 CRUD（日期键结构）', () {
    test('create 按日期分组、默认字段补全', () async {
      final created =
          value(
            await data.call('calendar_album', 'create', {
              'id': 'e1',
              'title': '野餐',
              'createdAt': '${day1}T09:30:00.000',
              'tags': ['休闲'],
              'imageUrls': ['assets/a.jpg'],
            }),
          )
          as Map;
      expect(created['content'], '');
      expect(created['thumbUrls'], []);
      expect(created['mood'], isNull);

      final entries = (await snapshot())['data'] as Map;
      expect(entries.containsKey(keyOf(day1)), isTrue);
      final bucket = (entries[keyOf(day1)] as List).cast<Map>();
      expect(bucket.length, 1);
      expect(bucket.first['id'], 'e1');
      expect(bucket.first['title'], '野餐');
    });

    test('create 缺 id 自动生成、同 id 返回 CONFLICT', () async {
      final created =
          value(
            await data.call('calendar_album', 'create', {
              'title': '自动 ID',
              'createdAt': day1,
            }),
          )
          as Map;
      expect((created['id'] as String).isNotEmpty, isTrue);

      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '重复',
          'createdAt': day1,
        }),
      );
      failure(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '重复',
          'createdAt': day1,
        }),
        'CONFLICT',
      );
    });

    test('update 按 date+id patch 且保留未提交字段', () async {
      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '旧标题',
          'content': '旧内容',
          'createdAt': '${day1}T08:00:00.000',
          'location': '公园',
        }),
      );
      final updated =
          value(
            await data.call('calendar_album', 'update', {
              'date': day1,
              'id': 'e1',
              'title': '新标题',
            }),
          )
          as Map;
      expect(updated['title'], '新标题');
      expect(updated['content'], '旧内容');
      expect(updated['location'], '公园');
      // date 不得混入条目字段
      expect(updated.containsKey('date'), isFalse);

      failure(
        await data.call('calendar_album', 'update', {
          'date': day1,
          'id': 'missing',
          'title': 'x',
        }),
        'NOT_FOUND',
      );
    });

    test('delete 按 date+id 删除且清空日期键', () async {
      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '待删',
          'createdAt': day1,
        }),
      );
      await value(
        await data.call('calendar_album', 'delete', {
          'date': day1,
          'id': 'e1',
        }),
      );
      final entries = (await snapshot())['data'] as Map;
      expect(entries.containsKey(keyOf(day1)), isFalse);
      failure(
        await data.call('calendar_album', 'delete', {'date': day1, 'id': 'e1'}),
        'NOT_FOUND',
      );
    });
  });

  group('按日期/月区间查询', () {
    test('month 与 date、startDate/endDate 过滤', () async {
      for (final (i, day) in [day1, day2, day3].indexed) {
        await value(
          await data.call('calendar_album', 'create', {
            'id': 'e$i',
            'title': '日记$i',
            'createdAt': day,
          }),
        );
      }
      final mayList =
          value(await data.call('calendar_album', 'getList', {'month': '2026-05'}))
              as Map;
      expect(mayList['total'], 2);
      expect((mayList['data'] as Map).keys,
          containsAll([keyOf(day1), keyOf(day2)]));

      final dayList =
          value(await data.call('calendar_album', 'getList', {'date': day2}))
              as Map;
      expect(dayList['total'], 1);
      expect((dayList['data'] as Map).keys, [keyOf(day2)]);

      final rangeList =
          value(
            await data.call('calendar_album', 'getList', {
              'startDate': day2,
              'endDate': day3,
            }),
          )
          as Map;
      expect(rangeList['total'], 2);

      failure(
        await data.call('calendar_album', 'getList', {'month': '2026-5'}),
        'INVALID_PARAMS',
      );
    });
  });

  group('tags 三文件（沿用 data/ 顶层原路径）', () {
    test('updateTags/getTags 读写与落盘位置', () async {
      final empty = value(await data.call('calendar_album', 'getTags')) as Map;
      expect(empty['tagGroups'], []);
      expect(empty['recentTags'], []);
      expect(empty['tagIcons'], {});

      final updated =
          value(
            await data.call('calendar_album', 'updateTags', {
              'tagGroups': [
                {'name': '地点', 'tags': ['家', '公司']},
                {'name': '最近使用', 'tags': []},
              ],
              'recentTags': ['家'],
              'tagIcons': {'家': 'home'},
            }),
          )
          as Map;
      expect((updated['tagGroups'] as List).length, 2);
      expect(updated['recentTags'], ['家']);
      expect(updated['tagIcons'], {'家': 'home'});

      // 真实落盘位置：data/ 顶层（与旧 StorageManager 路径一致）
      final groupsFile = File('${root.path}/data/calendar_tag_groups.json');
      expect(await groupsFile.exists(), isTrue);
      expect(jsonDecode(await groupsFile.readAsString()), [
        {'name': '地点', 'tags': ['家', '公司']},
        {'name': '最近使用', 'tags': []},
      ]);
      expect(
        jsonDecode(
          await File('${root.path}/data/calendar_recent_tags.json')
              .readAsString(),
        ),
        ['家'],
      );

      final reread = value(await data.call('calendar_album', 'getTags')) as Map;
      expect(reread['tagGroups'], [
        {'name': '地点', 'tags': ['家', '公司']},
        {'name': '最近使用', 'tags': []},
      ]);
    });

    test('updateTags 参数校验与空参数', () async {
      failure(
        await data.call('calendar_album', 'updateTags', {
          'recentTags': ['ok', 1],
        }),
        'INVALID_PARAMS',
      );
      failure(
        await data.call('calendar_album', 'updateTags', {}),
        'INVALID_PARAMS',
      );
    });
  });

  group('import/export 往返', () {
    test('导出→删除→导入恢复且按 id 幂等', () async {
      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '往返',
          'content': '![图](assets/p1.png)',
          'createdAt': day1,
          'imageUrls': ['assets/a.jpg'],
        }),
      );
      await value(
        await data.call('calendar_album', 'updateTags', {
          'tagGroups': [
            {'name': '心情', 'tags': ['开心']},
          ],
        }),
      );
      final exported = value(
        await data.call('calendar_album', 'exportData'),
      ) as Map;
      expect(exported['schemaVersion'], 1);

      await value(
        await data.call('calendar_album', 'delete', {'date': day1, 'id': 'e1'}),
      );
      final restored =
          value(
            await data.call('calendar_album', 'importData', {
              'entries': exported['entries'],
              'tags': exported['tags'],
            }),
          )
          as Map;
      expect(restored['inserted'], 1);

      // 再次导入同份数据：幂等，不重复
      final again =
          value(
            await data.call('calendar_album', 'importData', {
              'entries': exported['entries'],
            }),
          )
          as Map;
      expect(again['inserted'], 0);

      final entries = (await snapshot())['data'] as Map;
      expect((entries[keyOf(day1)] as List).length, 1);
      final tags = (await snapshot())['tags'] as Map;
      expect(tags['tagGroups'], [
        {'name': '心情', 'tags': ['开心']},
      ]);
    });

    test('importData 参数结构校验', () async {
      failure(
        await data.call('calendar_album', 'importData', {'entries': [1, 2]}),
        'INVALID_PARAMS',
      );
    });
  });

  group('getStats（照片数）', () {
    test('imageUrls 与 markdown 内联图去重统计', () async {
      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '带图',
          'content': '![图1](assets/p1.png) ![图2](assets/p2.png)',
          'createdAt': day1,
          'imageUrls': ['assets/p1.png', 'assets/p3.jpg'],
        }),
      );
      final stats =
          value(await data.call('calendar_album', 'getStats')) as Map;
      expect(stats['photoCount'], 3); // p1 去重 + p2 + p3
      expect(stats['totalEntries'], 1);
    });
  });

  group('损坏数据 CORRUPT_DATA', () {
    test('条目文件结构损坏', () async {
      await inject('calendar_album/calendar_entries.json', [1, 2, 3]);
      failure(await data.call('calendar_album', 'getSnapshot'), 'CORRUPT_DATA');
      failure(await data.call('calendar_album', 'getList'), 'CORRUPT_DATA');
    });

    test('条目行字段损坏（缺 id）与坏 JSON', () async {
      await inject('calendar_album/calendar_entries.json', {
        keyOf(day1): [
          {'title': '无 id'},
        ],
      });
      failure(await data.call('calendar_album', 'getSnapshot'), 'CORRUPT_DATA');

      await File('${root.path}/calendar_album/calendar_entries.json')
          .writeAsString('{bad json');
      failure(
        await data.call('calendar_album', 'create', {
          'id': 'x',
          'title': 't',
          'createdAt': day1,
        }),
        'CORRUPT_DATA',
      );
    });

    test('tag 文件损坏', () async {
      await inject('data/calendar_tag_groups.json', 'not-a-list');
      failure(await data.call('calendar_album', 'getTags'), 'CORRUPT_DATA');
    });
  });

  group('首写备份', () {
    test('首次写操作前备份原数据（含 data/ 顶层 tag 文件）', () async {
      final originalEntries = {
        keyOf(day1): [
          {
            'id': 'legacy',
            'title': '旧数据',
            'content': '',
            'createdAt': '${day1}T10:00:00.000',
            'updatedAt': '${day1}T10:00:00.000',
            'tags': [],
            'imageUrls': [],
            'thumbUrls': [],
            'liveVideoUrls': [],
          },
        ],
      };
      await inject('calendar_album/calendar_entries.json', originalEntries);
      await inject('data/calendar_recent_tags.json', ['旧标签']);

      await value(
        await data.call('calendar_album', 'create', {
          'id': 'e1',
          'title': '新数据',
          'createdAt': day1,
        }),
      );

      final backup = jsonDecode(
        await File('${root.path}/calendar_album/sdk_migration_backup.json')
            .readAsString(),
      ) as Map;
      expect(backup['pluginId'], 'calendar_album');
      final files = backup['files'] as Map;
      expect(files['calendar_entries.json'], originalEntries);
      expect(files['data/calendar_recent_tags.json'], ['旧标签']);
      expect(files.containsKey('data/calendar_tag_groups.json'), isTrue);

      // 二次写不覆盖首次备份
      await inject('calendar_album/calendar_entries.json', {'dirty': []});
      await value(
        await data.call('calendar_album', 'updateTags', {
          'recentTags': ['新'],
        }),
      );
      final backupAgain = jsonDecode(
        await File('${root.path}/calendar_album/sdk_migration_backup.json')
            .readAsString(),
      ) as Map;
      expect((backupAgain['files'] as Map)['calendar_entries.json'],
          originalEntries);
    });
  });

  group('seedExamples 幂等', () {
    test('首播插入、重复调用不再插入', () async {
      final first =
          value(await data.call('calendar_album', 'seedExamples')) as Map;
      expect(first['inserted'], 2);
      final second =
          value(await data.call('calendar_album', 'seedExamples')) as Map;
      expect(second['inserted'], 0);

      final entries = (await snapshot())['data'] as Map;
      var total = 0;
      entries.forEach((_, v) => total += (v as List).length);
      expect(total, 2);
    });
  });
}
