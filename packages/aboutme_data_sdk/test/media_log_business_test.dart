import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('media_log_sdk_');
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

  test('items CRUD, reviews, settings, stats, import/export and backup', () async {
    // 旧客户端 {items: []} 格式直接可读
    await fixture('media_log/items.json', {
      'items': [
        {
          'id': 'b1',
          'kind': 'reading',
          'title': '寻羊冒险记',
          'author': '村上春树',
          'rating': 4.3,
          'tags': ['小说'],
          'finishedAt': '2026-09-01T00:00:00.000Z',
          'createdAt': '2026-08-01T00:00:00.000Z',
          'reviews': [
            {'id': 'r-old', 'text': '旧点评', 'timestamp': '2026-09-02T00:00:00.000Z'},
          ],
        },
      ],
    });
    ok(
      await data.call('media_log', 'create', {
        'id': 'f1',
        'kind': 'watching',
        'title': '挪威的森林',
        'rating': 3.8,
        'tags': ['电影'],
        'createdAt': '2026-10-01T00:00:00.000Z',
      }),
    );
    expect(
      (await data.call('media_log', 'create', {
        'id': 'f1',
        'title': '重复',
      }))['code'],
      'CONFLICT',
    );
    expect(
      (await data.call('media_log', 'create', {'id': 'x'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      ok(await data.call('media_log', 'update', {'id': 'b1', 'rating': 4.5}))[
          'rating'],
      4.5,
    );
    expect(
      (await data.call('media_log', 'update', {'id': 'nope', 'title': 'x'}))[
          'code'],
      'NOT_FOUND',
    );
    expect(
      (ok(await data.get('media_log', 'getById', {'id': 'f1'})) as Map)['kind'],
      'watching',
    );
    // getList 过滤（kind / keyword 命中 author / finished）+ 默认 createdAt 倒序
    final list = ok(
      await data.get('media_log', 'getList', {'kind': 'reading'}),
    ) as Map;
    expect((list['data'] as List).length, 1);
    final byKeyword = (ok(
      await data.get('media_log', 'getList', {'keyword': '村上'}),
    ) as Map)['data'] as List;
    expect(byKeyword.length, 1);
    final byFinished = (ok(
      await data.get('media_log', 'getList', {'finished': true}),
    ) as Map)['data'] as List;
    expect(byFinished.length, 1);
    final all = ok(await data.get('media_log', 'getList')) as Map;
    expect((all['data'] as List).first['id'], 'f1');
    final paged = ok(
      await data.get('media_log', 'getList', {'offset': 1, 'count': 1}),
    ) as Map;
    expect(paged['total'], 2);
    expect(paged['count'], 1);
    expect(paged['hasMore'], false);

    // reviews：追加（timestamp 倒序）、upsert、删除
    final withReview = ok(
      await data.call('media_log', 'addReview', {
        'itemId': 'b1',
        'text': '很奇特的一本',
        'rating': 4,
        'timestamp': '2026-09-05T00:00:00.000Z',
      }),
    ) as Map;
    expect((withReview['reviews'] as List).length, 2);
    expect((withReview['reviews'] as List).first['text'], '很奇特的一本');
    final upserted = ok(
      await data.call('media_log', 'addReview', {
        'itemId': 'b1',
        'reviewId': 'r-old',
        'text': '改写后的旧点评',
        'timestamp': '2026-09-03T00:00:00.000Z',
      }),
    ) as Map;
    expect(
      (upserted['reviews'] as List)
          .firstWhere((r) => r['id'] == 'r-old')['text'],
      '改写后的旧点评',
    );
    expect(
      (await data.call('media_log', 'addReview', {'itemId': 'b1'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('media_log', 'addReview', {'itemId': 'nope', 'text': 'x'}))['code'],
      'NOT_FOUND',
    );
    final afterDelete = ok(
      await data.call('media_log', 'deleteReview', {
        'itemId': 'b1',
        'reviewId': 'r-old',
      }),
    ) as Map;
    expect((afterDelete['reviews'] as List).length, 1);

    // settings（ui_settings.json）
    ok(
      await data.call('media_log', 'updateSettings', {'viewMode': 'grid'}),
    );
    expect(
      ok(await data.get('media_log', 'getSettings'))['viewMode'],
      'grid',
    );

    // stats
    final stats = ok(await data.get('media_log', 'getStats')) as Map;
    expect(stats['total'], 2);
    expect(stats['reading'], 1);
    expect(stats['watching'], 1);
    expect(stats['finished'], 1);
    expect(stats['avgRating'], closeTo(4.15, 0.001));

    // 首写备份：保留原始主集合内容
    final backup = jsonDecode(
      await File(root.path + '/media_log/migration_v1_backup.json')
          .readAsString(),
    ) as Map;
    expect(backup['schemaVersion'], 1);
    expect((backup['items'] as Map)['items'] as List, hasLength(1));
    expect(
      ((backup['items'] as Map)['items'] as List).first['title'],
      '寻羊冒险记',
    );

    // export / import（按 id 去重合并）
    final exported = ok(await data.get('media_log', 'exportData')) as Map;
    expect(exported['schemaVersion'], 1);
    expect((exported['items'] as List).length, 2);
    expect((exported['settings'] as Map)['viewMode'], 'grid');
    final imported = ok(
      await data.call('media_log', 'importData', {
        'items': [
          {'id': 'b1', 'title': '重复导入应跳过'},
          {
            'id': 'new-1',
            'kind': 'reading',
            'title': '新书',
            'createdAt': '2026-10-10T00:00:00.000Z',
          },
        ],
        'settings': {'viewMode': 'list'},
      }),
    ) as Map;
    expect(imported['inserted'], 1);
    expect(imported['total'], 3);
    expect(
      ok(await data.get('media_log', 'getSettings'))['viewMode'],
      'list',
    );

    ok(await data.call('media_log', 'delete', {'id': 'f1'}));
    expect(
      (await data.call('media_log', 'delete', {'id': 'f1'}))['code'],
      'NOT_FOUND',
    );
    expect(
      ((ok(await data.get('media_log', 'getSnapshot')) as Map)['items'] as List)
          .length,
      2,
    );
  });

  test('seedExamples inserts only when empty and stays idempotent', () async {
    final res = ok(
      await data.call('media_log', 'seedExamples', {
        'items': [
          {'id': 'demo-1', 'title': '示例书', 'kind': 'reading'},
          {'id': 'demo-2', 'title': '示例片', 'kind': 'watching'},
        ],
      }),
    ) as Map;
    expect(res['insertedItems'], 2);
    final again = ok(
      await data.call('media_log', 'seedExamples', {
        'items': [
          {'id': 'demo-3', 'title': '再种'},
        ],
      }),
    ) as Map;
    expect(again['insertedItems'], 0);
    expect(
      ((ok(await data.get('media_log', 'getSnapshot')) as Map)['items'] as List)
          .length,
      2,
    );
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await fixture('media_log/items.json', {'items': 'broken'});
    expect(
      (await data.call('media_log', 'create', {'id': 'x', 'title': 't'}))[
          'code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.get('media_log', 'getSnapshot'))['code'],
      'CORRUPT_DATA',
    );
    expect((await data.get('media_log', 'getStats'))['code'], 'CORRUPT_DATA');
    await fixture('media_log/items.json', {
      'items': [
        {'id': 123, 'title': 'id 非字符串'},
      ],
    });
    expect(
      (await data.call('media_log', 'update', {'id': '123', 'title': 'x'}))[
          'code'],
      'CORRUPT_DATA',
    );
    await fixture('media_log/ui_settings.json', 'broken');
    expect(
      (await data.call('media_log', 'updateSettings', {'viewMode': 'grid'}))[
          'code'],
      'CORRUPT_DATA',
    );
    expect(
      jsonDecode(
        await File(root.path + '/media_log/items.json').readAsString(),
      ),
      {
        'items': [
          {'id': 123, 'title': 'id 非字符串'},
        ],
      },
    );
    expect(
      await File(root.path + '/media_log/migration_v1_backup.json').exists(),
      false,
    );
  });
}
