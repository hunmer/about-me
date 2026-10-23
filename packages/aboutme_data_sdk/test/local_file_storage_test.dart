import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late LocalFileStorage storage;
  const user = 'user-1';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aboutme_sdk_test');
    storage = LocalFileStorage(tempDir.path);
    await storage.initialize();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Uint8List bytes(String s) => Uint8List.fromList(s.codeUnits);

  test('写入/读取/ETag（sha256 hex 双引号包裹）', () async {
    final result = await storage.writeRawFile(
      user,
      'misc/data.json',
      bytes('hello'),
      force: true,
    );
    expect(result.status, RawFileWriteStatus.written);
    // sha256('hello') = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
    expect(
      result.metadata!.etag,
      '"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"',
    );

    final read = await storage.readRawFile(user, 'misc/data.json');
    expect(read, isNotNull);
    expect(String.fromCharCodes(read!.data), 'hello');
  });

  test('If-Match 条件写：版本一致成功、不一致冲突', () async {
    final first = await storage.writeRawFile(
      user,
      'a.json',
      bytes('v1'),
      force: true,
    );
    final etag = first.metadata!.etag;

    final ok = await storage.writeRawFile(
      user,
      'a.json',
      bytes('v2'),
      ifMatch: etag,
    );
    expect(ok.status, RawFileWriteStatus.written);

    final conflict = await storage.writeRawFile(
      user,
      'a.json',
      bytes('v3'),
      ifMatch: etag, // 旧版本 etag
    );
    expect(conflict.status, RawFileWriteStatus.preconditionFailed);
    expect(
      String.fromCharCodes((await storage.readRawFile(user, 'a.json'))!.data),
      'v2',
    );
  });

  test('无条件非强制写始终 precondition_failed（与 nodejs 语义一致）', () async {
    final result = await storage.writeRawFile(user, 'b.json', bytes('x'));
    expect(result.status, RawFileWriteStatus.preconditionFailed);
    expect(await storage.readRawFile(user, 'b.json'), isNull);

    final createNew = await storage.writeRawFile(
      user,
      'b.json',
      bytes('x'),
      ifNoneMatch: '*',
    );
    expect(createNew.status, RawFileWriteStatus.written);
    final duplicate = await storage.writeRawFile(
      user,
      'b.json',
      bytes('y'),
      ifNoneMatch: '*',
    );
    expect(duplicate.status, RawFileWriteStatus.preconditionFailed);
  });

  test('删除：force / If-Match / precondition_failed / not_found', () async {
    final created = await storage.writeRawFile(
      user,
      'c.json',
      bytes('c'),
      force: true,
    );
    final notFound = await storage.deleteRawFile(user, 'missing.json');
    expect(notFound, RawFileDeleteStatus.notFound);

    final conflict = await storage.deleteRawFile(user, 'c.json');
    expect(conflict, RawFileDeleteStatus.preconditionFailed);

    final ok = await storage.deleteRawFile(
      user,
      'c.json',
      ifMatch: created.metadata!.etag,
    );
    expect(ok, RawFileDeleteStatus.deleted);
    expect(await storage.readRawFile(user, 'c.json'), isNull);
  });

  test('列表/前缀过滤/清除', () async {
    await storage.writeRawFile(user, 'misc/1.json', bytes('1'), force: true);
    await storage.writeRawFile(user, 'misc/2.json', bytes('2'), force: true);
    await storage.writeRawFile(user, 'other/3.json', bytes('3'), force: true);

    final all = await storage.listRawFiles(user);
    expect(all.map((e) => e.path), ['misc/1.json', 'misc/2.json', 'other/3.json']);

    final todo = await storage.listRawFiles(user, prefix: 'misc/');
    expect(todo.map((e) => e.path), ['misc/1.json', 'misc/2.json']);

    final deleted = await storage.clearRawFiles(user, 'misc/');
    expect(deleted, 2);
    expect((await storage.listRawFiles(user)).length, 1);

    expect(
      () => storage.clearRawFiles(user, ''),
      throwsA(isA<StorageException>().having((e) => e.statusCode, 'status', 426)),
    );
  });

  test('路径穿越/绝对路径/反斜杠一律拒绝', () {
    expect(
      () => storage.resolveStoragePath(user, '../escape.json'),
      throwsA(isA<StoragePathException>()),
    );
    expect(
      () => storage.resolveStoragePath(user, 'a/../../escape.json'),
      throwsA(isA<StoragePathException>()),
    );
    expect(
      () => storage.resolveStoragePath(user, '/etc/passwd'),
      throwsA(isA<StoragePathException>()),
    );
    expect(
      () => storage.resolveStoragePath(user, 'a\\b.json'),
      throwsA(isA<StoragePathException>()),
    );
    expect(
      () => storage.resolveStoragePath(user, ''),
      throwsA(isA<StoragePathException>()),
    );
    expect(
      () => storage.resolveStoragePath(user, 'a//b.json'),
      throwsA(isA<StoragePathException>()),
    );
  });

  test('统一数据区布局：users/{id}（无 .storage 前缀）', () async {
    await storage.writeRawFile(user, 'x.json', bytes('x'), force: true);
    final expected = p.join(
      tempDir.path,
      'users',
      user,
      'x.json',
    );
    expect(await File(expected).exists(), isTrue);
  });

  test('审计日志写入', () async {
    await storage.logStorageAudit(
      userId: user,
      action: 'force-overwrite',
      filePath: 'x.json',
      details: 'test',
    );
    final log = File(p.join(tempDir.path, 'logs', 'storage_audit.log'));
    expect(await log.exists(), isTrue);
    expect((await log.readAsString()).contains('force-overwrite'), isTrue);
  });
}
