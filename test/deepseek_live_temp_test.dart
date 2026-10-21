import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';

void main() {
  test('DeepSeek actual provider reasoning', () async {
    final data = jsonDecode(File('C:/Users/Administrator/Documents/app_data/openai/agents.json').readAsStringSync()) as Map;
    final config = (data['agents'] as List).cast<Map>().firstWhere((a) => a['serviceProviderId'] == 'deepseek');
    final agent = Agent.forProvider(AppOpenAIProvider(apiKey: config['headers']['api-key'] as String, baseUrl: Uri.parse(config['baseUrl'] as String)), chatModelName: config['model'] as String, enableThinking: true);
    var thinking = 0;
    var output = 0;
    await for (final chunk in agent.sendStream('计算17*23，只回复结果。')) {
      thinking += chunk.thinking?.length ?? 0;
      output += chunk.output.length;
    }
    print('DeepSeek SDK model=${config['model']} thinking=$thinking output=$output');
    expect(thinking, greaterThan(0));
    expect(output, greaterThan(0));
  }, timeout: const Timeout(Duration(seconds: 90)));
}
