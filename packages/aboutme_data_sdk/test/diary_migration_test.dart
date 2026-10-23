import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('diary_migration_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });
  Future<void> fixture(String file, dynamic value) async {
    final target = File('${root.path}/diary/$file');
    await target.parent.create(recursive: true);
    await target.writeAsString(jsonEncode(value));
  }

  dynamic value(Map<String, dynamic> result) {
    expect(result['success'], true, reason: '$result');
    return result['data'];
  }

  test('迁移备份旧格式/未知字段并修复遗漏索引；重复执行和恢复后重迁一致', () async {
    final original = {
      'date': '2026-01-01T00:00:00',
      'content': '[{"insert":"hello\\n"}]',
      'extra': {'keep': true},
    };
    await fixture('2026-01-01.json', original);
    final report = value(await data.call('diary', 'migrate')) as Map;
    expect(report['verified'], true);
    expect(report['entryCount'], 1);
    expect(report['entryIds'], ['2026-01-01']);
    final backup = File('${root.path}/sdk_migrations/diary/v1_backup.json');
    final backupText = await backup.readAsString();
    expect(jsonDecode(backupText)['files']['2026-01-01.json'], original);
    value(await data.call('diary', 'migrate'));
    expect(await backup.readAsString(), backupText);
    expect(value(await data.get('diary', 'getStats'))['totalEntries'], 1);
    value(
      await data.call('diary', 'save', {
        'date': '2026-01-02',
        'content': 'new',
      }),
    );
    final backend = LocalPluginBackend(root.path);
    final restored = await backend.execute(
      pluginId: 'diary',
      action: 'restoreMigrationBackup',
      resource: 'entries',
      isQuery: false,
      params: {},
      operation: (transaction) async {
        await restoreDiaryMigrationBackup(transaction);
        return {'success': true};
      },
    );
    expect(restored['success'], true);
    expect(
      jsonDecode(
        await File('${root.path}/diary/2026-01-01.json').readAsString(),
      ),
      original,
    );
    expect(await File('${root.path}/diary/2026-01-02.json').exists(), false);
    expect(
      await File(
        '${root.path}/sdk_migrations/diary/before_restore.json',
      ).exists(),
      true,
    );
    final again = value(await data.call('diary', 'migrate')) as Map;
    expect(again['backupChecksum'], report['backupChecksum']);
    expect(again['normalizedChecksum'], report['normalizedChecksum']);
  });
  test('迁移损坏文件不会重写原数据或创建成功标记', () async {
    await fixture('2026-01-01.json', {'date': '2026-01-01', 'content': 42});
    expect((await data.call('diary', 'migrate'))['code'], 'CORRUPT_DATA');
    expect(
      await File('${root.path}/sdk_migrations/diary/v1.json').exists(),
      false,
    );
    expect(
      jsonDecode(
        await File('${root.path}/diary/2026-01-01.json').readAsString(),
      )['content'],
      42,
    );
  });
  test('原始写/删/前缀清理同时封闭；SDK 命令与分批导入可用', () async {
    for (final operation in <Future<void> Function()>[
      () async {
        await data.writeFile('diary', 'x.json', {});
      },
      () async {
        await data.writePath('diary/x.png', 'bad');
      },
      () async { await data.writePath('DIARY/x.json', {}); },
      () async { await data.writePath('Diary./x.json', {}); },
      () async { await data.writePath('.SDK/state.json', {}); },
      () async {
        await data.deletePath('diary/x.json');
      },
      () async {
        await data.clearPathPrefix('d');
      },
      () async {
        await data.clearPathPrefix('');
      },
      () async {
        await data.writePath('sdk_migrations/diary/v1.json', {});
      },
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<StorageException>().having((e) => e.statusCode, 'status', 426),
        ),
      );
    }
    final command = {
      'schemaVersion': 1,
      'entries': [
        {'date': '2026-01-01', 'content': 'first', 'extra': true},
      ],
    };
    expect(
      value(await data.call('diary', 'importEntries', command))['created'],
      ['2026-01-01'],
    );
    expect(
      value(await data.call('diary', 'importEntries', command))['skipped'],
      ['2026-01-01'],
    );
    final exported = value(await data.get('diary', 'exportEntries')) as Map;
    expect(exported['entries'][0]['extra'], true);
    expect(exported['entries'][0]['content'], 'first');
    final invalid = await data.call('diary', 'importEntries', {
      'schemaVersion': 1,
      'entries': [
        {'date': '2026-01-02', 'content': 'valid'},
        {'date': '2026-01-03', 'content': false},
      ],
    });
    expect(invalid['code'], 'INVALID_PARAMS');
    expect(
      (await data.get('diary', 'getByDate', {'date': '2026-01-02'}))['code'],
      'NOT_FOUND',
    );
  });
}
