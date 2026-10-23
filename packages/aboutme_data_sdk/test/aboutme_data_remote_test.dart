import 'dart:convert';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('远程文件不存在时返回 JSON 默认值或空文本', () async {
    final data = AboutmeData.remote(
      serverUrl: 'https://storage.example',
      apiKey: 'test',
      client: MockClient((_) async => http.Response('', 404)),
    );
    expect(await data.readPath('diary/diary_index.json'), {});
    expect(await data.readPath('bill/accounts.json', {'accounts': []}), {
      'accounts': [],
    });
    expect(await data.readPath('habits/habits.json', []), []);
    expect(await data.readPathText('day/memorial_days.json'), '');
  });

  test('远程文件读写保留 JSON 和原始文本语义', () async {
    final files = <String, String>{};
    final data = AboutmeData.remote(
      serverUrl: 'https://storage.example',
      apiKey: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'PUT') {
          files[path] = request.body;
          return http.Response('', 200);
        }
        return http.Response(
          files[path] ?? '',
          files.containsKey(path) ? 200 : 404,
        );
      }),
    );
    await data.writePath('legacy/index.json', {'2026-10-23': {}});
    expect(await data.readPath('legacy/index.json'), {'2026-10-23': {}});
    await data.writePath(
      'day/memorial_days.json',
      jsonEncode([
        {'id': 'sample'},
      ]),
    );
    expect(await data.readPath('day/memorial_days.json'), [
      {'id': 'sample'},
    ]);
    expect(
      await data.readPathText('day/memorial_days.json'),
      '[{"id":"sample"}]',
    );
    await data.writePath('empty.json', '');
    await expectLater(data.readPath('empty.json', []),
      throwsA(isA<StorageException>().having((error) => error.kind, 'kind', StorageErrorKind.invalidData)));
    await data.writePath('invalid.json', 'invalid json');
    await expectLater(data.readPath('invalid.json', []),
      throwsA(isA<StorageException>().having((error) => error.kind, 'kind', StorageErrorKind.invalidData)));
  });

  for (final status in [401, 500]) {
    test('HTTP $status 仍抛错，避免把认证或服务故障误判为空数据', () async {
      final data = AboutmeData.remote(
        serverUrl: 'https://storage.example',
        apiKey: 'test',
        client: MockClient((_) async => http.Response('', status)),
      );
      expect(
        data.readPath('diary/diary_index.json'),
        throwsA(isA<StorageException>()),
      );
      expect(
        data.readPathText('day/memorial_days.json'),
        throwsA(isA<StorageException>()),
      );
    });
  }
}
