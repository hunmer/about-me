import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// Photo editor 域业务：编辑器打开历史（薄文件层整表读写）。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('photo_editor_sdk_');
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

  test('历史：缺省空、整表写读、清空', () async {
    expect(ok(await data.get('photo_editor', 'getHistory', {})), isEmpty);

    final saved = ok(await data.get('photo_editor', 'saveHistory', {
      'history': [
        {'ts': 2, 'url': 'asset://a1', 'name': 'b.png'},
        {'ts': 1, 'url': 'https://x/c.jpg', 'name': 'c.jpg'},
      ],
    })) as Map;
    expect(saved['count'], 2);

    final rows = ok(await data.get('photo_editor', 'getHistory', {})) as List;
    expect(rows.length, 2);
    expect(rows.first['url'], 'asset://a1');

    // 落盘布局与旧文件层一致（photo_editor/history.json 顶层 List）
    final file = File('${root.path}/photo_editor/history.json');
    expect(file.existsSync(), true);
    expect(jsonDecode(file.readAsStringSync()), isA<List>());

    ok(await data.get('photo_editor', 'clearHistory', {}));
    expect(ok(await data.get('photo_editor', 'getHistory', {})), isEmpty);
  });

  test('旧数据零迁移兼容：磁盘注入直接可读', () async {
    final f = File('${root.path}/photo_editor/history.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode([
      {'ts': 1, 'url': 'https://old/a.png', 'name': 'a.png'},
    ]));
    final rows = ok(await data.get('photo_editor', 'getHistory', {})) as List;
    expect(rows.length, 1);
    expect(rows.first['name'], 'a.png');
  });

  test('损坏拒绝、入参校验、封闭验收', () async {
    // 损坏（对象形态）拒绝
    await File('${root.path}/photo_editor/history.json')
        .parent
        .create(recursive: true);
    await File('${root.path}/photo_editor/history.json').writeAsString('{}');
    expect(
      (await data.get('photo_editor', 'getHistory', {}))['success'],
      false,
    );

    // 入参非法拒绝
    expect(
      (await data.get('photo_editor', 'saveHistory', {
        'history': 'not-a-list',
      }))['success'],
      false,
    );
    expect(
      (await data.get('photo_editor', 'saveHistory', {
        'history': ['x'],
      }))['success'],
      false,
    );

    // 域前缀原始写封闭（426）
    try {
      await data.writePath('photo_editor/history.json', []);
      fail('photo_editor 原始写应被拦截');
    } on StorageException catch (e) {
      expect(e.statusCode, 426);
    }
  });
}
