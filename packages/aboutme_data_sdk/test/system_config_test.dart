import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// System 域：服务器全局系统配置（插件注册表/商店配置）。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('system_sdk_');
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

  test('注册表：缺省空对象、旧数据可读', () async {
    expect(ok(await data.get('system', 'getPluginRegistry', {})), isEmpty);

    final f = File('${root.path}/system/plugin_registry.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({
      'plugins': {
        'diary': {'version': '1.0.0', 'enabled': true},
      },
      'updatedAt': '2026-10-01',
    }));

    final registry = ok(
      await data.get('system', 'getPluginRegistry', {}),
    ) as Map;
    expect(registry['plugins']['diary']['enabled'], true);
  });

  test('商店配置：缺省空对象、合并更新、损坏拒绝', () async {
    expect(ok(await data.get('system', 'getStoreConfig', {})), isEmpty);

    // 合并更新
    final updated = ok(await data.get(
      'system',
      'updateStoreConfig',
      {'storeURL': 'https://store.example.com'},
    )) as Map;
    expect(updated['storeURL'], 'https://store.example.com');

    // 再次合并：已有键保留
    ok(await data.get('system', 'updateStoreConfig', {'lastSyncAt': 'x'}));
    final config = ok(
      await data.get('system', 'getStoreConfig', {}),
    ) as Map;
    expect(config['storeURL'], 'https://store.example.com');
    expect(config['lastSyncAt'], 'x');

    // 损坏数据拒绝且不覆盖
    await File('${root.path}/system/store_config.json')
        .writeAsString('[1,2]');
    expect(
      (await data.get('system', 'getStoreConfig', {}))['success'],
      false,
    );
    expect(
      (await data.get(
        'system',
        'updateStoreConfig',
        {'storeURL': 'y'},
      ))['success'],
      false,
    );
  });

  group('configs 设置统一通道', () {
    test('CRUD：缺省 null、写入回读、删除', () async {
      // 缺省 null（文件不存在）
      final missing = ok(
        await data.get('system', 'getConfig', {'key': 'bill/settings.json'}),
      ) as Map;
      expect(missing['value'], isNull);

      // 写对象、回读
      ok(await data.get('system', 'setConfig', {
        'key': 'bill/settings.json',
        'value': {'currency': 'CNY', 'theme': 2},
      }));
      final config = ok(
        await data.get('system', 'getConfig', {'key': 'bill/settings.json'}),
      ) as Map;
      expect(config['value']['currency'], 'CNY');

      // 顶层单文件键（webview 商场源布局，List 值）
      ok(await data.get('system', 'setConfig', {
        'key': 'webview_app_sources.json',
        'value': [
          {'id': 's1', 'url': 'https://a'},
        ],
      }));
      final sources = ok(
        await data.get(
          'system',
          'getConfig',
          {'key': 'webview_app_sources.json'},
        ),
      ) as Map;
      expect(sources['value'], isA<List>());

      // 字符串值（webview 当前源 ID 的 JSON 字符串字面量布局）
      ok(await data.get('system', 'setConfig', {
        'key': 'webview_app_source_current.json',
        'value': 'uuid-1',
      }));
      final current = ok(
        await data.get(
          'system',
          'getConfig',
          {'key': 'webview_app_source_current.json'},
        ),
      ) as Map;
      expect(current['value'], 'uuid-1');

      // 落盘路径与旧布局一致（configs/ 前缀原位）
      expect(
        File('${root.path}/configs/bill/settings.json').existsSync(),
        true,
      );

      // 删除
      final removed = ok(
        await data.get(
          'system',
          'deleteConfig',
          {'key': 'bill/settings.json'},
        ),
      ) as Map;
      expect(removed['deleted'], true);
      expect(
        File('${root.path}/configs/bill/settings.json').existsSync(),
        false,
      );
      final again = ok(
        await data.get('system', 'deleteConfig', {'key': 'bill/settings.json'}),
      ) as Map;
      expect(again['deleted'], false);
    });

    test('磁盘旧数据原地可读（零迁移兼容）', () async {
      final f = File('${root.path}/configs/app_config.json');
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({'locale': 'zh_CN', 'pluginStates': {'bill': false}}),
      );
      final config = ok(
        await data.get('system', 'getConfig', {'key': 'app_config.json'}),
      ) as Map;
      expect(config['value']['locale'], 'zh_CN');
      expect(config['value']['pluginStates']['bill'], false);
    });

    test('key 校验：空、穿越、非法字符拒绝', () async {
      for (final key in [
        '',
        '../etc/passwd',
        'a/../b.json',
        '/abs.json',
        'a\\b.json',
        'bad key.json',
      ]) {
        expect(
          (await data.get('system', 'getConfig', {'key': key}))['success'],
          false,
          reason: 'key=$key 应被拒绝',
        );
      }
      // 无扩展名存量键合法（configs/scripts_center_installed_scripts）
      expect(
        (await data.get(
          'system',
          'getConfig',
          {'key': 'scripts_center_installed_scripts'},
        ))['success'],
        true,
      );
    });

    test('封闭验收：configs/ 原始写一律 426，命令与读不受限', () async {
      // 读 API 不受限
      expect(await data.listPathKeys('configs/'), isA<List<String>>());
      expect(await data.existsPath('configs/app_config.json'), anyOf(true, false));

      // 原始写全被 LegacyWritePolicy 拦截（426/unsupported）
      Future<void> expectBlocked(Future<void> Function() write) async {
        try {
          await write();
          fail('应被封闭拦截');
        } on StorageException catch (e) {
          expect(e.statusCode, 426, reason: '$e');
        }
      }

      await expectBlocked(
        () => data.writePath('configs/app_config.json', {}),
      );
      await expectBlocked(
        () => data.writePath('configs/x/y.json', '{}'),
      );
      await expectBlocked(
        () => data.deletePath('configs/app_config.json'),
      );
      await expectBlocked(() => data.clearPathPrefix('configs'));

      // 命令通道仍可写
      ok(await data.get('system', 'setConfig', {
        'key': 'app_config.json',
        'value': {'themeMode': 'system'},
      }));
      final config = ok(
        await data.get('system', 'getConfig', {'key': 'app_config.json'}),
      ) as Map;
      expect(config['value']['themeMode'], 'system');
    });
  });

  test('迁移恢复演练：todo 旧布局迁移 → 封闭写拒绝 → 备份恢复', () async {
    // 1) 注入旧客户端布局（磁盘直写，不受封闭限制）
    final legacy = File('${root.path}/todo/tasks.json');
    await legacy.parent.create(recursive: true);
    await legacy.writeAsString(jsonEncode({
      'tasks': [
        {'id': 't1', 'title': '旧任务A', 'completed': false},
        {'id': 't2', 'title': '旧任务B', 'completed': false},
      ],
      'completedTasks': [],
    }));

    // 迁移前旧数据即可读（零搬家兼容）
    final before = (ok(await data.get('todo', 'getList', {})) as Map)['data']
        as List;
    expect(before.length, 2);

    // 2) 显式迁移清单落盘（读旧删旧通道合法）
    final manifest = ok(await data.get('todo', 'migrate', {})) as Map;
    expect(manifest['verified'], true);
    expect((manifest['entityIds']['tasks'] as List), containsAll(['t1', 't2']));

    // 域前缀原始写被拒绝（封闭验收）
    try {
      await data.writePath('todo/tasks.json', {});
      fail('todo 原始写应被拦截');
    } on StorageException catch (e) {
      expect(e.statusCode, 426);
    }

    // 3) 修改 → restoreBackup 恢复到迁移时快照
    ok(await data.get('todo', 'update', {'id': 't1', 'title': '改后标题'}));
    final changed = (ok(await data.get('todo', 'getList', {})) as Map)['data']
        as List;
    expect(
      (changed.firstWhere((t) => t['id'] == 't1') as Map)['title'],
      '改后标题',
    );

    final restored = ok(await data.get('todo', 'restoreBackup', {
      'confirmRestore': true,
    })) as Map;
    expect(restored['restored'], true);
    final after = (ok(await data.get('todo', 'getList', {})) as Map)['data']
        as List;
    expect(
      (after.firstWhere((t) => t['id'] == 't1') as Map)['title'],
      '旧任务A',
    );
    expect(after.length, 2);
  });
}
