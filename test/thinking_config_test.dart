import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/models/thinking_effort.dart';
import 'package:aboutme/plugins/openai/services/thinking_config.dart';
import 'package:flutter_test/flutter_test.dart';

AIAgent agent(
  String model, {
  ThinkingEffort effort = ThinkingEffort.medium,
  bool enabled = true,
}) => AIAgent(
  id: 'test',
  name: 'test',
  description: '',
  tags: const [],
  serviceProviderId: 'custom',
  baseUrl: 'https://example.com/v1',
  headers: const {},
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  model: model,
  thinkingEffort: effort,
  enableThinking: enabled,
);

void main() {
  test('旧配置默认 Medium，等级可序列化并随 copyWith 保留', () {
    final json = agent('gpt-5.2', effort: ThinkingEffort.galaxy).toJson();
    expect(
      AIAgent.fromJson(json).copyWith(name: 'copy').thinkingEffort,
      ThinkingEffort.galaxy,
    );
    json.remove('thinkingEffort');
    expect(AIAgent.fromJson(json).thinkingEffort, ThinkingEffort.medium);
    json['thinkingEffort'] = 'unknown';
    expect(AIAgent.fromJson(json).thinkingEffort, ThinkingEffort.medium);
  });

  test('OpenAI 高档位按模型上限映射', () {
    for (final entry in {
      'o3': 'high',
      'gpt-5': 'high',
      'gpt-5.2': 'xhigh',
      'openai/gpt-6-astra': 'max',
    }.entries) {
      expect(
        ThinkingConfig.openAI(
          agent(entry.key, effort: ThinkingEffort.galaxy),
        )['reasoning_effort'],
        entry.value,
      );
    }
    expect(
      ThinkingConfig.openAI(
        agent('gpt-5.4-pro', effort: ThinkingEffort.low),
      )['reasoning_effort'],
      'medium',
    );
  });

  test('未知模型及固定推理模型不发送不支持的参数', () {
    for (final model in [
      'gpt-4o',
      'custom-model',
      'o1-mini',
      'gpt-5.2-chat-latest',
      'gpt-5-pro',
    ]) {
      expect(ThinkingConfig.openAI(agent(model)), isEmpty, reason: model);
    }
  });

  test('关闭思考使用模型支持的值', () {
    expect(ThinkingConfig.openAI(agent('gpt-5', enabled: false)), {
      'reasoning_effort': 'minimal',
    });
    expect(ThinkingConfig.openAI(agent('gpt-5.2', enabled: false)), {
      'reasoning_effort': 'none',
    });
    expect(
      ThinkingConfig.openAI(agent('gpt-6-astra', enabled: false)),
      isEmpty,
    );
    expect(ThinkingConfig.openAI(agent('o3', enabled: false)), isEmpty);
  });

  test('DeepSeek Flash 仅发送 low/high/max，旧模型仅发送开关', () {
    final efforts = [
      for (final effort in ThinkingEffort.values)
        ThinkingConfig.openAI(
          agent('deepseek-flash', effort: effort),
        )['reasoning_effort'],
    ];
    expect(efforts, ['low', 'high', 'high', 'high', 'max', 'max']);
    expect(ThinkingConfig.openAI(agent('deepseek-flash', enabled: false)), {
      'thinking': {'type': 'disabled'},
    });
    expect(ThinkingConfig.openAI(agent('deepseek-chat')), {
      'thinking': {'type': 'enabled'},
    });
    expect(
      ThinkingConfig.usesOpenAIReasoning(agent('deepseek-flash')),
      isFalse,
    );
    expect(ThinkingConfig.usesOpenAIReasoning(agent('gpt-5.2')), isTrue);
  });

  test('Claude 自适应思考使用支持的 effort', () {
    expect(
      ThinkingConfig.anthropic(
        agent('claude-opus-4-6', effort: ThinkingEffort.extra),
        2000,
      ),
      {
        'thinking': {'type': 'adaptive'},
        'output_config': {'effort': 'max'},
      },
    );
    expect(
      ThinkingConfig.anthropic(
        agent('claude-opus-4-7', effort: ThinkingEffort.extra),
        2000,
      )['output_config'],
      {'effort': 'xhigh'},
    );
    expect(
      ThinkingConfig.anthropic(
        agent('claude-opus-4-5', effort: ThinkingEffort.galaxy),
        2000,
      ),
      {
        'thinking': {'type': 'enabled', 'budget_tokens': 1999},
        'output_config': {'effort': 'high'},
      },
    );
    expect(
      ThinkingConfig.anthropic(
        agent('claude-sonnet-4-6', enabled: false),
        2000,
      ),
      {
        'thinking': {'type': 'disabled'},
      },
    );
  });

  test('旧 Claude 预算小于输出上限，不给不支持的模型添加参数', () {
    final old = agent('claude-sonnet-4-5', effort: ThinkingEffort.galaxy);
    expect(ThinkingConfig.anthropic(old, 2000)['thinking'], {
      'type': 'enabled',
      'budget_tokens': 1999,
    });
    expect(ThinkingConfig.anthropic(old, 1024), isEmpty);
    expect(
      ThinkingConfig.anthropic(
        agent('claude-sonnet-4-20250514'),
        2000,
      )['thinking'],
      {'type': 'enabled', 'budget_tokens': 1999},
    );
    expect(
      ThinkingConfig.anthropic(old.copyWith(enableThinking: false), 2000),
      isEmpty,
    );
    expect(ThinkingConfig.anthropic(agent('claude-3-5-sonnet'), 2000), isEmpty);
  });
}
