import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

/// Toolbox 域业务：工具配置（configs/ 分区，含旧脚本中心迁移）与
/// AI 生图/图片搜索历史（保持旧文件布局，顶层 List）。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('toolbox_business_');
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

  test('配置：首次读取自动迁移旧脚本中心配置并落盘', () async {
    // 无新配置、无旧配置 → 空对象
    expect(ok(await data.get('toolbox', 'getAiImageConfig', {})), isEmpty);

    // 旧脚本中心配置存在 → 迁移返回并写入新路径
    await fixture('configs/scripts_center/ai_image_config.json', {
      'apiKey': 'sk-1',
      'model': 'gpt-image-2',
    });
    final config = ok(await data.get('toolbox', 'getAiImageConfig', {})) as Map;
    expect(config['apiKey'], 'sk-1');
    expect(config['model'], 'gpt-image-2');

    // 新文件已落盘；此后旧文件变更不再影响读取
    await fixture('configs/scripts_center/ai_image_config.json', {
      'apiKey': 'stale',
    });
    final again = ok(await data.get('toolbox', 'getAiImageConfig', {})) as Map;
    expect(again['apiKey'], 'sk-1');
  });

  test('配置：save 全量替换、往返一致（image_search 同布局）', () async {
    final saved = ok(await data.get(
      'toolbox',
      'saveImageSearchConfig',
      {
        'config': {'serpApiKey': 'k1', 'perPage': 10},
      },
    )) as Map;
    expect(saved['serpApiKey'], 'k1');

    final config = ok(
      await data.get('toolbox', 'getImageSearchConfig', {}),
    ) as Map;
    expect(config['perPage'], 10);
    expect(config['serpApiKey'], 'k1');
  });

  test('配置：损坏 JSON 拒绝（CORRUPT_DATA）', () async {
    await fixture('configs/toolbox/ai_image_config.json', 'not-a-map');
    // 非对象但 JSON 合法：与原客户端一致，回落旧配置（缺失则空对象）
    expect(ok(await data.get('toolbox', 'getAiImageConfig', {})), isEmpty);

    final f = File('${root.path}/configs/toolbox/ai_image_config.json');
    await f.writeAsString('{"broken":');
    final r = await data.get('toolbox', 'getAiImageConfig', {});
    expect(r['success'], false);
    expect(r['code'], 'CORRUPT_DATA');
  });

  test('生图历史：旧顶层 List 可读、整表读写往返、上限由客户端截断', () async {
    await fixture('toolbox/ai_image/history.json', [
      {
        'ts': 2,
        'prompt': 'cat',
        'model': 'gpt-image-2',
        'aspectRatio': '1:1',
        'refCount': 0,
        'images': ['toolbox/ai_image/a.png'],
      },
      {
        'ts': 1,
        'prompt': 'dog',
        'model': 'nano-banana',
        'aspectRatio': '16:9',
        'refCount': 1,
        'images': ['toolbox/ai_image/b.png'],
      },
    ]);

    final rows = ok(await data.get('toolbox', 'getAiImageHistory', {})) as List;
    expect(rows.length, 2);
    expect(rows.first['prompt'], 'cat');
    expect(rows.first['images'], isList);

    // 整表写回（客户端插入新记录后全量保存）
    final result = ok(await data.get('toolbox', 'saveAiImageHistory', {
      'history': [
        {'ts': 3, 'prompt': 'new', 'images': []},
        ...rows,
      ],
    })) as Map;
    expect(result['count'], 3);
    final reread = ok(await data.get('toolbox', 'getAiImageHistory', {})) as List;
    expect(reread.length, 3);
    expect(reread.first['prompt'], 'new');

    // 入参校验：history 非列表 / 行非对象 / images 非列表
    for (final p in [
      {'history': 'x'},
      {'history': ['x']},
      {
        'history': [
          {'ts': 1, 'images': 'x'},
        ],
      },
    ]) {
      expect(
        (await data.get('toolbox', 'saveAiImageHistory', p))['success'],
        false,
        reason: '$p',
      );
    }
  });

  test('搜图历史：旧文件可读、去重置顶、按 ts 删除、清空', () async {
    await fixture('toolbox/image_search_history.json', [
      {'mode': 'keyword', 'query': 'sky', 'imageUrl': '', 'provider': 'unsplash', 'ts': 1},
      {'mode': 'keyword', 'query': 'cat', 'imageUrl': '', 'provider': 'pixabay', 'ts': 2},
    ]);

    final rows = ok(
      await data.get('toolbox', 'getImageSearchHistory', {}),
    ) as List;
    expect(rows.length, 2);

    // 相同四元组去重置顶（ts 可指定）
    final added = ok(await data.get('toolbox', 'addImageSearchHistory', {
      'mode': 'keyword',
      'query': 'sky',
      'imageUrl': '',
      'provider': 'unsplash',
      'ts': 99,
    })) as List;
    expect(added.length, 2);
    expect(added.first['ts'], 99);
    expect(added.first['query'], 'sky');

    // 不同关键词追加置顶
    final added2 = ok(await data.get('toolbox', 'addImageSearchHistory', {
      'mode': 'lens',
      'query': '',
      'imageUrl': 'https://e.com/x.png',
      'provider': 'unsplash',
    })) as List;
    expect(added2.length, 3);

    // 按 ts 删除（REST 路径参数为字符串，int/string 均可命中）
    final removed = ok(await data.get(
      'toolbox',
      'removeImageSearchHistory',
      {'ts': '2'},
    )) as List;
    expect(removed.length, 2);
    expect(removed.any((e) => e['ts'] == 2), false);

    // 清空 → 空列表（与原客户端写入 [] 一致）
    ok(await data.get('toolbox', 'clearImageSearchHistory', {}));
    final cleared = ok(
      await data.get('toolbox', 'getImageSearchHistory', {}),
    ) as List;
    expect(cleared, isEmpty);
  });

  test('搜图历史：上限 50 截断', () async {
    for (var i = 0; i < 55; i++) {
      ok(await data.get('toolbox', 'addImageSearchHistory', {
        'mode': 'keyword',
        'query': 'q$i',
        'imageUrl': '',
        'provider': 'unsplash',
        'ts': i,
      }));
    }
    final rows = ok(
      await data.get('toolbox', 'getImageSearchHistory', {}),
    ) as List;
    expect(rows.length, 50);
    // 新→旧：最新在前，最旧的 5 条被截掉
    expect(rows.first['query'], 'q54');
    expect(rows.last['query'], 'q5');
  });

  test('历史：损坏数据 CORRUPT_DATA 拒绝', () async {
    await fixture('toolbox/ai_image/history.json', {'not': 'a list'});
    var r = await data.get('toolbox', 'getAiImageHistory', {});
    expect(r['success'], false);
    expect(r['code'], 'CORRUPT_DATA');

    await fixture('toolbox/image_search_history.json', [
      {'ts': 1},
      'bad-row',
    ]);
    r = await data.get('toolbox', 'getImageSearchHistory', {});
    expect(r['success'], false);
    expect(r['code'], 'CORRUPT_DATA');
  });
}
