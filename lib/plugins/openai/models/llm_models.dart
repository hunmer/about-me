class LLMModel {
  final String id;
  final String name;
  final String group;

  /// 能力信息（来源 models.dev）；内置列表与旧缓存可能缺失，null 表示未知
  final bool? supportsVision;
  final bool? supportsReasoning;
  final int? contextLimit;

  const LLMModel({
    required this.id,
    required this.name,
    required this.group,
    this.supportsVision,
    this.supportsReasoning,
    this.contextLimit,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'group': group,
    if (supportsVision != null) 'supportsVision': supportsVision,
    if (supportsReasoning != null) 'supportsReasoning': supportsReasoning,
    if (contextLimit != null) 'contextLimit': contextLimit,
  };

  factory LLMModel.fromJson(Map<String, dynamic> json) => LLMModel(
    id: json['id'] as String,
    name: json['name'] as String,
    group: json['group'] as String,
    supportsVision: json['supportsVision'] as bool?,
    supportsReasoning: json['supportsReasoning'] as bool?,
    contextLimit: (json['contextLimit'] as num?)?.toInt(),
  );

  /// 用远端数据补齐本地缺失的能力字段
  LLMModel withCapabilitiesFrom(LLMModel other) => LLMModel(
    id: id,
    name: name,
    group: group,
    supportsVision: supportsVision ?? other.supportsVision,
    supportsReasoning: supportsReasoning ?? other.supportsReasoning,
    contextLimit: contextLimit ?? other.contextLimit,
  );
}

class LLMModelGroup {
  final String id;
  final String name;
  final List<LLMModel> models;

  const LLMModelGroup({
    required this.id,
    required this.name,
    required this.models,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'models': models.map((e) => e.toJson()).toList(),
  };

  factory LLMModelGroup.fromJson(Map<String, dynamic> json) => LLMModelGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    models:
        (json['models'] as List)
            .map((e) => LLMModel.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
}

// 预定义的大模型列表（数据来源: https://models.dev）
final llmModelGroups = [
  LLMModelGroup(
    id: 'deepseek',
    name: 'DeepSeek',
    models: [
      LLMModel(
        id: 'deepseek-v4-pro',
        name: 'DeepSeek V4 Pro',
        group: 'deepseek',
      ),
      LLMModel(
        id: 'deepseek-v4-flash',
        name: 'DeepSeek V4 Flash',
        group: 'deepseek',
      ),
      LLMModel(
        id: 'deepseek-flash',
        name: 'DeepSeek V4.1 Flash',
        group: 'deepseek',
      ),
      LLMModel(
        id: 'deepseek-v4-flash-vision-exp',
        name: 'DeepSeek V4 Flash Vision Exp',
        group: 'deepseek',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'qwen',
    name: 'Qwen 开源模型',
    models: [
      LLMModel(
        id: 'qwen3.5-397b-a17b',
        name: 'Qwen3.5 397B-A17B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-coder-480b-a35b-instruct',
        name: 'Qwen3 Coder 480B-A35B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-235b-a22b',
        name: 'Qwen3 235B-A22B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-vl-235b-a22b',
        name: 'Qwen3-VL 235B-A22B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-next-80b-a3b-instruct',
        name: 'Qwen3-Next 80B-A3B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-32b',
        name: 'Qwen3 32B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-14b',
        name: 'Qwen3 14B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen3-8b',
        name: 'Qwen3 8B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen2-5-72b-instruct',
        name: 'Qwen2.5 72B',
        group: 'qwen',
      ),
      LLMModel(
        id: 'qwen2-5-coder-32b-instruct',
        name: 'Qwen2.5 Coder 32B',
        group: 'qwen',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'meta',
    name: 'Meta',
    models: [
      LLMModel(
        id: 'muse-wonder-1.0',
        name: 'Muse Wonder',
        group: 'meta',
      ),
      LLMModel(
        id: 'muse-spark-1.3',
        name: 'Muse Spark 1.3',
        group: 'meta',
      ),
      LLMModel(
        id: 'muse-spark-1.2',
        name: 'Muse Spark 1.2',
        group: 'meta',
      ),
      LLMModel(
        id: 'llama-4-maverick-17b-128e-instruct-fp8',
        name: 'Llama 4 Maverick',
        group: 'meta',
      ),
      LLMModel(
        id: 'llama-4-scout-17b-16e-instruct-fp8',
        name: 'Llama 4 Scout',
        group: 'meta',
      ),
      LLMModel(
        id: 'llama-3.3-70b-instruct',
        name: 'Llama 3.3 70B',
        group: 'meta',
      ),
      LLMModel(
        id: 'llama-3.3-8b-instruct',
        name: 'Llama 3.3 8B',
        group: 'meta',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'mistral',
    name: 'Mistral AI',
    models: [
      LLMModel(
        id: 'mistral-large-4',
        name: 'Mistral Large 4',
        group: 'mistral',
      ),
      LLMModel(
        id: 'mistral-large-latest',
        name: 'Mistral Large (latest)',
        group: 'mistral',
      ),
      LLMModel(
        id: 'mistral-medium-latest',
        name: 'Mistral Medium (latest)',
        group: 'mistral',
      ),
      LLMModel(
        id: 'mistral-small-latest',
        name: 'Mistral Small (latest)',
        group: 'mistral',
      ),
      LLMModel(
        id: 'devstral-latest',
        name: 'Devstral 2',
        group: 'mistral',
      ),
      LLMModel(
        id: 'codestral-2508',
        name: 'Codestral 25.08',
        group: 'mistral',
      ),
      LLMModel(
        id: 'ministral-14b-2512',
        name: 'Ministral 3 14B',
        group: 'mistral',
      ),
      LLMModel(
        id: 'ministral-8b-2512',
        name: 'Ministral 3 8B',
        group: 'mistral',
      ),
      LLMModel(
        id: 'ministral-3b-2512',
        name: 'Ministral 3 3B',
        group: 'mistral',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'openai',
    name: 'OpenAI',
    models: [
      LLMModel(
        id: 'gpt-6.1-sol',
        name: 'GPT-6.1 Sol',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-6-sol',
        name: 'GPT-6 Sol',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-6-luna',
        name: 'GPT-6 Luna',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-6-astra',
        name: 'GPT-6 Astra',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.6',
        name: 'GPT-5.6',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.5-pro',
        name: 'GPT-5.5 Pro',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.5',
        name: 'GPT-5.5',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.4',
        name: 'GPT-5.4',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.4-mini',
        name: 'GPT-5.4 Mini',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.3-codex',
        name: 'GPT-5.3 Codex',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.2',
        name: 'GPT-5.2',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5.1',
        name: 'GPT-5.1',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-5',
        name: 'GPT-5',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-4o',
        name: 'GPT-4o',
        group: 'openai',
      ),
      LLMModel(
        id: 'gpt-4o-mini',
        name: 'GPT-4o Mini',
        group: 'openai',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'anthropic',
    name: 'Anthropic',
    models: [
      LLMModel(
        id: 'claude-opus-5-5',
        name: 'Claude Opus 5.5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-sonnet-5-5',
        name: 'Claude Sonnet 5.5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-haiku-5-5',
        name: 'Claude Haiku 5.5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-fable-5-1',
        name: 'Claude Fable 5.1',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-opus-5',
        name: 'Claude Opus 5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-sonnet-5',
        name: 'Claude Sonnet 5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-fable-5',
        name: 'Claude Fable 5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-opus-4-8',
        name: 'Claude Opus 4.8',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-opus-4-6',
        name: 'Claude Opus 4.6',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-sonnet-4-6',
        name: 'Claude Sonnet 4.6',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-opus-4-5',
        name: 'Claude Opus 4.5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-sonnet-4-5',
        name: 'Claude Sonnet 4.5',
        group: 'anthropic',
      ),
      LLMModel(
        id: 'claude-haiku-4-5',
        name: 'Claude Haiku 4.5',
        group: 'anthropic',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'google',
    name: 'Google',
    models: [
      LLMModel(
        id: 'gemini-4-argon',
        name: 'Gemini 4 Argon',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.8-flash',
        name: 'Gemini 3.8 Flash',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-flash-latest',
        name: 'Gemini Flash (latest)',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.7-flash',
        name: 'Gemini 3.7 Flash',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.6-flash',
        name: 'Gemini 3.6 Flash',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.5-flash',
        name: 'Gemini 3.5 Flash',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.5-flash-lite',
        name: 'Gemini 3.5 Flash Lite',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.1-flash-lite',
        name: 'Gemini 3.1 Flash Lite',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-3.1-pro-preview',
        name: 'Gemini 3.1 Pro Preview',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-flash-lite-latest',
        name: 'Gemini Flash-Lite (latest)',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-2.5-pro',
        name: 'Gemini 2.5 Pro',
        group: 'google',
      ),
      LLMModel(
        id: 'gemini-2.5-flash',
        name: 'Gemini 2.5 Flash',
        group: 'google',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'zhipu',
    name: '智谱 AI',
    models: [
      LLMModel(
        id: 'glm-5.3',
        name: 'GLM-5.3',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-5.3-flash',
        name: 'GLM-5.3 Flash',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-5.3-flashx',
        name: 'GLM-5.3 FlashX',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-5.2',
        name: 'GLM-5.2',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-5.1',
        name: 'GLM-5.1',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-5',
        name: 'GLM-5',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.7',
        name: 'GLM-4.7',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.7-flash',
        name: 'GLM-4.7 Flash',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.6',
        name: 'GLM-4.6',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.5',
        name: 'GLM-4.5',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.5-air',
        name: 'GLM-4.5 Air',
        group: 'zhipu',
      ),
      LLMModel(
        id: 'glm-4.5-flash',
        name: 'GLM-4.5 Flash',
        group: 'zhipu',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'moonshot',
    name: '月之暗面',
    models: [
      LLMModel(
        id: 'kimi-k3',
        name: 'Kimi K3',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2.7-code',
        name: 'Kimi K2.7 Code',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2.7-code-highspeed',
        name: 'Kimi K2.7 Code HighSpeed',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2.6',
        name: 'Kimi K2.6',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2.5',
        name: 'Kimi K2.5',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2-thinking',
        name: 'Kimi K2 Thinking',
        group: 'moonshot',
      ),
      LLMModel(
        id: 'kimi-k2',
        name: 'Kimi K2',
        group: 'moonshot',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'xfyun',
    name: '讯飞星火',
    models: [
      LLMModel(
        id: 'spark-4.0-turbo',
        name: 'Spark 4.0 Turbo',
        group: 'xfyun',
      ),
      LLMModel(
        id: 'spark-x1',
        name: 'Spark X1',
        group: 'xfyun',
      ),
      LLMModel(
        id: 'spark-multilingual',
        name: 'Spark Multilingual',
        group: 'xfyun',
      ),
      LLMModel(
        id: 'spark-3.5',
        name: 'Spark 3.5',
        group: 'xfyun',
      ),
      LLMModel(
        id: 'spark-lite',
        name: 'Spark Lite',
        group: 'xfyun',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'cohere',
    name: 'Cohere',
    models: [
      LLMModel(
        id: 'command-a-plus-05-2026',
        name: 'Command A Plus (05-2026)',
        group: 'cohere',
      ),
      LLMModel(
        id: 'north-mini-code-1-0',
        name: 'North Mini Code',
        group: 'cohere',
      ),
      LLMModel(
        id: 'command-a-reasoning-08-2025',
        name: 'Command A Reasoning (08-2025)',
        group: 'cohere',
      ),
      LLMModel(
        id: 'command-a-translate-08-2025',
        name: 'Command A Translate (08-2025)',
        group: 'cohere',
      ),
      LLMModel(
        id: 'command-a-vision-07-2025',
        name: 'Command A Vision (07-2025)',
        group: 'cohere',
      ),
      LLMModel(
        id: 'command-a-03-2025',
        name: 'Command A (03-2025)',
        group: 'cohere',
      ),
      LLMModel(
        id: 'command-r7b-12-2024',
        name: 'Command R7B (12-2024)',
        group: 'cohere',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'alibaba-qwen',
    name: '阿里云通义千问',
    models: [
      LLMModel(
        id: 'qwen3.8-max',
        name: 'Qwen3.8 Max',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.8-flash',
        name: 'Qwen3.8 Flash',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.7-max',
        name: 'Qwen3.7 Max',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.7-plus',
        name: 'Qwen3.7 Plus',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.7-flash',
        name: 'Qwen3.7 Flash',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.6-max',
        name: 'Qwen3.6 Max',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.6-plus',
        name: 'Qwen3.6 Plus',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.6-flash',
        name: 'Qwen3.6 Flash',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.5-plus',
        name: 'Qwen3.5 Plus',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3.5-flash',
        name: 'Qwen3.5 Flash',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3-max',
        name: 'Qwen3 Max',
        group: 'alibaba-qwen',
      ),
      LLMModel(
        id: 'qwen3-coder-plus',
        name: 'Qwen3 Coder Plus',
        group: 'alibaba-qwen',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'perplexity',
    name: 'Perplexity',
    models: [
      LLMModel(
        id: 'sonar-reasoning-pro',
        name: 'Sonar Reasoning Pro',
        group: 'perplexity',
      ),
      LLMModel(
        id: 'sonar-pro',
        name: 'Sonar Pro',
        group: 'perplexity',
      ),
      LLMModel(
        id: 'sonar-deep-research',
        name: 'Sonar Deep Research',
        group: 'perplexity',
      ),
      LLMModel(
        id: 'sonar',
        name: 'Sonar',
        group: 'perplexity',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'xai',
    name: 'xAI',
    models: [
      LLMModel(
        id: 'grok-4.7',
        name: 'Grok 4.7',
        group: 'xai',
      ),
      LLMModel(
        id: 'grok-4.6',
        name: 'Grok 4.6',
        group: 'xai',
      ),
      LLMModel(
        id: 'grok-4.5',
        name: 'Grok 4.5',
        group: 'xai',
      ),
      LLMModel(
        id: 'grok-4.3',
        name: 'Grok 4.3',
        group: 'xai',
      ),
      LLMModel(
        id: 'grok-4.20-multi-agent-0309',
        name: 'Grok 4.20 Multi-Agent',
        group: 'xai',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'other',
    name: '其他模型',
    models: [
      LLMModel(
        id: 'gemma-4-31b-it',
        name: 'Gemma 4 31B',
        group: 'other',
      ),
      LLMModel(
        id: 'gemma-4-26b-a4b-it',
        name: 'Gemma 4 26B A4B',
        group: 'other',
      ),
      LLMModel(
        id: 'yi-34b',
        name: 'Yi-34B',
        group: 'other',
      ),
      LLMModel(
        id: 'baichuan2-13b',
        name: 'Baichuan2-13B',
        group: 'other',
      ),
      LLMModel(
        id: 'internlm2-20b',
        name: 'InternLM2-20B',
        group: 'other',
      ),
      LLMModel(
        id: 'phi-3',
        name: 'Phi-3',
        group: 'other',
      ),
    ],
  ),
  LLMModelGroup(
    id: 'minimax',
    name: 'MiniMax',
    models: [
      LLMModel(
        id: 'MiniMax-M3',
        name: 'MiniMax-M3',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M3.1-Flash-Preview',
        name: 'MiniMax-M3.1 Flash Preview',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2.7',
        name: 'MiniMax-M2.7',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2.7-highspeed',
        name: 'MiniMax-M2.7-highspeed',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2.5',
        name: 'MiniMax-M2.5',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2.5-highspeed',
        name: 'MiniMax-M2.5-highspeed',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2.1',
        name: 'MiniMax-M2.1',
        group: 'minimax',
      ),
      LLMModel(
        id: 'MiniMax-M2',
        name: 'MiniMax-M2',
        group: 'minimax',
      ),
    ],
  ),
];
