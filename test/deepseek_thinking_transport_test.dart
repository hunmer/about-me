import 'dart:convert';
import 'dart:io';

import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final enabled in [true, false]) {
    test('普通聊天传递 thinking=$enabled 并分离思考和正文', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? body;
      server.listen((request) async {
        body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        for (final delta in [
          if (enabled) {'reasoning_content': '先计算'},
          if (enabled) {'reasoning_content': '再核对', 'content': '391'},
          if (!enabled) {'content': '391'},
        ]) {
          request.response.write(
            'data: ${jsonEncode({
              'choices': [
                {'delta': delta},
              ],
            })}\n\n',
          );
        }
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      final thinking = StringBuffer();
      final output = StringBuffer();
      final errors = <String>[];
      var completed = false;
      await RequestService.streamResponse(
        agent: AIAgent(
          id: 'test',
          name: 'test',
          description: '',
          tags: const [],
          serviceProviderId: 'deepseek',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          headers: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          model: 'deepseek-flash',
          enableThinking: enabled,
        ),
        prompt: '计算17*23',
        onToken: output.write,
        onThinking: thinking.write,
        onError: errors.add,
        onComplete: () => completed = true,
      );
      expect(errors, isEmpty);
      expect(completed, isTrue);
      expect(body?['thinking'], {'type': enabled ? 'enabled' : 'disabled'});
      expect(body?.containsKey('extra_body'), isFalse);
      expect(thinking.toString(), enabled ? '先计算再核对' : '');
      expect(output.toString(), '391');
    });
  }

  test('原生 Provider 显式关闭覆盖默认开启', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    Map<String, dynamic>? body;
    server.listen((request) async {
      body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'id': 'test',
          'object': 'chat.completion.chunk',
          'created': 0,
          'model': 'deepseek-flash',
          'choices': [
            {
              'index': 0,
              'delta': {'role': 'assistant', 'content': '391'},
              'finish_reason': 'stop',
            },
          ],
        })}\n\ndata: [DONE]\n\n',
      );
      await request.response.close();
    });
    final agent = Agent.forProvider(
      AppOpenAIProvider(
        apiKey: 'test',
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1'),
      ),
      chatModelName: 'deepseek-flash',
      enableThinking: false,
    );
    final output = StringBuffer();
    await for (final chunk in agent.sendStream('计算17*23')) {
      output.write(chunk.output);
    }
    expect(body?['thinking'], {'type': 'disabled'});
    expect(output.toString(), '391');
  });

  test('网络异常不会重发未适配的原始请求', () async {
    var requests = 0;
    final client = DeepSeekCompatClient(
      MockClient((request) async {
        requests++;
        throw http.ClientException('offline');
      }),
      disableThinking: false,
    );
    addTearDown(client.close);
    await expectLater(
      client.send(
        http.Request('POST', Uri.parse('https://example.test/chat/completions'))
          ..body = '{"messages":[]}',
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(requests, 1);
  });
}
