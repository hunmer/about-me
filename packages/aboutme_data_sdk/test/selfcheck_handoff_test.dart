import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:aboutme_data_sdk/io.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// handoff.md 第八轮基线自检：按文档契约直接验证，不参考实现。
void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('handoff_selfcheck_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  dynamic ok(Map<String, dynamic> res) {
    expect(res['success'], true, reason: '$res');
    return res['data'];
  }


  group('system 域 configs 命令速查', () {
    test('getConfig 缺省 value=null；setConfig 覆盖写；deleteConfig', () async {
      expect(ok(await data.get('system', 'getConfig', {'key': 'app_config.json'}))['value'], isNull);

      ok(await data.get('system', 'setConfig', {
        'key': 'app_config.json',
        'value': {'a': 1},
      }));
      expect(ok(await data.get('system', 'getConfig', {'key': 'app_config.json'}))['value'], {'a': 1});

      ok(await data.get('system', 'setConfig', {
        'key': 'app_config.json',
        'value': {'b': 2},
      }));
      expect(ok(await data.get('system', 'getConfig', {'key': 'app_config.json'}))['value'], {'b': 2});

      expect(ok(await data.get('system', 'deleteConfig', {'key': 'app_config.json'}))['deleted'], true);
      expect(ok(await data.get('system', 'getConfig', {'key': 'app_config.json'}))['value'], isNull);
    });

    test('key 白名单：穿越/反斜杠/空格/空串拒绝', () async {
      for (final key in ['../x.json', 'a\\b.json', 'a b.json', '']) {
        final res = await data.get('system', 'setConfig', {'key': key, 'value': 1});
        expect(res['success'], false, reason: 'key=$key 应被拒绝');
      }
    });

    test('封闭验收：configs/ 原始写 426、读不受限', () async {
      ok(await data.get('system', 'setConfig', {'key': 'k.json', 'value': 'v'}));
      await expectLater(
        data.writePath('configs/k.json', 'x'),
        throwsA(isA<StorageException>().having((e) => e.statusCode, 'statusCode', 426)),
      );
      expect(ok(await data.get('system', 'getConfig', {'key': 'k.json'}))['value'], 'v');
    });
  });

  group('migratedDomains 封闭（文件层原始写 426）', () {
    for (final path in ['diary/x.json', 'todo/x.json', 'tracker/x.json', 'photo_editor/x.json', 'agent_chat/x.json', 'configs/k.json']) {
      test('$path writePath 抛 426（读不受限）', () async {
        await expectLater(
          data.writePath(path, 'y'),
          throwsA(isA<StorageException>().having(
            (e) => e.statusCode, 'statusCode', 426,
          )),
        );
        expect(await data.existsPath(path), isFalse, reason: '写被拦截后不应落盘');
      });
    }
  });

  group('photo_editor 薄文件层历史', () {
    test('getHistory/saveHistory/clearHistory', () async {
      expect(ok(await data.get('photo_editor', 'getHistory', {})), isEmpty);
      ok(await data.get('photo_editor', 'saveHistory', {
        'history': [
          {'op': 'crop', 'ts': 1},
        ],
      }));
      final h = ok(await data.get('photo_editor', 'getHistory', {})) as List;
      expect(h.single['op'], 'crop');
      ok(await data.get('photo_editor', 'clearHistory', {}));
      expect(ok(await data.get('photo_editor', 'getHistory', {})), isEmpty);
    });
  });

  group('assets 资源命令', () {
    test('initUpload/appendChunk/completeUpload 端到端 + sha256 校验', () async {
      final bytes = utf8.encode('hello-chunked-upload');
      final digest = sha256.convert(bytes).toString();
      final init = ok(await data.call('assets', 'initUpload', {
        'fileName': 'selfcheck.bin',
        'mediaType': 'application/octet-stream',
        'size': bytes.length,
        'sha256': digest,
      })) as Map;
      final uploadId = init['uploadId'] as String;
      ok(await data.call('assets', 'appendChunk', {
        'uploadId': uploadId,
        'index': 0,
        'content': base64Encode(bytes),
      }));
      final done = ok(await data.call('assets', 'completeUpload', {'uploadId': uploadId})) as Map;
      final assetId = done['id'] ?? done['assetId'];
      expect(assetId, isNotNull, reason: '$done');
      expect(await data.assets.read(assetId as String), bytes);
    });

    test('migrateLegacyAssets：白名单迁移 + 幂等；sweep dryRun', () async {
      final f = File('${root.path}/openai/moments/images/p.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes([7, 8, 9]);

      final r1 = ok(await data.get('assets', 'migrateLegacyAssets', {
        'items': [
          {'sourcePath': 'openai/moments/images/p.png'},
        ],
      })) as Map;
      final migrated = (r1['migrated'] as List).cast<Map>().single;
      expect(await f.exists(), isFalse, reason: '迁后删旧');
      final ref = migrated['reference'] as String;
      expect(await data.assets.read(ref.substring('asset://'.length)), [7, 8, 9]);

      final r2 = ok(await data.get('assets', 'migrateLegacyAssets', {
        'items': [
          {'sourcePath': 'openai/moments/images/p.png'},
        ],
      })) as Map;
      expect((r2['migrated'] as List).length, 1);

      final sweep = ok(await data.call('assets', 'sweep', {'dryRun': true, 'minAgeHours': 0})) as Map;
      expect(sweep['dryRun'] ?? sweep['count'], isNotNull, reason: '$sweep');
    });
  });

  group('uploadChunked 封装', () {
    test('端到端（init→append→complete，内容一致）', () async {
      final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 251));
      final dto = await data.assets.uploadChunked(bytes,
          fileName: 'u.bin', mediaType: 'application/octet-stream');
      expect(await data.assets.read(dto.id), bytes);
    });
  });
}


