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
}
