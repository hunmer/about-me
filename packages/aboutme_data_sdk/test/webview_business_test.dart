import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// WebView 域：settings/tabs/cards 整文件读写 + JS bridge KV。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('webview_sdk_');
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

  test('settings：缺省空对象、合并更新', () async {
    expect(ok(await data.get('webview', 'getSettings', {})), isEmpty);
    ok(await data.get(
      'webview',
      'updateSettings',
      {'homepage': 'https://example.com'},
    ));
    final settings = ok(
      await data.get('webview', 'getSettings', {}),
    ) as Map;
    expect(settings['homepage'], 'https://example.com');
  });

  test('tabs/cards：快照读写与旧数据兼容', () async {
    await fixture('webview/tabs.json', [
      {'id': 't1', 'url': 'https://a.com'},
    ]);
    await fixture('webview/cards.json', [
      {'id': 'c1', 'title': '卡片'},
    ]);

    final tabs = ok(await data.get('webview', 'getTabs', {})) as List;
    expect(tabs.first['id'], 't1');
    final cards = ok(await data.get('webview', 'getCards', {})) as List;
    expect(cards.first['title'], '卡片');

    ok(await data.get('webview', 'saveTabs', {
      'tabs': [
        {'id': 't2'},
      ],
    }));
    expect(
      (ok(await data.get('webview', 'getTabs', {})) as List).length,
      1,
    );
  });

  test('webStorage：KV 读写删、key 路径穿越拒绝', () async {
    expect(ok(await data.get('webview', 'getWebStorage', {'key': 'k1'})), isNull);

    ok(await data.get('webview', 'setWebStorage', {
      'key': 'k1',
      'value': {'counter': 3},
    }));
    expect(
      (ok(await data.get('webview', 'getWebStorage', {'key': 'k1'})) as Map)[
          'counter'],
      3,
    );

    ok(await data.get('webview', 'deleteWebStorage', {'key': 'k1'}));
    expect(
      ok(await data.get('webview', 'getWebStorage', {'key': 'k1'})),
      isNull,
    );

    // key 穿越拒绝
    expect(
      (await data.get('webview', 'getWebStorage', {
        'key': '../diary',
      }))['success'],
      false,
    );
    expect(
      (await data.get('webview', 'setWebStorage', {
        'key': 'a/b',
        'value': 1,
      }))['success'],
      false,
    );
  });
}
