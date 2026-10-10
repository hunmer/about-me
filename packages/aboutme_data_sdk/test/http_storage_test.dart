import 'dart:convert';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

  test('写入加密、读取解密，X-Device-ID 取全局默认值', () async {
    Uint8List? stored;
    var etag = '"v1"';
    final client = MockClient((request) async {
      if (request.method == 'HEAD') return http.Response('', 404);
      if (request.method == 'PUT') {
        expect(request.headers['If-None-Match'], '*');
        expect(request.headers['X-Device-ID'], 'device-x');
        stored = request.bodyBytes;
        expect(utf8.decode(stored!), isNot(contains('private text')));
        return http.Response('', 200, headers: {'etag': etag});
      }
      if (request.method == 'GET') {
        return http.Response.bytes(stored!, 200, headers: {'etag': etag});
      }
      throw StateError('unexpected ${request.method}');
    });
    HttpStorageDefaults.deviceId = 'device-x';
    addTearDown(() => HttpStorageDefaults.deviceId = '');
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.jwt,
      credential: 'token',
      encryptionKey: key,
      client: client,
    );

    await storage.writeString('notes/data.json', 'private text');
    expect(await storage.readString('notes/data.json'), 'private text');
  });

  test('条件写：新文件用 If-None-Match，已知版本用 If-Match', () async {
    final putHeaders = <Map<String, String>>[];
    var serverEtag = '"v2"';
    Uint8List? stored;
    final client = MockClient((request) async {
      switch (request.method) {
        case 'PUT':
          putHeaders.add(Map.of(request.headers));
          stored = request.bodyBytes;
          return http.Response('', 200, headers: {'etag': serverEtag});
        case 'GET':
          if (stored == null) return http.Response('', 404);
          return http.Response.bytes(stored!, 200, headers: {'etag': serverEtag});
        default:
          throw StateError('unexpected ${request.method}');
      }
    });
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.apiKey,
      credential: 'key',
      encryptionKey: key,
      client: client,
    );

    await storage.writeBytes('data.bin', Uint8List.fromList([1]));
    expect(putHeaders.single['If-None-Match'], '*');

    await storage.readBytes('data.bin'); // 缓存 etag "v2"
    await storage.writeBytes('data.bin', Uint8List.fromList([2]));
    expect(putHeaders.last['If-Match'], '"v2"');
    expect(putHeaders.last.containsKey('If-None-Match'), isFalse);
  });

  test('条件写冲突：刷新版本重试一次，二次冲突回退强制覆盖', () async {
    final putIfMatchHeaders = <String?>[];
    var putCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 200, headers: {'etag': '"server-v9"'});
      }
      if (request.method == 'PUT') {
        putIfMatchHeaders.add(request.headers['If-Match']);
        putCalls++;
        if (putCalls <= 2) {
          return http.Response('', 412, headers: {'etag': '"server-v9"'});
        }
        return http.Response('', 200, headers: {'etag': '"final"'});
      }
      throw StateError('unexpected ${request.method}');
    });
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.apiKey,
      credential: 'key',
      encryptionKey: key,
      client: client,
    );

    await storage.writeBytes('retry.bin', Uint8List.fromList([1]));
    // If-None-Match/* 冲突 → HEAD 刷新 → If-Match 重试仍冲突 → 强制覆盖成功
    expect(putIfMatchHeaders.length, 3);
    expect(putIfMatchHeaders[0], isNull);
    expect(putIfMatchHeaders[1], '"server-v9"');
    expect(putIfMatchHeaders[2], isNull);
  });

  test('writeBytesIfCurrent 严格模式：冲突直接抛异常', () async {
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        return http.Response('', 412);
      }
      return http.Response('', 200);
    });
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.apiKey,
      credential: 'key',
      encryptionKey: key,
      client: client,
    );

    await expectLater(
      storage.writeBytesIfCurrent('strict.bin', Uint8List.fromList([1])),
      throwsA(
        isA<StorageException>().having(
          (e) => e.kind,
          'kind',
          StorageErrorKind.conflict,
        ),
      ),
    );
  });

  test('离线与认证失败显式报错', () async {
    final unauthorized = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.jwt,
      credential: 'bad',
      encryptionKey: key,
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      unauthorized.testConnection(),
      throwsA(
        isA<StorageException>().having(
          (error) => error.kind,
          'kind',
          StorageErrorKind.unauthorized,
        ),
      ),
    );

    final offline = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.jwt,
      credential: 'token',
      encryptionKey: key,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.testConnection(),
      throwsA(
        isA<StorageException>().having(
          (error) => error.kind,
          'kind',
          StorageErrorKind.offline,
        ),
      ),
    );
  });

  test('配置校验：远端必须 HTTPS（本机 HTTP 例外）', () {
    expect(
      () => const StorageBackendConfig(
        type: StorageBackendType.http,
        serverUrl: 'http://remote.example',
        credential: 'token',
        encryptionKey: key,
      ).validate(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => const StorageBackendConfig(
        type: StorageBackendType.http,
        serverUrl: 'https://remote.example',
        credential: 'token',
        encryptionKey: key,
      ).validate(),
      returnsNormally,
    );
    expect(
      () => const StorageBackendConfig(
        type: StorageBackendType.http,
        serverUrl: 'http://127.0.0.1:8874',
        credential: 'token',
        encryptionKey: key,
      ).validate(),
      returnsNormally,
    );
  });
}
