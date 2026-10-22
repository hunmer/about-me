import '../models/ai_agent.dart';

/// 将 UI 档位限制到模型实际支持的范围；未知模型不添加推理参数。
class ThinkingConfig {
  static Map<String, dynamic> openAI(AIAgent agent) {
    final model = agent.model.toLowerCase().split('/').last;
    final index = agent.thinkingEffort.index;
    final isDeepSeek =
        agent.serviceProviderId == 'deepseek' ||
        Uri.tryParse(agent.baseUrl)?.host.contains('deepseek') == true ||
        model.startsWith('deepseek-');
    if (isDeepSeek) {
      // V4 / Flash 支持 low / high / max；旧版只保留原有思考开关。
      final supportsEffort =
          model.startsWith('deepseek-v4') || model == 'deepseek-flash';
      return {
        'thinking': {'type': agent.enableThinking ? 'enabled' : 'disabled'},
        if (agent.enableThinking && supportsEffort)
          'reasoning_effort': index == 0
              ? 'low'
              : index < 4
              ? 'high'
              : 'max',
      };
    }

    final gpt = RegExp(r'^gpt-(\d+)(?:\.(\d+))?(?:-|$)').firstMatch(model);
    final major = int.tryParse(gpt?.group(1) ?? '') ?? 0;
    final minor = int.tryParse(gpt?.group(2) ?? '') ?? 0;
    final isOModel = RegExp(r'^o[134](?:-|$)').hasMatch(model);
    if (major < 5 && !isOModel ||
        model.contains('chat-latest') ||
        model.startsWith('o1-preview') ||
        model.startsWith('o1-mini')) {
      return {};
    }
    // ChatGPT 别名及早期固定 effort 的 pro 模型不能接收任意等级。
    if (model.contains('-pro') && major == 5 && minor < 4) return {};
    if (model.contains('-pro') &&
        major == 5 &&
        index == 0 &&
        agent.enableThinking) {
      return {'reasoning_effort': 'medium'};
    }
    if (!agent.enableThinking) {
      if (major == 5 && !model.contains('-pro')) {
        return {'reasoning_effort': minor == 0 ? 'minimal' : 'none'};
      }
      // o 系列 / GPT-6 不支持关闭推理，不发送不合法的 none。
      return {};
    }
    final supportsXhigh = major >= 6 || major == 5 && minor >= 2;
    final effort = index == 0
        ? 'low'
        : index == 1
        ? 'medium'
        : index == 2
        ? 'high'
        : index >= 4 && major >= 6
        ? 'max'
        : supportsXhigh
        ? 'xhigh'
        : 'high';
    return {'reasoning_effort': effort};
  }

  static bool usesOpenAIReasoning(AIAgent agent) {
    final config = openAI(agent);
    return config.containsKey('reasoning_effort') &&
        !config.containsKey('thinking');
  }

  static Map<String, dynamic> anthropic(AIAgent agent, int maxTokens) {
    final model = agent.model.toLowerCase();
    final version = RegExp(
      r'claude-(opus|sonnet|haiku)-(\d+)(?:[-.](\d)(?=-|$))?',
    ).firstMatch(model);
    final major = int.tryParse(version?.group(2) ?? '') ?? 0;
    final minor = int.tryParse(version?.group(3) ?? '') ?? 0;
    final family = version?.group(1);
    final adaptive =
        major >= 5 ||
        major == 4 && minor >= 6 && (family == 'opus' || family == 'sonnet');
    final effortOnly = family == 'opus' && major == 4 && minor == 5;
    if (!agent.enableThinking) {
      return {
        if (adaptive || effortOnly) 'thinking': {'type': 'disabled'},
      };
    }
    if (adaptive || effortOnly) {
      final index = agent.thinkingEffort.index;
      final effort = index == 0
          ? 'low'
          : index == 1
          ? 'medium'
          : index == 2 || effortOnly
          ? 'high'
          : index == 3 && (major >= 5 || minor >= 7)
          ? 'xhigh'
          : 'max';
      return {
        if (adaptive) 'thinking': {'type': 'adaptive'},
        if (effortOnly && maxTokens > 1024)
          'thinking': {
            'type': 'enabled',
            'budget_tokens': _budget(agent, maxTokens),
          },
        'output_config': {'effort': effort},
      };
    }
    // 旧版 Claude 使用预算，必须至少 1024 且严格小于 max_tokens。
    final supportsBudget =
        model.contains('claude-3-7-sonnet') ||
        major == 4 &&
            (family == 'opus' || family == 'sonnet' || family == 'haiku');
    if (!supportsBudget || maxTokens <= 1024) return {};
    return {
      'thinking': {
        'type': 'enabled',
        'budget_tokens': _budget(agent, maxTokens),
      },
    };
  }

  static int _budget(AIAgent agent, int maxTokens) {
    const budgets = [1024, 2048, 4096, 8192, 16384, 32768];
    return budgets[agent.thinkingEffort.index].clamp(1024, maxTokens - 1);
  }
}
