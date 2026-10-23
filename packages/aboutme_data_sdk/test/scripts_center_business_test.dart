import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// 脚本中心域：脚本/配置/执行记录/商场四组命令。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('scripts_center_sdk_');
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
    await f.writeAsString(value is String ? value : jsonEncode(value));
  }

  Future<String> readFixture(String path) async =>
      File(root.path + '/' + path).readAsString();

  test('脚本元数据/代码往返：命令写入后 listScripts/getMeta/getCode 可读', () async {
    expect(ok(await data.get('scripts_center', 'listScripts', {})), isEmpty);
    expect(ok(await data.get('scripts_center', 'getMeta', {'id': 's1'})), isNull);
    expect(ok(await data.get('scripts_center', 'getCode', {'id': 's1'})), isNull);
    expect(
      ok(await data.get('scripts_center', 'existsScript', {'id': 's1'})),
      false,
    );

    final meta = {
      'name': '测试脚本',
      'version': '1.2.0',
      'enabled': true,
      'builtIn': false,
    };
    ok(await data.call('scripts_center', 'saveMeta', {
      'id': 's1',
      'metadata': meta,
    }));
    const code = 'async function main(){ return 1; }';
    ok(await data.call('scripts_center', 'saveCode', {
      'id': 's1',
      'code': code,
    }));

    // 磁盘上 script.js 为 JSON 字符串（裸文本通道由命令编解码）
    expect(await readFixture('scripts_center/scripts/s1/script.js'),
        jsonEncode(code));

    final list = ok(await data.get('scripts_center', 'listScripts', {})) as List;
    expect(list.length, 1);
    expect(list.first['id'], 's1');
    expect((list.first['metadata'] as Map)['version'], '1.2.0');

    expect(
      (ok(await data.get('scripts_center', 'getMeta', {'id': 's1'})) as Map)[
          'name'],
      '测试脚本',
    );
    expect(
      ok(await data.get('scripts_center', 'getCode', {'id': 's1'})),
      code,
    );
    expect(
      ok(await data.get('scripts_center', 'existsScript', {'id': 's1'})),
      true,
    );
  });

  test('迁移落盘的旧数据（分区文件直写）经命令可读，损坏 metadata 跳过', () async {
    // 模拟 Flutter 迁移直接落盘的结果：metadata 为对象、script.js 为 JSON 字符串
    await fixture('scripts_center/scripts/a/metadata.json',
        {'name': 'A', 'version': '1.0.0'});
    await fixture('scripts_center/scripts/a/script.js', jsonEncode('code-a'));
    await fixture('scripts_center/scripts/b/metadata.json',
        {'name': 'B', 'version': '2.0.0'});
    await fixture('scripts_center/scripts/b/script.js', jsonEncode('code-b'));
    // 损坏：非法 JSON
    await fixture('scripts_center/scripts/bad/metadata.json', '{oops');

    final list = ok(await data.get('scripts_center', 'listScripts', {})) as List;
    expect(list.map((e) => e['id']).toList()..sort(), ['a', 'b']);
    expect(
      ok(await data.get('scripts_center', 'getCode', {'id': 'a'})),
      'code-a',
    );
  });

  test('createScript 事务：已存在拒绝 CONFLICT，成功后 meta+code 均可读', () async {
    final created = ok(await data.call('scripts_center', 'createScript', {
      'id': 's1',
      'metadata': {'name': 'S1', 'version': '1.0.0'},
      'code': '// s1',
    }));
    expect(created['id'], 's1');

    final conflict =
        await data.call('scripts_center', 'createScript', {
      'id': 's1',
      'metadata': {'name': 'S1', 'version': '2.0.0'},
      'code': '// s1 v2',
    });
    expect(conflict['success'], false);
    expect(conflict['code'], 'CONFLICT');
    // 旧内容未被覆盖
    expect(
      (ok(await data.get('scripts_center', 'getMeta', {'id': 's1'})) as Map)[
          'version'],
      '1.0.0',
    );
    expect(ok(await data.get('scripts_center', 'getCode', {'id': 's1'})), '// s1');
  });

  test('deleteScript 级联删除 meta/code/config', () async {
    await data.call('scripts_center', 'createScript', {
      'id': 's1',
      'metadata': {'name': 'S1'},
      'code': '// s1',
    });
    await data.call('scripts_center', 'setConfig', {
      'scriptId': 's1',
      'config': {'enabled': true},
    });
    expect(
      (ok(await data.get('scripts_center', 'getConfig', {'scriptId': 's1'}))
              as Map)
          .isNotEmpty,
      true,
    );

    ok(await data.call('scripts_center', 'deleteScript', {'id': 's1'}));
    expect(
      ok(await data.get('scripts_center', 'existsScript', {'id': 's1'})),
      false,
    );
    expect(ok(await data.get('scripts_center', 'getMeta', {'id': 's1'})), isNull);
    expect(ok(await data.get('scripts_center', 'getCode', {'id': 's1'})), isNull);
    expect(
      ok(await data.get('scripts_center', 'getConfig', {'scriptId': 's1'})),
      isNull,
    );
    expect(ok(await data.get('scripts_center', 'listScripts', {})), isEmpty);
  });

  test('syncBuiltin 版本比较：新版本覆盖、旧版本/同版本跳过、缺失恢复', () async {
    Future<Map<String, dynamic>> sync(List items) => data.call(
        'scripts_center', 'syncBuiltin', {'items': items});

    // 本地不存在：恢复
    var result = ok(await sync([
      {
        'id': 'lib1',
        'metadata': {'name': 'Lib1', 'version': '1.0.0'},
        'code': '// v1',
      },
    ])) as Map;
    expect(result['synced'], ['lib1']);
    expect(result['skipped'], isEmpty);

    // 同版本：跳过（保留本地修改）
    result = ok(await sync([
      {
        'id': 'lib1',
        'metadata': {'name': 'Lib1', 'version': '1.0.0'},
        'code': '// v1 same',
      },
    ])) as Map;
    expect(result['synced'], isEmpty);
    expect(result['skipped'], ['lib1']);
    expect(
      ok(await data.get('scripts_center', 'getCode', {'id': 'lib1'})),
      '// v1',
    );

    // 更高版本（1.10.0 > 1.9.0 数值语义，非字符串比较）：覆盖
    await data.call('scripts_center', 'saveMeta', {
      'id': 'lib1',
      'metadata': {'name': 'Lib1', 'version': '1.9.0'},
    });
    result = ok(await sync([
      {
        'id': 'lib1',
        'metadata': {'name': 'Lib1', 'version': '1.10.0'},
        'code': '// v2',
      },
    ])) as Map;
    expect(result['synced'], ['lib1']);
    expect(
      (ok(await data.get('scripts_center', 'getMeta', {'id': 'lib1'})) as Map)[
          'version'],
      '1.10.0',
    );

    // 更低版本：跳过
    result = ok(await sync([
      {
        'id': 'lib1',
        'metadata': {'name': 'Lib1', 'version': '1.2.0'},
        'code': '// old',
      },
    ])) as Map;
    expect(result['skipped'], ['lib1']);
    expect(
      ok(await data.get('scripts_center', 'getCode', {'id': 'lib1'})),
      '// v2',
    );
  });

  test('scriptConfig：对象原样透传（旧扁平/新 profiles 均为普通 Map）', () async {
    expect(
      ok(await data.get('scripts_center', 'getConfig', {'scriptId': 'x'})),
      isNull,
    );
    final flat = {'enabled': true, 'agentId': 'a1'};
    ok(await data.call('scripts_center', 'setConfig', {
      'scriptId': 'x',
      'config': flat,
    }));
    expect(
      ok(await data.get('scripts_center', 'getConfig', {'scriptId': 'x'})),
      flat,
    );
    ok(await data.call('scripts_center', 'deleteConfig', {'scriptId': 'x'}));
    expect(
      ok(await data.get('scripts_center', 'getConfig', {'scriptId': 'x'})),
      isNull,
    );
  });

  test('execLog：头部插入、滚动 200 条、清空', () async {
    expect(ok(await data.get('scripts_center', 'getExecLog', {})), isEmpty);

    for (var i = 0; i < 205; i++) {
      ok(await data.call('scripts_center', 'recordExecution', {
        'entry': {'scriptId': 's$i', 'success': true, 'seq': i},
      }));
    }
    final rows = ok(await data.get('scripts_center', 'getExecLog', {})) as List;
    expect(rows.length, 200);
    // 最新的在前
    expect(rows.first['scriptId'], 's204');
    expect(rows.last['scriptId'], 's5');

    ok(await data.call('scripts_center', 'clearExecLog', {}));
    expect(ok(await data.get('scripts_center', 'getExecLog', {})), isEmpty);
  });

  test('store：sources 与 installed 两组读写', () async {
    expect(ok(await data.get('scripts_center', 'getSources', {})), isEmpty);
    expect(ok(await data.get('scripts_center', 'getInstalled', {})), isEmpty);

    ok(await data.call('scripts_center', 'saveSources', {
      'sources': [
        {'id': 'src1', 'name': '本地仓库'},
      ],
    }));
    ok(await data.call('scripts_center', 'saveInstalled', {
      'installed': [
        {'scriptId': 's1', 'version': '1.0.0'},
      ],
    }));
    expect(
      (ok(await data.get('scripts_center', 'getSources', {})) as List)
          .first['id'],
      'src1',
    );
    expect(
      (ok(await data.get('scripts_center', 'getInstalled', {})) as List)
          .first['scriptId'],
      's1',
    );
  });

  test('id/scriptId 路径穿越与非法输入拒绝', () async {
    Future<Map<String, dynamic>> fail(String action, Map<String, dynamic> p) =>
        data.call('scripts_center', action, p);

    for (final id in ['../other', 'a/b', 'a\\b', '']) {
      expect((await fail('getMeta', {'id': id}))['success'], false,
          reason: 'getMeta id=$id');
      expect((await fail('getCode', {'id': id}))['success'], false,
          reason: 'getCode id=$id');
    }
    expect(
      (await fail('getConfig', {'scriptId': '../webview'}))['success'],
      false,
    );
    expect(
      (await fail('setConfig', {'scriptId': 'ok', 'config': 'not-a-map'}))[
          'success'],
      false,
    );
    expect(
      (await fail('saveCode', {'id': 'ok', 'code': 42}))['success'],
      false,
    );
    expect(
      (await fail('createScript', {
        'id': 'ok',
        'metadata': {'name': 'x'},
        'code': 1,
      }))['success'],
      false,
    );
    // createScript 参数不合法时不落任何文件
    expect(ok(await data.get('scripts_center', 'listScripts', {})), isEmpty);
  });
}
