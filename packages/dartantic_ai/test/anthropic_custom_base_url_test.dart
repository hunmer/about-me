import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  test('AnthropicProvider sends requests to its configured base URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    Uri? requestUri;
    server.listen((request) async {
      requestUri = request.uri;
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('text', 'event-stream')
        ..write(
          _event('message_start', {
            'type': 'message_start',
            'message': {
              'id': 'msg_test',
              'type': 'message',
              'role': 'assistant',
              'content': <Object>[],
              'model': 'claude-test',
              'usage': {'input_tokens': 1, 'output_tokens': 0},
            },
          }),
        )
        ..write(
          _event('content_block_start', {
            'type': 'content_block_start',
            'index': 0,
            'content_block': {'type': 'text', 'text': ''},
          }),
        )
        ..write(
          _event('content_block_delta', {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': 'ok'},
          }),
        )
        ..write(
          _event('content_block_stop', {
            'type': 'content_block_stop',
            'index': 0,
          }),
        )
        ..write(
          _event('message_delta', {
            'type': 'message_delta',
            'delta': {'stop_reason': 'end_turn'},
            'usage': {'output_tokens': 1},
          }),
        )
        ..write(_event('message_stop', {'type': 'message_stop'}));
      await request.response.close();
    });

    final agent = Agent.forProvider(
      AnthropicProvider(
        apiKey: 'test-key',
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/custom-prefix/v1'),
      ),
      chatModelName: 'claude-test',
    );

    final result = await agent.send('hello');

    expect(result.output, contains('ok'));
    expect(requestUri?.path, '/custom-prefix/v1/messages');
  });
}

String _event(String type, Map<String, Object?> payload) =>
    'event: $type\ndata: ${jsonEncode(payload)}\n\n';
