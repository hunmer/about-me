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
    expect(jsonDecode(request.body).containsKey('temperature'), isFalse);
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

  test(
    'reasoning requests omit sampling and preserve effort and token limits',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = AgentLibClient(
        baseUrl: 'https://example.test/v1',
        headers: const {},
        httpClient: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            request.body.contains('"stream":true')
                ? 'data: [DONE]\n\n'
                : '{"choices":[{"message":{"content":"ok"}}]}',
            200,
          );
        }),
      );
      const extra = {
        'reasoning_effort': 'xhigh',
        'max_completion_tokens': 2000,
      };
      await client.complete(
        model: 'gpt-5.2',
        messages: const [],
        extraBody: extra,
      );
      await client
          .stream(model: 'gpt-5.2', messages: const [], extraBody: extra)
          .toList();
      for (final body in bodies) {
        expect(body['reasoning_effort'], 'xhigh');
        expect(body['max_completion_tokens'], 2000);
        expect(body.containsKey('max_tokens'), isFalse);
        expect(body.containsKey('temperature'), isFalse);
      }
    },
  );

  test('complete sends thinking at the top level only when provided', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = AgentLibClient(
      baseUrl: 'https://example.test/v1',
      headers: const {},
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"choices":[{"message":{"content":"ok"}}]}', 200);
      }),
    );
    await client.complete(model: 'demo', messages: const []);
    await client.complete(
      model: 'demo',
      messages: const [],
      extraBody: {
        'thinking': {'type': 'disabled'},
      },
    );
    expect(bodies.first.containsKey('thinking'), isFalse);
    expect(bodies.last['thinking'], {'type': 'disabled'});
    expect(bodies.last.containsKey('extra_body'), isFalse);
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
