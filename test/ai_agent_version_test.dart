import 'dart:convert';

import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> legacyAgentJson() => {
    'id': 'agent',
    'name': '助手',
    'description': '',
    'serviceProviderId': 'provider',
    'baseUrl': 'https://example.com',
    'headers': <String, String>{},
    'model': 'model',
  };

  test('旧 Agent 无版本时可加载和保存', () {
    final agent = AIAgent.fromJson(legacyAgentJson());
    expect(agent.version, isNull);
    expect(agent.toJson().containsKey('version'), isFalse);
  });

  test('升级版本可持久化，后续编辑保留版本及连接配置', () {
    final agent = AIAgent.fromJson(legacyAgentJson());
    final updated = agent.copyWith(version: 1);
    final restored = AIAgent.fromJson(
      jsonDecode(jsonEncode(updated.toJson())) as Map<String, dynamic>,
    );
    final edited = restored.copyWith(name: '新名称');

    expect(edited.version, 1);
    expect(edited.baseUrl, agent.baseUrl);
    expect(edited.serviceProviderId, agent.serviceProviderId);
    expect(edited.model, agent.model);
    expect(edited.copyWith(version: 2).version, 2);
  });
}
