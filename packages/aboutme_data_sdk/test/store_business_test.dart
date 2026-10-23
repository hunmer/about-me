import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('store_sdk_');
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

  Future<dynamic> raw(String path) async =>
      jsonDecode(await File(root.path + '/' + path).readAsString());

  Map<String, dynamic> product(String id, {int stock = 3, int price = 10}) => {
        'id': id,
        'name': '商品$id',
        'description': '描述',
        'image': null,
        'category': null,
        'stock': stock,
        'price': price,
        'exchange_start': '2020-01-01T00:00:00.000Z',
        'exchange_end': '2099-01-01T00:00:00.000Z',
        'use_duration': 7,
      };

  test('five collections CRUD, archive/restore and first-write backup', () async {
    // 旧客户端文件格式直接可读
    await fixture('store/products.json', {
      'products': [product('p1')],
    });
    await fixture('store/points.json', {
      'value': 100,
      'logs': [
        {
          'id': 'log1',
          'type': '获得',
          'value': 100,
          'reason': '初始',
          'timestamp': '2026-01-01T00:00:00.000Z',
        },
      ],
    });
    await fixture('store/user_items.json', {
      'items': [
        {
          'id': 'ui1',
          'product_id': 'p1',
          'remaining': 2,
          'expire_date': '2099-01-01T00:00:00.000Z',
          'purchase_date': '2026-01-01T00:00:00.000Z',
          'purchase_price': 10,
        },
      ],
    });

    // snapshot：五集合一次取全
    final snapshot = ok(await data.get('store', 'getSnapshot')) as Map;
    expect((snapshot['products'] as List).length, 1);
    expect(snapshot['value'], 100);
    expect((snapshot['logs'] as List).length, 1);
    expect((snapshot['userItems'] as List).length, 1);
    expect((snapshot['usedItems'] as List).isEmpty, true);
    expect((snapshot['archivedProducts'] as List).isEmpty, true);

    // 商品 CRUD
    final created = ok(await data.call('store', 'createProduct', {
      'id': 'p2',
      'name': '新品',
      'stock': 5,
      'price': 20,
    })) as Map;
    expect(created['stock'], 5);
    expect(created['exchange_end'], isNotNull);
    expect(
      (await data.call('store', 'createProduct', {'id': 'p2', 'name': '重复'}))['code'],
      'CONFLICT',
    );
    expect(
      (await data.call('store', 'createProduct', {'id': 'p3'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      ok(await data.call('store', 'updateProduct', {'id': 'p2', 'price': 15}))['price'],
      15,
    );
    expect(
      (await data.call('store', 'updateProduct', {'id': 'nope', 'price': 1}))['code'],
      'NOT_FOUND',
    );
    expect(
      ((ok(await data.get('store', 'getProducts')) as Map)['data'] as List).length,
      2,
    );
    ok(await data.call('store', 'deleteProduct', {'id': 'p2'}));
    expect(
      ((ok(await data.get('store', 'getProducts')) as Map)['data'] as List).length,
      1,
    );

    // 归档/恢复：行在两份文件间移动
    final archived = ok(await data.call('store', 'archiveProduct', {'id': 'p1'})) as Map;
    expect(archived['id'], 'p1');
    expect(
      ((ok(await data.get('store', 'getArchivedProducts')) as Map)['data'] as List)
          .length,
      1,
    );
    expect(
      ((ok(await data.get('store', 'getProducts')) as Map)['data'] as List).isEmpty,
      true,
    );
    ok(await data.call('store', 'restoreProduct', {'id': 'p1'}));
    expect(
      ((ok(await data.get('store', 'getProducts')) as Map)['data'] as List).length,
      1,
    );

    // 积分
    final points = ok(await data.get('store', 'getPoints')) as Map;
    expect(points['value'], 100);
    ok(await data.call('store', 'addPoints', {'value': -30, 'reason': '手动扣除'}));
    expect(ok(await data.get('store', 'getPoints'))['value'], 70);
    ok(await data.call('store', 'clearPointsLogs'));
    expect((ok(await data.get('store', 'getPoints'))['logs'] as List).isEmpty, true);
    expect(ok(await data.get('store', 'getPoints'))['value'], 70);
    expect(
      (await data.call('store', 'addPoints', {'value': 1}))['code'],
      'INVALID_PARAMS',
    );

    // 用户物品
    expect(
      ((ok(await data.get('store', 'getUserItems')) as Map)['data'] as List).length,
      1,
    );
    expect(
      ((ok(await data.get('store', 'getUserItems', {'productId': 'p1'})) as Map)['data']
              as List)
          .length,
      1,
    );
    expect(
      ((ok(await data.get('store', 'getUserItems', {'productId': 'zz'})) as Map)['data']
              as List)
          .isEmpty,
      true,
    );
    ok(await data.call('store', 'deleteUserItem', {'id': 'ui1'}));
    expect(
      ((ok(await data.get('store', 'getUserItems')) as Map)['data'] as List).isEmpty,
      true,
    );

    // 整表保存（排序等 UI 路径）
    ok(await data.call('store', 'saveProducts', {
      'products': [product('p9')],
    }));
    expect(
      ((ok(await data.get('store', 'getProducts')) as Map)['data'] as List).length,
      1,
    );
    ok(await data.call('store', 'saveUsedItems', {
      'items': [
        {
          'id': 'u1',
          'product_id': 'p9',
          'use_date': '2026-02-01T00:00:00.000Z',
          'product_snapshot': product('p9'),
        },
      ],
    }));
    expect(
      ((ok(await data.get('store', 'getUsedItems')) as Map)['data'] as List).length,
      1,
    );

    // 首写备份：保留原始主集合内容
    final backup = await raw('store/migration_v1_backup.json') as Map;
    expect(backup['schemaVersion'], 1);
    expect((backup['products'] as Map)['products'].length, 1);
    expect(backup['points']['value'], 100);
    expect((backup['user_items'] as Map)['items'].length, 1);
  });

  test('purchase/redeem atomic consistency and rollback on failures', () async {
    await fixture('store/products.json', {
      'products': [
        product('p1', stock: 2, price: 10),
        product('nostock', stock: 0, price: 1),
        product('closed', stock: 5, price: 1, ),
      ],
    });
    // closed：兑换窗口已过
    await fixture('store/points.json', {
      'value': 25,
      'logs': [],
    });
    final closed = await raw('store/products.json') as Map;
    ((closed['products'] as List)[2] as Map)['exchange_end'] =
        '2020-01-01T00:00:00.000Z';
    await File(root.path + '/store/products.json')
        .writeAsString(jsonEncode(closed));

    // 成功：库存-1、积分-价格、流水+1、用户物品+1，一次提交
    final result = ok(await data.call('store', 'purchase', {
      'productId': 'p1',
      'clientMutationId': 'buy-1',
    })) as Map;
    expect((result['product'] as Map)['stock'], 1);
    expect(result['value'], 15);
    expect((result['log'] as Map)['type'], '消耗');
    expect((result['userItem'] as Map)['product_id'], 'p1');
    expect((await raw('store/products.json'))['products'][0]['stock'], 1);
    expect((await raw('store/points.json'))['value'], 15);
    expect(((await raw('store/points.json'))['logs'] as List).length, 1);
    expect(((await raw('store/user_items.json'))['items'] as List).length, 1);

    // redeem 为同一动作的别名
    final alias = ok(await data.call('store', 'redeem', {'productId': 'p1'})) as Map;
    expect(alias['value'], 5);
    expect((await raw('store/products.json'))['products'][0]['stock'], 0);

    final productsBefore = await File(root.path + '/store/products.json').readAsString();
    final pointsBefore = await File(root.path + '/store/points.json').readAsString();
    final itemsBefore =
        await File(root.path + '/store/user_items.json').readAsString();

    // 库存不足：业务失败，全部不写入
    final noStock =
        await data.call('store', 'purchase', {'productId': 'p1'});
    expect(noStock['success'], false);
    expect(noStock['code'], 'INVALID_PARAMS');
    // 积分不足（5 < 10）
    final noPoints = await data.call('store', 'purchase', {
      'productId': 'nostock',
    });
    expect(noPoints['success'], false);
    // 不在兑换时间内
    final closedWindow = await data.call('store', 'purchase', {
      'productId': 'closed',
    });
    expect(closedWindow['success'], false);
    expect(closedWindow['code'], 'INVALID_PARAMS');
    // 商品不存在
    expect(
      (await data.call('store', 'purchase', {'productId': 'ghost'}))['code'],
      'NOT_FOUND',
    );
    expect(
      (await data.call('store', 'purchase', {}))['code'],
      'INVALID_PARAMS',
    );

    expect(await File(root.path + '/store/products.json').readAsString(), productsBefore);
    expect(await File(root.path + '/store/points.json').readAsString(), pointsBefore);
    expect(await File(root.path + '/store/user_items.json').readAsString(), itemsBefore);
  });

  test('addPoints idempotency: retry and concurrent instances add once', () async {
    // 同一 mutationId 重试：返回原结果，只加一次
    final first = ok(await data.call('store', 'addPoints', {
      'value': 5,
      'reason': '完成任务奖励',
      'clientMutationId': 'award-1',
    })) as Map;
    final retry = ok(await data.call('store', 'addPoints', {
      'value': 5,
      'reason': '完成任务奖励',
      'clientMutationId': 'award-1',
    })) as Map;
    expect(retry['value'], first['value']);
    expect((retry['log'] as Map)['id'], (first['log'] as Map)['id']);
    final points = ok(await data.get('store', 'getPoints')) as Map;
    expect(points['value'], 5);
    expect((points['logs'] as List).length, 1);

    // 同 mutationId 不同参数：CONFLICT
    expect(
      (await data.call('store', 'addPoints', {
        'value': 9,
        'reason': '完成任务奖励',
        'clientMutationId': 'award-1',
      }))['code'],
      'CONFLICT',
    );

    // 两实例并发同 mutationId：只加一次
    final second = AboutmeData.local(root.path);
    try {
      final results = await Future.wait([
        data.call('store', 'addPoints', {
          'value': 7,
          'reason': '签到完成奖励',
          'clientMutationId': 'award-2',
        }),
        second.call('store', 'addPoints', {
          'value': 7,
          'reason': '签到完成奖励',
          'clientMutationId': 'award-2',
        }),
      ]);
      expect(results.every((r) => r['success'] == true), true);
      final ids = results.map((r) => (r['data'] as Map)['log']['id']).toSet();
      expect(ids.length, 1);
      final after = ok(await second.get('store', 'getPoints')) as Map;
      expect(after['value'], 12);
      expect((after['logs'] as List).length, 2);
    } finally {
      await second.dispose();
    }
  });

  test('useItem records used history and consumes remaining atomically', () async {
    await fixture('store/products.json', {
      'products': [product('p1')],
    });
    await fixture('store/user_items.json', {
      'items': [
        {
          'id': 'ui1',
          'product_id': 'p1',
          'remaining': 2,
          'expire_date': '2099-01-01T00:00:00.000Z',
          'purchase_date': '2026-01-01T00:00:00.000Z',
          'purchase_price': 10,
        },
        {
          'id': 'ui2',
          'product_id': 'p1',
          'remaining': 1,
          'expire_date': '2099-01-01T00:00:00.000Z',
          'purchase_date': '2026-01-01T00:00:00.000Z',
          'purchase_price': 10,
        },
        {
          'id': 'expired',
          'product_id': 'p1',
          'remaining': 1,
          'expire_date': '2020-01-01T00:00:00.000Z',
          'purchase_date': '2019-01-01T00:00:00.000Z',
          'purchase_price': 10,
        },
      ],
    });

    // 使用一次：remaining-1，写使用记录（冻结商品快照）
    final used = ok(await data.call('store', 'useItem', {'id': 'ui1'})) as Map;
    expect((used['usedItem'] as Map)['id'], 'ui1');
    expect(((used['usedItem'] as Map)['product_snapshot'] as Map)['id'], 'p1');
    expect((used['userItem'] as Map)['remaining'], 1);
    expect(
      ((ok(await data.get('store', 'getUsedItems')) as Map)['data'] as List).length,
      1,
    );

    // 用尽：从用户物品移除，保留使用记录
    final consumed = ok(await data.call('store', 'useItem', {'id': 'ui2'})) as Map;
    expect(consumed['userItem'], isNull);
    final items = ((ok(await data.get('store', 'getUserItems')) as Map)['data'] as List);
    expect(items.length, 2); // ui1 + expired
    expect(
      ((ok(await data.get('store', 'getUsedItems')) as Map)['data'] as List).length,
      2,
    );

    // 过期物品：业务失败，不写任何文件
    final before = await File(root.path + '/store/user_items.json').readAsString();
    final expired = await data.call('store', 'useItem', {'id': 'expired'});
    expect(expired['success'], false);
    expect(expired['code'], 'INVALID_PARAMS');
    expect(await File(root.path + '/store/user_items.json').readAsString(), before);
    expect(
      (await data.call('store', 'useItem', {'id': 'ghost'}))['code'],
      'NOT_FOUND',
    );
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await fixture('store/products.json', {'products': 'broken'});
    expect(
      (await data.call('store', 'createProduct', {'id': 'x', 'name': 'n'}))['code'],
      'CORRUPT_DATA',
    );
    expect((await data.get('store', 'getSnapshot'))['code'], 'CORRUPT_DATA');
    await fixture('store/points.json', {'value': 'abc', 'logs': []});
    expect((await data.get('store', 'getPoints'))['code'], 'CORRUPT_DATA');
    expect(
      (await data.call('store', 'addPoints', {'value': 1, 'reason': 'r'}))['code'],
      'CORRUPT_DATA',
    );
    await fixture('store/user_items.json', {'items': [{'id': 1}]});
    expect((await data.get('store', 'getUserItems'))['code'], 'CORRUPT_DATA');
    await fixture('store/used_items.json', 'broken');
    expect((await data.get('store', 'getUsedItems'))['code'], 'CORRUPT_DATA');
    // 损坏读失败不产生备份与写放大
    expect(
      await File(root.path + '/store/migration_v1_backup.json').exists(),
      false,
    );
    expect(await raw('store/products.json'), {'products': 'broken'});
  });
}
