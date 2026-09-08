import 'dart:convert';

import 'package:agentlib/agentlib.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('complete sends auth and returns content', () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'ok'},
            },
          ],
        }),
        200,
      );
    });

    final result = await AgentLibClient(
      baseUrl: 'https://example.test/v1/',
      headers: const {'Authorization': 'Bearer token'},
      httpClient: client,
    ).complete(model: 'demo', messages: const []);

    expect(result, 'ok');
    expect(request.url.path, '/v1/chat/completions');
    expect(request.headers['authorization'], 'Bearer token');
    expect(jsonDecode(request.body)['model'], 'demo');
  });

  test('stream parses SSE deltas and ignores DONE', () async {
    final client = MockClient(
      (_) async => http.Response(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'A'},
            },
          ],
        })}\n\n'
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'B'},
            },
          ],
        })}\n\n'
        'data: [DONE]\n\n',
        200,
        headers: const {'content-type': 'text/event-stream'},
      ),
    );

    final result =
        await AgentLibClient(
          baseUrl: 'https://example.test/v1',
          headers: const {},
          httpClient: client,
        ).stream(model: 'demo', messages: const []).toList();

    expect(result, ['A', 'B']);
  });

  test('non-success responses expose status and body', () async {
    final client = MockClient((_) async => http.Response('bad', 401));
    expect(
      () => AgentLibClient(
        baseUrl: 'https://example.test/v1',
        headers: const {},
        httpClient: client,
      ).complete(model: 'demo', messages: const []),
      throwsA(isA<AgentLibException>()),
    );
  });

  test('stream can be cancelled by the consumer', () async {
    final client = MockClient(
      (_) async => http.Response(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'A'},
            },
          ],
        })}\n\n'
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'B'},
            },
          ],
        })}\n\n',
        200,
      ),
    );
    final values =
        await AgentLibClient(
          baseUrl: 'https://example.test/v1',
          headers: const {},
          httpClient: client,
        ).stream(model: 'demo', messages: const []).take(1).toList();
    expect(values, ['A']);
  });
}
