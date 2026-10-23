import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('goods_sdk_');
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

  Future<dynamic> readFixture(String path) async =>
      jsonDecode(await File(root.path + '/' + path).readAsString());

  // 客户端真实布局：索引 + 每仓库明细（物品内嵌，子物品嵌套）
  Future<void> seedTwoWarehouses() async {
    await fixture('goods/warehouses.json', {'warehouses': ['w1', 'w2']});
    await fixture('goods/warehouse/w1.json', {
      'warehouse': {
        'id': 'w1',
        'title': '客厅',
        'iconData': 58136,
        'iconColor': 4280391411,
        'items': [
          {
            'id': 'i1',
            'title': '笔记本电脑',
            'quantity': 1,
            'tags': ['电子产品'],
            'notes': '工作用',
            'subItems': [
              {'id': 's1', 'title': '电源适配器', 'subItems': <dynamic>[]},
            ],
          },
        ],
      },
    });
    await fixture('goods/warehouse/w2.json', {
      'warehouse': {'id': 'w2', 'title': '卧室', 'items': <dynamic>[]},
    });
  }

  test('warehouse + item CRUD on embedded warehouse/{id}.json layout', () async {
    await seedTwoWarehouses();

    // getWarehouses：聚合索引内所有仓库（含内嵌物品）
    final warehouses = ok(await data.get('goods', 'getWarehouses')) as Map;
    expect((warehouses['data'] as List).length, 2);
    final w1 =
        (warehouses['data'] as List).firstWhere((w) => w['id'] == 'w1')
            as Map;
    expect((w1['items'] as List).length, 1);

    // getList：递归展平（含子物品）并附加 warehouseId
    final items = ok(await data.get('goods', 'getList')) as Map;
    final flat = items['data'] as List;
    expect(flat.length, 2); // i1 + 子物品 s1
    expect(flat.firstWhere((i) => i['id'] == 's1')['warehouseId'], 'w1');

    // create：落到所属仓库 items 顶层；name/description 归一为 title/notes
    final created = ok(
      await data.call('goods', 'create', {
        'id': 'i2',
        'name': '电视',
        'description': '客厅电视',
        'warehouseId': 'w1',
        'tags': ['家电'],
      }),
    ) as Map;
    expect(created['title'], '电视');
    expect(created['notes'], '客厅电视');
    expect(created.containsKey('name'), false);
    expect(created['quantity'], 1);
    final stored = await readFixture('goods/warehouse/w1.json') as Map;
    final storedItems =
        ((stored['warehouse'] as Map)['items'] as List).cast<Map>();
    expect(storedItems.any((i) => i['id'] == 'i2'), true);
    expect(
      await File(root.path + '/goods/items.json').exists(),
      false, // 旧格式文件不应再产生
    );

    // quantity 显式 null 保留（客户端 toJson 语义）
    final nullQty = ok(
      await data.call('goods', 'create', {
        'id': 'i3',
        'title': '赠品',
        'quantity': null,
        'warehouseId': 'w2',
      }),
    ) as Map;
    expect(nullQty['quantity'], null);

    // create 参数校验
    expect(
      (await data.call('goods', 'create', {'id': 'x', 'title': 't'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('goods', 'create', {
        'id': 'x',
        'title': 't',
        'warehouseId': 'nope',
      }))['code'],
      'NOT_FOUND',
    );
    expect(
      (await data.call('goods', 'create', {'id': 'x', 'warehouseId': 'w1'}))[
          'code'],
      'INVALID_PARAMS',
    );

    // update：顶层物品 merge
    final updated = ok(
      await data.call('goods', 'update', {'id': 'i1', 'title': '手提电脑'}),
    ) as Map;
    expect(updated['title'], '手提电脑');
    expect(updated['notes'], '工作用'); // 未传字段保留
    expect(updated['warehouseId'], 'w1');
    expect(
      (await data.call('goods', 'update', {'id': 'nope', 'title': 'x'}))[
          'code'],
      'NOT_FOUND',
    );

    // update：子物品递归替换，仍嵌套在父物品 subItems 内
    ok(
      await data.call('goods', 'update', {
        'id': 's1',
        'title': '充电器',
        'notes': '原装',
      }),
    );
    final afterSubUpdate = await readFixture('goods/warehouse/w1.json') as Map;
    final parent =
        ((afterSubUpdate['warehouse'] as Map)['items'] as List)
            .cast<Map>()
            .firstWhere((i) => i['id'] == 'i1');
    final sub = (parent['subItems'] as List).cast<Map>().first;
    expect(sub['title'], '充电器');

    // getById
    expect(ok(await data.get('goods', 'getById', {'id': 's1'}))['title'],
        '充电器');
    expect(
      (await data.get('goods', 'getById', {'id': 'nope'}))['code'],
      'NOT_FOUND',
    );

    // delete：子物品递归删除
    final removed = ok(await data.call('goods', 'delete', {'id': 's1'})) as Map;
    expect(removed['warehouseId'], 'w1');
    final afterSubDelete = await readFixture('goods/warehouse/w1.json') as Map;
    final parentAfter =
        ((afterSubDelete['warehouse'] as Map)['items'] as List)
            .cast<Map>()
            .firstWhere((i) => i['id'] == 'i1');
    expect((parentAfter['subItems'] as List).isEmpty, true);

    // delete：顶层物品
    ok(await data.call('goods', 'delete', {'id': 'i2'}));
    final w1Items = ((await readFixture('goods/warehouse/w1.json')
        as Map)['warehouse'] as Map)['items'] as List;
    expect(w1Items.any((i) => i['id'] == 'i2'), false);
    expect(w1Items.length, 1);
    expect(
      (await data.call('goods', 'delete', {'id': 'nope'}))['code'],
      'NOT_FOUND',
    );

    // search：title/notes 关键词 + 仓库过滤
    final searched = ok(
      await data.get('goods', 'search', {'keyword': '手提'}),
    ) as Map;
    expect((searched['data'] as List).map((i) => i['id']), ['i1']);
    final scoped = ok(
      await data.get('goods', 'search', {'keyword': '赠品'}),
    ) as Map;
    expect((scoped['data'] as List).length, 1);
    expect((scoped['data'] as List).first['warehouseId'], 'w2');
  });

  test('updateWarehouse / clearWarehouse / deleteWarehouse / createWarehouse',
      () async {
    await seedTwoWarehouses();

    // updateWarehouse：patch 元数据，不触碰内嵌物品
    final patched = ok(
      await data.call('goods', 'updateWarehouse', {
        'id': 'w1',
        'name': '客厅储物',
        'iconColor': 4280391411,
      }),
    ) as Map;
    expect(patched['title'], '客厅储物'); // name 归一为 title
    expect((patched['items'] as List).length, 1);
    expect(
      (await data.call('goods', 'updateWarehouse', {'id': 'nope'}))['code'],
      'NOT_FOUND',
    );

    // createWarehouse：写索引 + 明细；title 兜底；重复 id 冲突
    final created = ok(
      await data.call('goods', 'createWarehouse', {'id': 'w3', 'title': '书房'}),
    ) as Map;
    expect(created['items'], <dynamic>[]);
    expect((await readFixture('goods/warehouses.json') as Map)['warehouses'],
        ['w1', 'w2', 'w3']);
    expect(
      (await data.call('goods', 'createWarehouse', {
        'id': 'w3',
        'title': '重复',
      }))['code'],
      'CONFLICT',
    );
    final noTitle = ok(
      await data.call('goods', 'createWarehouse', {'id': 'w4'}),
    ) as Map;
    expect(noTitle['title'], '未命名仓库');

    // clearWarehouse：物品清空、元数据保留
    ok(await data.call('goods', 'clearWarehouse', {'id': 'w1'}));
    final cleared =
        (await readFixture('goods/warehouse/w1.json') as Map)['warehouse'] as Map;
    expect(cleared['items'], <dynamic>[]);
    expect(cleared['title'], '客厅储物');
    expect(
      (await data.call('goods', 'clearWarehouse', {'id': 'nope'}))['code'],
      'NOT_FOUND',
    );

    // deleteWarehouse：索引移除 + 明细文件删除
    ok(await data.call('goods', 'deleteWarehouse', {'id': 'w2'}));
    expect((await readFixture('goods/warehouses.json') as Map)['warehouses'],
        ['w1', 'w3', 'w4']);
    expect(await File(root.path + '/goods/warehouse/w2.json').exists(), false);
    expect(
      (await data.call('goods', 'deleteWarehouse', {'id': 'w2'}))['code'],
      'NOT_FOUND',
    );
  });

  test('preferences get/update matches client preferences.json usage', () async {
    expect(ok(await data.get('goods', 'getPreferences')), {});

    final prefs = ok(
      await data.call('goods', 'updatePreferences', {
        'warehouseSortPreferences': {'w1': 'name'},
      }),
    ) as Map;
    expect(prefs['warehouseSortPreferences'], {'w1': 'name'});

    // 浅 merge：整键覆盖 + 其他键保留
    ok(
      await data.call('goods', 'updatePreferences', {
        'warehouseSortPreferences': {'w1': 'date', 'w2': 'none'},
        'listView': 'grid',
      }),
    );
    final merged = ok(await data.get('goods', 'getPreferences')) as Map;
    expect(merged['warehouseSortPreferences'], {'w1': 'date', 'w2': 'none'});
    expect(merged['listView'], 'grid');
    expect(await readFixture('goods/preferences.json'), merged);
  });

  test('corrupt data returns CORRUPT_DATA and files stay untouched', () async {
    await seedTwoWarehouses();

    // 坏索引：聚合查询全部拒绝
    await fixture('goods/warehouses.json', {'warehouses': 'broken'});
    expect(
      (await data.get('goods', 'getWarehouses'))['code'],
      'CORRUPT_DATA',
    );
    expect((await data.get('goods', 'getList'))['code'], 'CORRUPT_DATA');

    await fixture('goods/warehouses.json', {'warehouses': ['w1', 42]});
    expect(
      (await data.call('goods', 'createWarehouse', {'title': 'x'}))['code'],
      'CORRUPT_DATA',
    );

    // 坏明细：读写均拒绝
    await fixture('goods/warehouses.json', {'warehouses': ['w1', 'w2']});
    await fixture('goods/warehouse/w1.json', {'warehouse': 'broken'});
    expect(
      (await data.get('goods', 'getWarehouses'))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('goods', 'updateWarehouse', {'id': 'w1'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('goods', 'create', {
        'id': 'x',
        'title': 't',
        'warehouseId': 'w1',
      }))['code'],
      'CORRUPT_DATA',
    );

    await fixture('goods/warehouse/w1.json', {
      'warehouse': {
        'id': 'w1',
        'items': [{'id': 'i1', 'title': 'x'}, 'broken'],
      },
    });
    expect((await data.get('goods', 'getList'))['code'], 'CORRUPT_DATA');
    expect(
      (await data.call('goods', 'update', {'id': 'i1', 'title': 'y'}))['code'],
      'CORRUPT_DATA',
    );

    await fixture('goods/preferences.json', 'broken');
    expect(
      (await data.get('goods', 'getPreferences'))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('goods', 'updatePreferences', {'a': 1}))['code'],
      'CORRUPT_DATA',
    );

    // 损坏文件保持原样，未被改写
    expect(await readFixture('goods/preferences.json'), 'broken');
    expect(await readFixture('goods/warehouse/w1.json'), {
      'warehouse': {
        'id': 'w1',
        'items': [{'id': 'i1', 'title': 'x'}, 'broken'],
      },
    });
  });
}
