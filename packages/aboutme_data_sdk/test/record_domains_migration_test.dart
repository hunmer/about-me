import 'dart:io';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('record_domains_');
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

  test('todo 首次写入前迁移全量实体，二进制幂等不重复', () async {
    await value(
      await data.call('todo', 'create', {
        'id': 't1',
        'title': 'a',
        'subtasks': [
          {'id': 's1', 'title': 'x'},
        ],
      }),
    );
    final report = value(await data.call('todo', 'getMigrationReport')) as Map;
    expect(report['verified'], isTrue);
    final ids = (report['entityIds']['tasks'] as List).cast<String>();
    expect(ids, containsAll(['t1']));
    expect((report['entityIds']['completedTasks'] as List).isEmpty, isTrue);
    await value(
      await data.call('todo', 'setStatus', {'id': 't1', 'status': 2}),
    );
    final again = value(await data.call('todo', 'getMigrationReport')) as Map;
    expect(again['backupChecksum'], report['backupChecksum']);
    final export = value(await data.call('todo', 'exportData')) as Map;
    expect(export['entityIds']['tasks'], containsAll(['t1']));
  });

  test('tracker 孤儿 record 拒绝迁移且不写入清单', () async {
    await value(
      await data.call('tracker', 'create', {
        'id': 'g1',
        'name': 'goal',
        'group': 'g', 'targetValue': 10,
      }),
    );
    await value(
      await data.call('tracker', 'addRecord', {
        'id': 'r1',
        'goalId': 'missing',
        'value': 1,
        'date': DateTime.now().toIso8601String(),
      }),
    );
    final failed = await data.call('tracker', 'getMigrationReport');
    expect(failed['success'], isFalse);
    expect(failed['code'], 'CORRUPT_DATA');
  });

  test('合法 tracker 数据迁移后 restoreBackup 可恢复当前快照', () async {
    await value(
      await data.call('tracker', 'create', {
        'id': 'g1',
        'name': 'goal',
        'group': 'g', 'targetValue': 10,
      }),
    );
    await value(
      await data.call('tracker', 'addRecord', {
        'id': 'r1',
        'goalId': 'g1',
        'value': 3,
        'date': DateTime.now().toIso8601String(),
      }),
    );
    value(await data.call('tracker', 'getMigrationReport', {}));
    final before = value(await data.call('tracker', 'getSnapshot')) as Map;
    await value(
      await data.call('tracker', 'update', {'id': 'g1', 'name': 'changed'}),
    );
    final restored =
        value(
              await data.call('tracker', 'restoreBackup', {
                'confirmRestore': true,
              }),
            )
            as Map;
    expect(restored['restored'], isTrue);
    expect(restored['entityIds']['goals'], contains('g1'));
    final after = value(await data.call('tracker', 'getSnapshot')) as Map;
    expect(
      (after['goals'] as List).first['name'],
      (before['goals'] as List).first['name'],
    );
  });
}
