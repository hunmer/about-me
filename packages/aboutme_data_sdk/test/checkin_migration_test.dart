import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('checkin_migration_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });
  dynamic value(Map result) {
    expect(result['success'], isTrue, reason: '$result');
    return result['data'];
  }

  Map<String, dynamic> recordParams(String date, int hour) => {
    'id': 'c1',
    'date': date,
    'startTime': '${date}T08:00:00.000',
    'endTime': '${date}T0$hour:00:00.000',
    'checkinTime': '${date}T08:30:00.000',
    'note': 'ok',
  };

  test('checkin 首次写入后迁移快照与幂等', () async {
    await value(
      await data.call('checkin', 'create', {'id': 'c1', 'name': '喝水'}),
    );
    final report = value(await data.call('checkin', 'getMigrationReport')) as Map;
    expect(report['verified'], isTrue);
    expect((report['entityIds']['items'] as List), containsAll(['c1']));

    // 写操作后清单已存在，快照不重复构建（幂等）
    final record =
        value(await data.call('checkin', 'addRecord', recordParams('2030-01-01', 9)))
            as Map;
    // 完整记录字段透传（startTime/endTime/checkinTime），供客户端 DTO 还原
    expect(record['startTime'], '2030-01-01T08:00:00.000');
    expect(record['endTime'], '2030-01-01T09:00:00.000');
    expect(record['checkinTime'], '2030-01-01T08:30:00.000');
    final again =
        value(await data.call('checkin', 'getMigrationReport')) as Map;
    expect(again['backupChecksum'], report['backupChecksum']);

    final export = value(await data.call('checkin', 'exportData')) as Map;
    expect(export['entityIds']['items'], containsAll(['c1']));
    final items = (export['files']['items.json'] as Map)['items'] as List;
    final records = (items.first as Map)['checkInRecords'] as Map;
    expect((records['2030-01-01'] as List).length, 1);
  });

  test('deleteRecord 删除记录并回滚统计', () async {
    await value(
      await data.call('checkin', 'create', {'id': 'c1', 'name': '喝水'}),
    );
    await value(
      await data.call('checkin', 'addRecord', recordParams('2030-01-01', 9)),
    );
    await value(
      await data.call('checkin', 'addRecord', recordParams('2030-01-01', 9)),
    );
    var stats = value(await data.call('checkin', 'getStats')) as Map;
    expect(stats['totalCheckins'], 2);

    // 路由路径参数（date/recordIndex）以字符串回填，handler 需正确解析
    final updated =
        value(
          await data.call('checkin', 'deleteRecord', {
            'id': 'c1',
            'date': '2030-01-01',
            'recordIndex': 1,
          }),
        )
        as Map;
    expect(((updated['checkInRecords'] as Map)['2030-01-01'] as List).length, 1);
    stats = value(await data.call('checkin', 'getStats')) as Map;
    expect(stats['totalCheckins'], 1);

    // 仍有记录时索引越界拒绝
    final bad = await data.call('checkin', 'deleteRecord', {
      'id': 'c1',
      'date': '2030-01-01',
      'recordIndex': 5,
    });
    expect(bad['success'], isFalse);
    expect(bad['code'], 'INVALID_PARAMS');

    // 删空后日期 key 移除，统计归零；此后再删该日期返回 NOT_FOUND
    await value(
      await data.call('checkin', 'deleteRecord', {
        'id': 'c1',
        'date': '2030-01-01',
        'recordIndex': 0,
      }),
    );
    final item = value(await data.call('checkin', 'getById', {'id': 'c1'})) as Map;
    expect((item['checkInRecords'] as Map).containsKey('2030-01-01'), isFalse);
    stats = value(await data.call('checkin', 'getStats')) as Map;
    expect(stats['totalCheckins'], 0);
    final empty = await data.call('checkin', 'deleteRecord', {
      'id': 'c1',
      'date': '2030-01-01',
      'recordIndex': 0,
    });
    expect(empty['success'], isFalse);
    expect(empty['code'], 'NOT_FOUND');
  });

  test('损坏数据 getMigrationReport 返回 CORRUPT_DATA', () async {
    // checkin 已封闭原始写，损坏数据用磁盘直写注入
    Future<void> inject(Map content) async {
      final f = File('${root.path}/checkin/items.json');
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(content));
    }

    // 顶层 items 集合非法（元素缺 String id）
    await inject({
      'items': [
        {'name': 'no-id'},
      ],
    });
    var failed = await data.call('checkin', 'getMigrationReport');
    expect(failed['success'], isFalse);
    expect(failed['code'], 'CORRUPT_DATA');

    // 内嵌 checkInRecords 形状损坏（应为 Map<日期, List>）
    await inject({
      'items': [
        {'id': 'a', 'name': 'x', 'checkInRecords': 'bad'},
      ],
    });
    failed = await data.call('checkin', 'getMigrationReport');
    expect(failed['success'], isFalse);
    expect(failed['code'], 'CORRUPT_DATA');
  });
}
