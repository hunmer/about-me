import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bill_sdk_');
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

  Map<String, dynamic> subscriptionParams({
    String? id,
    String name = '视频会员',
    num totalAmount = 30.0,
    int days = 30,
  }) => <String, dynamic>{
    if (id != null) 'id': id,
    'name': name,
    'totalAmount': totalAmount,
    'days': days,
    'dailyAmount': totalAmount / days,
    'category': '订阅',
    'startDate': '2026-10-01T00:00:00.000',
    'endDate': null,
    'isActive': true,
    'createdAt': '2026-10-01T08:00:00.000',
    'note': '连续包月',
    'icon': 58155,
    'iconColor': 4280391411,
  };

  test('订阅 CRUD 与账户共存', () async {
    // 预置旧客户端账户数据（JSON 字符串数组格式，与订阅数据共存）
    await fixture('bill/accounts.json', {
      'accounts': [
        jsonEncode({
          'id': 'a1',
          'title': '现金',
          'iconCodePoint': 59569,
          'backgroundColor': 4280391411,
          'totalAmount': 0,
          'bills': [],
        }),
      ],
    });

    // 创建订阅（字段与客户端 Subscription.toJson 一致）
    final created = ok(
      await data.call('bill', 'createSubscription', subscriptionParams(id: 's1')),
    ) as Map;
    expect(created['id'], 's1');
    expect(created['name'], '视频会员');
    expect(created['dailyAmount'], 1.0);
    expect(created['updatedAt'], isA<String>());

    // 重复 ID → CONFLICT；缺字段/非法字段 → INVALID_PARAMS
    expect(
      (await data.call(
        'bill',
        'createSubscription',
        subscriptionParams(id: 's1'),
      ))['code'],
      'CONFLICT',
    );
    expect(
      (await data.call(
        'bill',
        'createSubscription',
        subscriptionParams(name: '  '),
      ))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call(
        'bill',
        'createSubscription',
        subscriptionParams(days: -1),
      ))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('bill', 'createSubscription', {'name': 'x', 'days': 1}))['code'],
      'INVALID_PARAMS',
    );

    // 未传 id 自动生成
    final auto = ok(
      await data.call('bill', 'createSubscription', subscriptionParams(name: '音乐会员')),
    ) as Map;
    expect((auto['id'] as String).isNotEmpty, true);

    // 列表查询
    final list = ok(await data.get('bill', 'getSubscriptions')) as Map;
    expect(list['total'], 2);
    expect((list['data'] as List).length, 2);

    // 更新（终止订阅语义：isActive=false，其余字段合并保留）
    final updated = ok(
      await data.call('bill', 'updateSubscription', {'id': 's1', 'isActive': false}),
    ) as Map;
    expect(updated['isActive'], false);
    expect(updated['name'], '视频会员');
    expect(
      (await data.call('bill', 'updateSubscription', {'id': 'nope'}))['code'],
      'NOT_FOUND',
    );

    // 删除；重复删除 → NOT_FOUND
    expect(ok(await data.call('bill', 'deleteSubscription', {'id': 's1'})), {
      'id': 's1',
    });
    expect(
      (await data.call('bill', 'deleteSubscription', {'id': 's1'}))['code'],
      'NOT_FOUND',
    );
    expect((ok(await data.get('bill', 'getSubscriptions')) as Map)['total'], 1);

    // 订阅操作不影响账户数据（共存）
    final storedAccounts =
        jsonDecode(await File(root.path + '/bill/accounts.json').readAsString())
            as Map;
    expect((storedAccounts['accounts'] as List).length, 1);
    final stats = ok(await data.get('bill', 'getStats')) as Map;
    expect(stats['accountCount'], 1);

    // 订阅文件为对象数组格式
    final storedSubscriptions =
        jsonDecode(
          await File(root.path + '/bill/subscriptions.json').readAsString(),
        ) as Map;
    final rows = storedSubscriptions['subscriptions'] as List;
    expect(rows.length, 1);
    expect(rows.first, isA<Map>());
    expect((rows.first as Map)['name'], '音乐会员');
  });

  test('账户 JSON 字符串格式兼容往返（getAccountsWithBills + saveAccounts）', () async {
    // 旧客户端格式：accounts 为 JSON 编码字符串数组
    await fixture('bill/accounts.json', {
      'accounts': [
        jsonEncode({
          'id': 'a1',
          'title': '现金',
          'iconCodePoint': 59569,
          'iconFontFamily': 'MaterialIcons',
          'backgroundColor': 4280391411,
          'totalAmount': -50.5,
          'bills': [
            {
              'id': 'b1',
              'title': '午餐',
              'amount': -50.5,
              'accountId': 'a1',
              'category': '餐饮',
              'date': '2026-10-20T12:00:00.000',
            },
          ],
        }),
      ],
    });

    // 整表读取：返回解码后的完整账户（含内嵌账单）
    final raw = ok(await data.get('bill', 'getAccountsWithBills')) as Map;
    expect(raw['total'], 1);
    final accounts = raw['data'] as List;
    final a1 = accounts.first as Map;
    expect(a1['title'], '现金');
    expect((a1['bills'] as List).length, 1);

    // 客户端全量回写（Map 数组）→ 落盘仍是 JSON 字符串数组格式
    a1['title'] = '现金钱包';
    expect(ok(await data.call('bill', 'saveAccounts', {'accounts': accounts})), {
      'count': 1,
    });
    final stored =
        jsonDecode(await File(root.path + '/bill/accounts.json').readAsString())
            as Map;
    final storedList = stored['accounts'] as List;
    expect(storedList.length, 1);
    expect(storedList.first, isA<String>());
    final decoded = jsonDecode(storedList.first as String) as Map;
    expect(decoded['title'], '现金钱包');
    expect((decoded['bills'] as List).length, 1);
    expect(decoded['totalAmount'], -50.5);

    // 再读一次，数据往返一致
    final again =
        (ok(await data.get('bill', 'getAccountsWithBills')) as Map)['data'] as List;
    expect((again.first as Map)['title'], '现金钱包');
    expect(((again.first as Map)['bills'] as List).length, 1);

    // 非法输入被拒绝
    expect(
      (await data.call('bill', 'saveAccounts', {'accounts': 'x'}))['code'],
      'INVALID_PARAMS',
    );
    expect(
      (await data.call('bill', 'saveAccounts', {'accounts': [123]}))['code'],
      'INVALID_PARAMS',
    );
  });

  test('损坏数据返回 CORRUPT_DATA 且文件不被改写', () async {
    await fixture('bill/subscriptions.json', {'subscriptions': 'broken'});
    expect((await data.get('bill', 'getSubscriptions'))['code'], 'CORRUPT_DATA');
    expect(
      (await data.call('bill', 'createSubscription', subscriptionParams()))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('bill', 'updateSubscription', {'id': 's1', 'name': 'x'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      (await data.call('bill', 'deleteSubscription', {'id': 's1'}))['code'],
      'CORRUPT_DATA',
    );
    expect(
      jsonDecode(
        await File(root.path + '/bill/subscriptions.json').readAsString(),
      ),
      {'subscriptions': 'broken'},
    );

    // 行内非对象同样视为损坏
    await fixture('bill/subscriptions.json', {'subscriptions': ['not-map']});
    expect((await data.get('bill', 'getSubscriptions'))['code'], 'CORRUPT_DATA');

    // 顶层非对象同样视为损坏
    await fixture('bill/subscriptions.json', 'broken');
    expect((await data.get('bill', 'getSubscriptions'))['code'], 'CORRUPT_DATA');
    expect(
      jsonDecode(
        await File(root.path + '/bill/subscriptions.json').readAsString(),
      ),
      'broken',
    );
  });
}
