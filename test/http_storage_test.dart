import 'dart:convert';
import 'dart:typed_data';

import 'package:aboutme/core/storage/http_storage.dart';
import 'package:aboutme/core/storage/storage_backend_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=';

  test('validates remote configuration and requires HTTPS', () {
    expect(
      () =>
          const StorageBackendConfig(
            type: StorageBackendType.http,
            serverUrl: 'http://remote.example',
            credential: 'token',
            encryptionKey: key,
          ).validate(),
      throwsA(isA<FormatException>()),
    );
    expect(
      () =>
          const StorageBackendConfig(
            type: StorageBackendType.http,
            serverUrl: 'https://remote.example',
            credential: 'token',
            encryptionKey: key,
          ).validate(),
      returnsNormally,
    );
  });

  test('encrypts bytes on write and decrypts them on read', () async {
    Uint8List? stored;
    var etag = '"v1"';
    final client = MockClient((request) async {
      if (request.method == 'HEAD') return http.Response('', 404);
      if (request.method == 'PUT') {
        expect(request.headers['X-Force-Overwrite'], 'true');
        stored = request.bodyBytes;
        expect(utf8.decode(stored!), isNot(contains('private text')));
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
      encryptionKey: key,
      client: client,
    );

    await storage.writeString('notes/data.json', 'private text');
    expect(await storage.readString('notes/data.json'), 'private text');
  });

  test('uses force overwrite instead of conditional writes', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'PUT');
      expect(request.headers['X-Force-Overwrite'], 'true');
      expect(request.headers.containsKey('If-Match'), isFalse);
      expect(request.headers.containsKey('If-None-Match'), isFalse);
      return http.Response('', 200, headers: {'etag': '"new"'});
    });
    final storage = HttpStorage(
      serverUrl: 'https://storage.example',
      authType: StorageAuthType.apiKey,
      credential: 'key',
      encryptionKey: key,
      client: client,
    );

    await storage.writeBytes('data.bin', Uint8List.fromList([1, 2, 3]));
    expect(calls, 1);
  });

  test('reports offline and authentication failures explicitly', () async {
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
}
