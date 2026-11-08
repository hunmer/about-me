import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// 单文件快照域（timer/achievement/reminder/live2d/tts）：
/// 保持各域原文件布局，getSnapshot/saveSnapshot 整文件读写。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('snapshot_domains_');
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

  test('timer：旧 tasks.json 可读、快照读写、列表键类型校验', () async {
    final f = File('${root.path}/timer/tasks.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({
      'tasks': [
        {'id': 't1', 'title': '倒计时', 'duration': 300},
      ],
    }));

    final snapshot = ok(await data.get('timer', 'getSnapshot', {})) as Map;
    expect((snapshot['tasks'] as List).first['id'], 't1');

    ok(await data.get('timer', 'saveSnapshot', {
      'snapshot': {'tasks': []},
    }));
    expect((ok(await data.get('timer', 'getSnapshot', {})) as Map)['tasks'], []);

    // tasks 必须是 List
    expect(
      (await data.get('timer', 'saveSnapshot', {
        'snapshot': {'tasks': 'x'},
      }))['success'],
      false,
    );
  });

  test('achievement：进度 Map 读写', () async {
    expect(ok(await data.get('achievement', 'getSnapshot', {})), isEmpty);
    ok(await data.get('achievement', 'saveSnapshot', {
      'snapshot': {
        'a1': {'unlocked': true, 'progress': 3},
      },
    }));
    final snapshot = ok(
      await data.get('achievement', 'getSnapshot', {}),
    ) as Map;
    expect(snapshot['a1']['unlocked'], true);
  });

  test('reminder：reminders 列表读写', () async {
    ok(await data.get('reminder', 'saveSnapshot', {
      'snapshot': {
        'reminders': [
          {'id': 'r1', 'isEnabled': true},
        ],
      },
    }));
    final snapshot = ok(
      await data.get('reminder', 'getSnapshot', {}),
    ) as Map;
    expect((snapshot['reminders'] as List).length, 1);
  });

  test('live2d：v2 分文件存储（archives_v2/<id>.json + 元数据）', () async {
    // saveSnapshot 只落 selectedId
    ok(await data.get('live2d', 'saveSnapshot', {
      'snapshot': {'selectedId': 'a1'},
    }));
    // 存档走 upsertArchive / deleteArchive 独立文件
    ok(await data.get('live2d', 'upsertArchive', {
      'id': 'a1',
      'archive': {'id': 'a1', 'name': 'hiyori'},
    }));
    ok(await data.get('live2d', 'upsertArchive', {
      'id': 'a2',
      'archive': {'id': 'a2', 'name': 'haru'},
    }));

    final snapshot = ok(
      await data.get('live2d', 'getSnapshot', {}),
    ) as Map;
    expect(snapshot['selectedId'], 'a1');
    final names = (snapshot['archives'] as List)
        .map((e) => (e as Map)['name'])
        .toSet();
    expect(names, {'hiyori', 'haru'});

    // 独立文件确实存在
    expect(File('${root.path}/live2d/archives_v2/a1.json').existsSync(), true);

    // 删除单个存档文件
    ok(await data.get('live2d', 'deleteArchive', {'id': 'a2'}));
    final after = ok(await data.get('live2d', 'getSnapshot', {})) as Map;
    expect((after['archives'] as List).length, 1);
    expect(File('${root.path}/live2d/archives_v2/a2.json').existsSync(), false);
  });

  test('tts：services Map 读写、损坏拒绝', () async {
    expect(ok(await data.get('tts', 'getSnapshot', {})), isEmpty);
    ok(await data.get('tts', 'saveSnapshot', {
      'snapshot': {
        'services': {'s1': {'name': 'edge'}},
      },
    }));
    expect(
      ((ok(await data.get('tts', 'getSnapshot', {})) as Map)['services']
          as Map)['s1']['name'],
      'edge',
    );

    // 损坏数据拒绝
    final f = File('${root.path}/tts/services.json');
    await f.writeAsString('[1]');
    expect((await data.get('tts', 'getSnapshot', {}))['success'], false);
  });
}
