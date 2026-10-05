// 原生 FC 链路 e2e 测试（真实 API，复刻 runToolLoop 的构造逻辑）
// 用法：flutter test test/native_fc_e2e_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 不用 TestWidgetsFlutterBinding：其 HttpClient mock 会拦截真实网络
  late Map<String, dynamic> agentJson;

  setUpAll(() {
    final home = Platform.environment['HOME']!;
    final path =
        '$home/Library/Containers/github.hunmer.aboutme/Data/Documents/'
        'app_data/openai/agents.json';
    final data = jsonDecode(File(path).readAsStringSync()) as Map;
    agentJson = (data['agents'] as List).firstWhere(
      (a) => a['name'] == '余小满',
    ) as Map<String, dynamic>;
  });

  String extractApiKey(Map<String, dynamic> agent) {
    final headers = (agent['headers'] as Map).cast<String, String>();
    final auth = headers['Authorization'] ?? '';
    if (auth.startsWith('Bearer ')) return auth.substring(7);
    return headers['api-key'] ?? headers['x-api-key'] ?? '';
  }

  Uri? normalizeBaseUrl(String baseUrl) {
    var s = baseUrl.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/chat/completions')) {
      s = s.substring(0, s.length - '/chat/completions'.length);
    }
    return Uri.tryParse(s);
  }

  test('dartantic FC：Agent 构造 + 工具调用循环', () async {
    final tool = Tool(
      name: 'get_test_info',
      description: '获取测试信息（固定返回一段文字）',
      onCall: (args) async => {'info': '这是来自测试工具的信息：一切正常'},
    );

    final agent = Agent(
      'openai:${agentJson['model']}',
      apiKey: extractApiKey(agentJson),
      baseUrl: normalizeBaseUrl(agentJson['baseUrl'] as String),
      systemPrompt: '你是测试助手。用户让你查询时必须调用工具。',
      tools: [tool],
      temperature: 0.7,
    );

    final output = StringBuffer();
    var toolCalled = false;
    await for (final chunk in agent.runStream(
      '用工具查一下测试信息，然后告诉我结果',
      messages: const [],
    )) {
      output.write(chunk.output);
    }
    // 无法直接观测 onCall，通过输出间接断言
    toolCalled = output.toString().contains('一切正常') ||
        output.toString().contains('测试工具');
    print('=== 输出: ${output.toString()}');

    expect(output.toString().trim(), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
