import 'dart:convert';
import 'dart:typed_data';

import 'package:aboutme/core/storage/http_storage.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {

  test('validates remote configuration and requires HTTPS', () {
    expect(
      () =>
          const StorageBackendConfig(
            type: StorageBackendType.http,
            serverUrl: 'http://remote.example',
            credential: 'token',
          ).validate(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () =>
          const StorageBackendConfig(
            type: StorageBackendType.http,
            serverUrl: 'https://remote.example',
            credential: 'token',
          ).validate(),
      returnsNormally,
    );
  });

  test('明文传输：写入与读取内容一致', () async {
    Uint8List? stored;
    var etag = '"v1"';
    final client = MockClient((request) async {
      if (request.method == 'HEAD') return http.Response('', 404);
      if (request.method == 'PUT') {
        expect(request.headers['If-None-Match'], '*');
        stored = request.bodyBytes;
        expect(utf8.decode(stored!), 'private text');
        return http.Response('', 200, headers: {'etag': etag});
      }
      if (request.method == 'GET') {
        return http.Response.bytes(stored!, 200, headers: {'etag': etag});
      }
      throw StateError('unexpected ${request.method}');
    });
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.jwt,
      credential: 'token',
      client: client,
    );

    await storage.writeString('notes/data.json', 'private text');
    expect(await storage.readString('notes/data.json'), 'private text');
  });

  test('conditional write: If-None-Match for new, If-Match for known version', () async {
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
      client: client,
    );

    await storage.writeBytes('data.bin', Uint8List.fromList([1]));
    expect(putHeaders.single['If-None-Match'], '*');

    await storage.readBytes('data.bin'); // 缓存 etag
    await storage.writeBytes('data.bin', Uint8List.fromList([2]));
    expect(putHeaders.last['If-Match'], '"v2"');
    expect(putHeaders.last.containsKey('If-None-Match'), isFalse);
  });

  test('reports offline and authentication failures explicitly', () async {
    final unauthorized = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.jwt,
      credential: 'bad',
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
}
