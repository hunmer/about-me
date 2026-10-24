import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sdk_stickers_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async { await data.dispose(); await root.delete(recursive: true); });
  Map value(Map result) { expect(result['success'], isTrue, reason: '$result'); return result['data'] as Map; }
  Future<Map> create(String id) async => value(await data.call('chat', 'createStickerCollection',
    {'id': id, 'name': 'collection', 'stickerPaths': <String>[]}));
  Future<List> list() async => (await data.get('chat', 'getStickerCollections'))['data'] as List;

  test('并发追加、重命名基于最新合集；移除仅指定引用，封面正确切换', () async {
    await create('one');
    final clients = [for (var i = 0; i < 8; i++) AboutmeData.local(root.path)];
    addTearDown(() async { for (final client in clients) { await client.dispose(); } });
    final results = await Future.wait([for (var i = 0; i < clients.length; i++)
      clients[i].call('chat', 'addStickers', {'id': 'one', 'stickerPaths': ['stickers/one/$i.png']})]);
    expect(results.every((r) => r['success'] == true), isTrue);
    value(await data.call('chat', 'renameStickerCollection', {'id': 'one', 'name': 'renamed'}));
    final before = (await list()).single as Map;
    expect(before['name'], 'renamed');
    expect(before['stickerPaths'], hasLength(8));
    final removed = value(await data.call('chat', 'removeSticker', {'id': 'one', 'stickerPath': before['coverPath']}));
    expect(removed['stickerPaths'], hasLength(7));
    expect(removed['coverPath'], (removed['stickerPaths'] as List).first);
    await expectLater(data.writePath('stickers/collections.json', []), throwsA(isA<StorageException>()));
    final backup = jsonDecode(await File('${root.path}/sdk_migrations/chat_stickers/v1_backup.json').readAsString());
    expect(backup['collections'], isEmpty);
  });

  test('资源与多个合集/消息共享，引用仍存在时不能物理删除', () async {
    final asset = await data.assets.upload(Uint8List.fromList([1, 2]), fileName: 'x.gif');
    for (final id in ['one', 'two']) {
      value(await data.call('chat', 'createStickerCollection', {'id': id, 'name': id,
        'stickerPaths': [asset.reference]}));
    }
    value(await data.call('chat', 'create', {'id': 'channel'}));
    final message = value(await data.call('chat', 'sendMessage', {'channelId': 'channel',
      'content': 'image', 'metadata': {'fileInfo': {'path': asset.reference}}}));
    expect((await data.call('assets', 'remove', {'id': asset.id}))['code'], 'CONFLICT');
    value(await data.call('chat', 'deleteStickerCollection', {'id': 'one'}));
    value(await data.call('chat', 'deleteStickerCollection', {'id': 'two'}));
    expect((await data.call('assets', 'remove', {'id': asset.id}))['code'], 'CONFLICT');
    value(await data.call('chat', 'deleteMessage', {'channelId': 'channel', 'messageId': message['id']}));
    expect(await data.assets.remove(asset.id), isTrue);
  });

  test('无效/不存在资源导致整个命令回滚，不留下注册表或迁移备份', () async {
    final result = await data.call('chat', 'createStickerCollection', {'id': 'one', 'name': 'x',
      'stickerPaths': ['asset://00000000-0000-4000-8000-000000000000']});
    expect(result['code'], 'INVALID_PARAMS');
    expect(await File('${root.path}/stickers/collections.json').exists(), isFalse);
    expect(await Directory('${root.path}/sdk_migrations').exists(), isFalse);
    expect(await list(), isEmpty);
  });

  test('旧注册表保留未知字段，损坏条目阻止改写', () async {
    final file = File('${root.path}/stickers/collections.json');
    await file.parent.create();
    final old = [{'id': 'one', 'name': 'old', 'stickerPaths': ['stickers/one/a.gif'],
      'coverPath': 'stickers/one/a.gif', 'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z', 'extension': {'keep': true}}];
    await file.writeAsString(jsonEncode(old));
    final renamed = value(await data.call('chat', 'renameStickerCollection', {'id': 'one', 'name': 'new'}));
    expect(renamed['extension'], {'keep': true});
    final backup = jsonDecode(await File('${root.path}/sdk_migrations/chat_stickers/v1_backup.json').readAsString());
    expect(backup['collections'], old);
    await file.writeAsString('[{"id":"broken"}]');
    expect((await data.call('chat', 'createStickerCollection', {'name': 'new'}))['code'], 'CORRUPT_DATA');
    expect(await file.readAsString(), '[{"id":"broken"}]');
  });

  test('旧贴图通过 SDK 受控读取，目录穿越/业务 JSON 不能借此访问', () async {
    final file = File('${root.path}/stickers/one/x.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 255]);
    expect(await data.assets.readLegacySticker('stickers/one/x.png'), [1, 2, 255]);
    expect(await data.assets.readLegacySticker('stickers/one/missing.png'), isNull);
    for (final path in ['diary/2026-01-01.json', 'stickers/../diary/x.png', 'stickers/collections.json']) {
      expect((await data.get('assets', 'readLegacySticker', {'sourcePath': path}))['code'], 'INVALID_PARAMS');
    }
  });

  test('删除频道解除其消息资源引用；用户正文中的资源文本不当作附件', () async {
    final asset = await data.assets.upload(Uint8List.fromList([1]), fileName: 'x.png');
    value(await data.call('chat', 'create', {'id': 'c'}));
    value(await data.call('chat', 'sendMessage', {'channelId': 'c', 'content': 'asset://not-an-id'}));
    value(await data.call('chat', 'sendMessage', {'channelId': 'c', 'content': '',
      'metadata': {'fileInfo': {'path': asset.reference}}}));
    expect((await data.call('assets', 'remove', {'id': asset.id}))['code'], 'CONFLICT');
    value(await data.call('chat', 'delete', {'id': 'c'}));
    expect(await data.assets.remove(asset.id), isTrue);
  });

  test('migrateLegacyStickers：dryRun 统计、注册表引用更新、幂等重跑、旧文件删除', () async {
    // 注入旧注册表（含跨合集共享贴图）与旧贴图二进制
    final reg = File('${root.path}/stickers/collections.json');
    await reg.parent.create(recursive: true);
    await reg.writeAsString(jsonEncode([
      {'id': 'a', 'name': 'A', 'stickerPaths': ['stickers/one/s1.gif', 'stickers/one/shared.png'],
        'coverPath': 'stickers/one/s1.gif', 'createdAt': '2026-01-01T00:00:00Z', 'updatedAt': '2026-01-01T00:00:00Z'},
      {'id': 'b', 'name': 'B', 'stickerPaths': ['stickers/two/s2.png', 'stickers/one/shared.png'],
        'coverPath': 'stickers/two/s2.png', 'createdAt': '2026-01-02T00:00:00Z', 'updatedAt': '2026-01-02T00:00:00Z'},
    ]));
    for (final path in ['stickers/one/s1.gif', 'stickers/one/shared.png', 'stickers/two/s2.png']) {
      final f = File('${root.path}/$path');
      await f.parent.create(recursive: true);
      await f.writeAsBytes([1, 2, 3, path.length]);
    }

    // dryRun（默认）：仅统计，不产生副作用
    final dry = value(await data.call('chat', 'migrateLegacyStickers', {}));
    expect(dry['dryRun'], true);
    expect(dry['pending'], 3);
    expect(await File('${root.path}/stickers/one/s1.gif').exists(), isTrue);

    // 执行：注册表全部引用替换为 asset://，旧文件删除
    final done = value(await data.call('chat', 'migrateLegacyStickers', {'dryRun': false}));
    expect(done['migrated'], 3);
    expect((done['failed'] as List), isEmpty);
    expect(done['updatedCollections'], 2);
    for (final path in ['stickers/one/s1.gif', 'stickers/one/shared.png', 'stickers/two/s2.png']) {
      expect(await File('${root.path}/$path').exists(), isFalse, reason: path);
    }
    final collections = await list();
    for (final entry in collections.cast<Map>()) {
      for (final ref in (entry['stickerPaths'] as List).cast<String>()) {
        expect(ref.startsWith('asset://'), isTrue, reason: ref);
      }
    }
    // 共享贴图两个合集引用同一资源
    final collectionA = collections.cast<Map>().firstWhere((entry) => entry['id'] == 'a');
    final collectionB = collections.cast<Map>().firstWhere((entry) => entry['id'] == 'b');
    final refsA = (collectionA['stickerPaths'] as List).cast<String>();
    final refsB = (collectionB['stickerPaths'] as List).cast<String>();
    final shared = refsA.toSet().intersection(refsB.toSet());
    expect(shared.length, 1);
    // 封面同步更新为资源引用
    expect(((collections[0] as Map)['coverPath'] as String).startsWith('asset://'), isTrue);

    // 资源可读
    final sharedId = shared.first.substring('asset://'.length);
    expect(await data.assets.read(sharedId), isNotNull);

    // 幂等重跑：无待迁移引用
    final again = value(await data.call('chat', 'migrateLegacyStickers', {'dryRun': false}));
    expect(again['pending'], 0);
    expect(again['migrated'], 0);

    // 中断恢复场景：注册表被回写为旧引用（迁移记录仍在），重跑从记录恢复映射
    final records = (await list()).cast<Map>().toList();
    final idOf = <String, String>{};
    for (final entry in records) {
      for (final ref in (entry['stickerPaths'] as List).cast<String>()) {
        idOf[ref.substring('asset://'.length)] = '';
      }
    }
    // 模拟旧引用残留：把合集 A 的首张改回旧路径（文件已删）
    final rollback = [
      for (final entry in records)
        {...entry, 'stickerPaths': [
          for (final ref in (entry['stickerPaths'] as List).cast<String>())
            if (entry['id'] == 'a' && ref == refsA.first) 'stickers/one/s1.gif' else ref,
        ], 'coverPath': entry['id'] == 'a' ? 'stickers/one/s1.gif' : entry['coverPath']},
    ];
    await reg.writeAsString(jsonEncode(rollback));
    final recovered = value(await data.call('chat', 'migrateLegacyStickers', {'dryRun': false}));
    expect(recovered['migrated'], 1); // 从迁移记录恢复，不读旧文件
    final finalA = ((await list()).firstWhere((e) => (e as Map)['id'] == 'a') as Map);
    expect(((finalA['stickerPaths'] as List).cast<String>().every((r) => r.startsWith('asset://'))), isTrue);
  });
}
