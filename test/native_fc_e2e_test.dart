// 原生 FC 链路 e2e 测试（真实 DeepSeek API，含 thinking 模式兼容验证）
// 用法：flutter test test/native_fc_e2e_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';

void main() {
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

  Uri normalizeBaseUrl(String baseUrl) {
    var s = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (s.endsWith('/chat/completions')) {
      s = s.substring(0, s.length - '/chat/completions'.length);
    }
    return Uri.parse(s);
  }

  test('deepseek-flash thinking 兼容 + 工具调用多轮循环', () async {
    final agent = Agent.forProvider(
      AppOpenAIProvider(
        apiKey: extractApiKey(agentJson),
        baseUrl: normalizeBaseUrl(agentJson['baseUrl'] as String),
      ),
      chatModelName: agentJson['model'] as String,
      tools: [
        Tool<Map<String, dynamic>>(
          name: 'get_test_info',
          description: '获取测试信息（固定返回一段文字）',
          inputSchema: Schema.fromMap(<String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
            'required': <String>[],
          }),
          onCall: (args) async => {'info': '这是来自测试工具的信息：一切正常'},
        ),
      ],
      temperature: 0.7,
    );

    final output = StringBuffer();
    await for (final chunk in agent.sendStream(
      '先调用工具查询测试信息，再用一句话告诉我结果',
      history: const [],
    )) {
      output.write(chunk.output);
    }
    print('=== 输出: ${output.toString()}');

    // 若工具循环未被执行或 thinking 400，输出为空或抛异常
    expect(output.toString().trim(), isNotEmpty);
    expect(
      output.toString().contains('一切正常') || output.toString().contains('正常'),
      isTrue,
      reason: '工具结果应出现在最终回复中',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
