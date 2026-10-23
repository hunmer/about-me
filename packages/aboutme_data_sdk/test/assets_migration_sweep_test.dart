import 'dart:convert';
import 'dart:io';
import 'package:aboutme_data_sdk/io.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// assets 域 P1 能力：分区外旧媒体批量迁移（幂等 + 白名单 + 迁移后删旧）
/// 与引用计数为 0 的 sweep 回收。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('assets_p1_');
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

  Future<File> injectBinary(String path, List<int> bytes) async {
    final f = File('${root.path}/$path');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes);
    return f;
  }

  test('migrateLegacyAssets：迁移/幂等/白名单/删旧文件', () async {
    await injectBinary('openai/moments/images/p1.png', [1, 2, 3]);
    await injectBinary('toolbox/ai_image/p2.png', [4, 5]);
    await injectBinary('misc/evil.png', [9]);
    await injectBinary('openai/agents.json', utf8.encode('[]')); // 非媒体扩展名

    final result = ok(await data.get('assets', 'migrateLegacyAssets', {
      'items': [
        {'sourcePath': 'openai/moments/images/p1.png'},
        {'sourcePath': 'toolbox/ai_image/p2.png'},
        {'sourcePath': 'misc/evil.png'},
        {'sourcePath': 'openai/agents.json'},
        {'sourcePath': 'openai/missing.png'},
        {'sourcePath': '../outside.png'},
      ],
    })) as Map;

    final migrated = (result['migrated'] as List).cast<Map>();
    final failed = (result['failed'] as List).cast<Map>();
    expect(migrated.length, 2);
    expect(failed.length, 4); // 白名单外前缀/非媒体/不存在/穿越

    // 迁移后旧文件删除，资源可读且内容一致
    expect(await File('${root.path}/openai/moments/images/p1.png').exists(), isFalse);
    final ref1 = migrated
        .firstWhere((m) => m['sourcePath'] == 'openai/moments/images/p1.png');
    final assetId1 = (ref1['reference'] as String).substring('asset://'.length);
    expect(await data.assets.read(assetId1), [1, 2, 3]);

    // 幂等：重复迁移同一路径复用既有资源，不再上传
    final again = ok(await data.get('assets', 'migrateLegacyAssets', {
      'items': [
        {'sourcePath': 'openai/moments/images/p1.png'},
      ],
    })) as Map;
    expect((again['migrated'] as List).length, 1);
    expect(
      ((again['migrated'] as List).first as Map)['id'],
      assetId1,
    );
    final list = ok(await data.get('assets', 'list', {})) as Map;
    expect(list['total'], 2, reason: '重复迁移不得新增资源');
  });

  test('分块上传：init/append/complete 全链路与异常拒绝', () async {
    // 用小 chunk 场景验证协议（实际 chunk 上限 8 MiB；此处按真实 chunkBytes 分块）
    const chunk = 8 * 1024 * 1024;
    final part1 = List.filled(chunk, 7);
    final part2 = List.filled(1024, 9); // 末块可小
    final full = [...part1, ...part2];
    final digest = sha256.convert(full).toString();

    final init = ok(await data.get('assets', 'initUpload', {
      'fileName': 'big.png', 'mediaType': 'image/png',
      'size': full.length, 'sha256': digest,
    })) as Map;
    expect(init['totalChunks'], 2);

    final uploadId = init['uploadId'] as String;
    // 缺块 complete 拒绝
    final early = await data.get('assets', 'completeUpload', {'uploadId': uploadId});
    expect(early['code'], 'INVALID_PARAMS');

    // 乱序 append 幂等（先 1 后 0，重复 1）
    ok(await data.get('assets', 'appendChunk', {
      'uploadId': uploadId, 'index': 1, 'content': base64Encode(part2),
    }));
    ok(await data.get('assets', 'appendChunk', {
      'uploadId': uploadId, 'index': 0, 'content': base64Encode(part1),
    }));
    final dup = ok(await data.get('assets', 'appendChunk', {
      'uploadId': uploadId, 'index': 1, 'content': base64Encode(part2),
    })) as Map;
    expect(dup['receivedChunks'], 2);

    // 越界拒绝
    expect(
      (await data.get('assets', 'appendChunk', {
        'uploadId': uploadId, 'index': 2, 'content': base64Encode([1]),
      }))['code'],
      'INVALID_PARAMS',
    );

    final done = ok(await data.get('assets', 'completeUpload', {
      'uploadId': uploadId,
    })) as Map;
    expect(done['size'], full.length);
    expect(done['sha256'], digest);
    // 资源内容与分块合并一致
    expect(await data.assets.read(done['id'] as String), full);

    // 完成后暂存清理，重复 complete 404
    expect(
      (await data.get('assets', 'completeUpload', {'uploadId': uploadId}))['code'],
      'NOT_FOUND',
    );
  });

  test('分块上传：sha256 不符拒绝、超限拒绝', () async {
    final init = ok(await data.get('assets', 'initUpload', {
      'fileName': 'x.png', 'mediaType': 'image/png',
      'size': 3, 'sha256': 'a' * 64,
    })) as Map;
    final uploadId = init['uploadId'] as String;
    await data.get('assets', 'appendChunk', {
      'uploadId': uploadId, 'index': 0, 'content': base64Encode([1, 2, 3]),
    });
    final bad = await data.get('assets', 'completeUpload', {'uploadId': uploadId});
    expect(bad['code'], 'INVALID_PARAMS');
    expect(bad['error'], contains('sha256'));

    // 总大小超 256 MiB 拒绝
    expect(
      (await data.get('assets', 'initUpload', {
        'fileName': 'huge.png', 'mediaType': 'image/png',
        'size': 257 * 1024 * 1024,
      }))['code'],
      'INVALID_PARAMS',
    );
  });

  test('sweep：引用为 0 回收、有引用保护、dryRun 与 minAge 保护', () async {
    final uploaded = ok(await data.get('assets', 'upload', {
      'content': base64Encode([1, 2, 3]),
      'fileName': 'orphan.png',
      'mediaType': 'image/png',
    })) as Map;
    final referenced = ok(await data.get('assets', 'upload', {
      'content': base64Encode([4, 5]),
      'fileName': 'used.png',
      'mediaType': 'image/png',
    })) as Map;
    final oldId = uploaded['id'] as String;
    final usedId = referenced['id'] as String;

    // minAge 保护：刚上传的资源默认（24h）不回收
    final youngDry = ok(await data.get('assets', 'sweep', {})) as Map;
    expect(youngDry['count'], 0);

    // 引用中的资源永不回收：手动建立引用索引
    final refFile = File('${root.path}/asset_references/$usedId.json');
    await refFile.parent.create(recursive: true);
    await refFile.writeAsString(jsonEncode(['chat/collections.json']));

    // dryRun 列出候选（orphan）不删除
    final dry = ok(await data.get('assets', 'sweep', {
      'minAgeHours': 0,
    })) as Map;
    expect(dry['dryRun'], isTrue);
    expect(dry['ids'], [oldId]);
    final stillThere = await data.get('assets', 'getMetadata', {'id': oldId});
    expect(stillThere['success'], isTrue);

    // 正式回收：orphan 删除、used 保留
    final swept = ok(await data.get('assets', 'sweep', {
      'dryRun': false,
      'minAgeHours': 0,
    })) as Map;
    expect(swept['ids'], [oldId]);
    expect(
      (await data.get('assets', 'getMetadata', {'id': oldId}))['code'],
      'NOT_FOUND',
    );
    expect(
      (await data.get('assets', 'getMetadata', {'id': usedId}))['success'],
      isTrue,
    );
    // 资源索引同步更新
    final list = ok(await data.get('assets', 'list', {})) as Map;
    expect(list['total'], 1);
  });
}
