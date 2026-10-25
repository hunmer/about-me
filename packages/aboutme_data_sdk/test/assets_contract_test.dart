import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late AboutmeData data;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('assets_contract_');
    data = AboutmeData.local(root.path);
  });
  tearDown(() async {
    await data.dispose();
    await root.delete(recursive: true);
  });

  test('资源字节和元数据可往返；普通文件 API 不能改写资源', () async {
    final bytes = Uint8List.fromList([0, 255, 1, 0, 128]);
    final asset = await data.assets.upload(bytes, fileName: '照片.png', mediaType: 'image/png');
    expect(asset.size, bytes.length);
    expect(await data.assets.read(asset.id), bytes);
    expect((await data.assets.getMetadata(asset.id)).toJson(), asset.toJson());
    expect(await data.assets.read(asset.id), bytes);
    await expectLater(data.writePath('assets/${asset.id}.json', {}), throwsA(isA<StorageException>()));
    expect(() => data.clearPathPrefix('a'), throwsA(isA<StorageException>()));
    expect(await data.assets.remove(asset.id), isTrue);
    expect(await data.assets.remove(asset.id), isFalse);
    await expectLater(data.assets.read(asset.id), throwsA(isA<QueryFailure>()));
  });

  test('相同 mutationId 在新实例中只生成同一个资源，换参数报冲突', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final asset = await data.assets.upload(bytes, fileName: 'one.bin', clientMutationId: 'one');
    final other = AboutmeData.local(root.path);
    addTearDown(other.dispose);
    final replay = await other.assets.upload(bytes, fileName: 'one.bin', clientMutationId: 'one');
    expect(replay.id, asset.id);
    expect((await data.assets.list()).total, 1);
    await expectLater(other.assets.upload(bytes, fileName: 'two.bin', clientMutationId: 'one'),
      throwsA(isA<QueryFailure>().having((e) => e.result['code'], 'code', 'CONFLICT')));
  });

  test('不接受目标路径、非法 ID、超限字节、非法 base64', () async {
    for (final params in [
      {'content': 'AA==', 'fileName': '../x', 'mediaType': 'image/png'},
      {'content': 'AA==', 'fileName': 'x', 'mediaType': 'image/png', 'path': 'chat/x'},
      {'content': '%%%', 'fileName': 'x', 'mediaType': 'image/png'},
      {'content': 'AA==', 'fileName': 'x', 'mediaType': 'invalid'},
    ]) {
      expect((await data.call('assets', 'upload', params))['code'], 'INVALID_PARAMS');
    }
    expect((await data.get('assets', 'read', {'id': '../chat/channels'}))['code'], 'INVALID_PARAMS');
    await expectLater(data.assets.upload(Uint8List(16 * 1024 * 1024 + 1), fileName: 'large'),
      throwsArgumentError);
    expect(await Directory('${root.path}/assets').exists(), isFalse);
  });

  test('内容损坏明确失败，元数据查询同样校验，不覆盖原文件', () async {
    final asset = await data.assets.upload(Uint8List.fromList([1, 2]), fileName: 'x.bin');
    final file = File('${root.path}/assets/${asset.id}.json');
    final record = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    record['content'] = 'AwQ=';
    final damaged = jsonEncode(record);
    await file.writeAsString(damaged);
    expect((await data.get('assets', 'getMetadata', {'id': asset.id}))['code'], 'CORRUPT_DATA');
    expect((await data.get('assets', 'read', {'id': asset.id}))['code'], 'CORRUPT_DATA');
    expect(await file.readAsString(), damaged);
  });

  test('并发上传不覆盖，旧业务域版本删除报冲突', () async {
    final first = await data.assets.upload(Uint8List.fromList([0]), fileName: 'same.bin');
    final snapshot = await data.get('assets', 'getMetadata', {'id': first.id});
    final assets = await Future.wait([for (var i = 0; i < 8; i++)
      data.assets.upload(Uint8List.fromList([i]), fileName: 'same.bin')]);
    expect(assets.map((asset) => asset.id).toSet().length, 8);
    await expectLater(data.assets.remove(first.id, expectedVersion: snapshot['version'] as int),
      throwsA(isA<QueryFailure>().having((e) => e.result['code'], 'code', 'CONFLICT')));
    expect(await data.assets.read(first.id), [0]);
  });

  test('资源替换：引用不变，内容/元数据/索引同步更新，物化句柄失效', () async {
    final asset = await data.assets.upload(
        Uint8List.fromList([1, 2, 3]), fileName: '照片.png', mediaType: 'image/png');
    final oldPath = await data.assets.resolvePath(asset.id);
    final updated = await data.assets.replace(asset.id, Uint8List.fromList([9, 9, 9, 9]));
    expect(updated.id, asset.id);
    expect(updated.fileName, asset.fileName);
    expect(updated.createdAt, asset.createdAt);
    expect(updated.size, 4);
    expect(updated.sha256, isNot(asset.sha256));
    expect(await data.assets.read(asset.id), [9, 9, 9, 9]);
    final listed = await data.assets.list(mediaTypePrefix: 'image/');
    expect(listed.data.single.id, asset.id);
    expect(listed.data.single.size, 4);
    expect(listed.data.single.sha256, updated.sha256);
    expect(await File(oldPath).exists(), isFalse);
    expect(await File(await data.assets.resolvePath(asset.id)).readAsBytes(), [9, 9, 9, 9]);
  });

  test('资源替换：不存在报 NOT_FOUND，非法 ID/非法 base64 拒绝', () async {
    const missing = '0a0a0a0a-0a0a-4a0a-8a0a-0a0a0a0a0a0a';
    expect((await data.call('assets', 'replace', {'id': missing, 'content': 'AA=='}))['code'], 'NOT_FOUND');
    expect((await data.call('assets', 'replace', {'id': '../x', 'content': 'AA=='}))['code'], 'INVALID_PARAMS');
    expect((await data.call('assets', 'replace', {'id': missing, 'content': '%%'}))['code'], 'INVALID_PARAMS');
    expect((await data.call('assets', 'replace',
        {'id': missing, 'content': 'AA==', 'fileName': 'x'}))['code'], 'INVALID_PARAMS');
  });

  test('物化仅生成临时句柄，dispose 可重复且不删除持久资源', () async {
    final asset = await data.assets.upload(Uint8List.fromList([2, 4]), fileName: 'x.PNG');
    final handle = await data.assets.materialize(asset.id);
    final file = File(handle.path);
    expect(file.path.endsWith('.PNG'), isTrue);
    expect(await file.readAsBytes(), [2, 4]);
    expect(file.path.contains(root.path), isFalse);
    await handle.dispose();
    await handle.dispose();
    expect(await file.exists(), isFalse);
    expect(await data.assets.read(asset.id), [2, 4]);
  });

  test('资源列表筛选/分页只返回元数据，删除维护索引', () async {
    final image = await data.assets.upload(Uint8List.fromList([1]), fileName: 'a.png', mediaType: 'image/png');
    await data.assets.upload(Uint8List.fromList([2]), fileName: 'b.mp4', mediaType: 'video/mp4');
    await data.assets.upload(Uint8List.fromList([3]), fileName: 'c.gif', mediaType: 'image/gif');
    final first = await data.assets.list(mediaTypePrefix: 'image/', limit: 1);
    expect(first.total, 2); expect(first.hasMore, isTrue); expect(first.offset, 0); expect(first.count, 1);
    final next = await data.assets.list(mediaTypePrefix: 'image/', limit: 1, offset: 1);
    expect(next.data.single.id, image.id); expect(next.hasMore, isFalse);
    expect(first.data.single.toJson().containsKey('content'), isFalse);
    await data.assets.remove(image.id);
    expect((await data.assets.list()).total, 2);
  });

  test('资源提交中断后恢复内容/索引/幂等状态，不生成第二个资源', () async {
    final files = <String, String>{};
    final identity = '${root.path}-memory';
    final first = AboutmeData.withPersistence(_Memory(files, identity, failPath: 'assets/index.json'));
    addTearDown(first.dispose);
    final events = <DataChangeEvent>[];
    final subscription = first.events.listen(events.add); addTearDown(subscription.cancel);
    final command = {'content': 'AAEC', 'fileName': 'x.bin', 'mediaType': 'application/octet-stream',
      'clientMutationId': 'one'};
    expect((await first.call('assets', 'upload', command))['success'], isFalse);
    expect(files.containsKey('.sdk/pending.json'), isTrue); expect(events, isEmpty);
    final restored = AboutmeData.withPersistence(_Memory(files, identity));
    addTearDown(restored.dispose);
    final replay = await restored.call('assets', 'upload', command);
    expect(replay['success'], isTrue);
    expect((await restored.assets.list()).total, 1);
    expect(await restored.assets.read(replay['data']['id'] as String), [0, 1, 2]);
    expect(files.containsKey('.sdk/pending.json'), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(events.single.source, 'recovery');
  });

  test('同一会话物化合并请求，SDK 销毁释放路径，新实例不复用', () async {
    final asset = await data.assets.upload(Uint8List.fromList([1]), fileName: 'a.png');
    final paths = await Future.wait([data.assets.resolvePath(asset.id), data.assets.resolvePath(asset.id)]);
    expect(paths[0], paths[1]);
    expect(data.assets.referenceForResolvedPath(paths[0]), asset.reference);
    await data.dispose(); expect(await File(paths[0]).exists(), isFalse);
    final other = AboutmeData.local(root.path); addTearDown(other.dispose);
    final newPath = await other.assets.resolvePath(asset.id);
    expect(newPath, isNot(paths[0]));
    expect(await File(newPath).readAsBytes(), [1]);
  });
}

class _Memory implements PluginPersistence {
  _Memory(this.files, this.identity, {this.failPath});
  final Map<String, String> files;
  @override
  final String identity;
  final String? failPath;
  @override
  Future<String?> read(String path) async => files[path];
  @override
  Future<void> write(String path, String content) async {
    if (path == failPath) throw StateError('injected interruption');
    files[path] = content;
  }
  @override
  Future<bool> remove(String path) async => files.remove(path) != null;
  @override
  Future<List<String>> keys(String prefix) async => files.keys.where((path) => path.startsWith(prefix)).toList();
}
