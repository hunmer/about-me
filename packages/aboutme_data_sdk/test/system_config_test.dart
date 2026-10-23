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
}
