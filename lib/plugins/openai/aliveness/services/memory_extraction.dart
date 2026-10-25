import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import '../models/memory_fragment.dart';

/// 单次提取的只读检索会话。仅索引和分页命中结果进入模型上下文。
class MemoryExtraction {
  MemoryExtraction(this.fragments);

  final List<MemoryFragment> fragments;
  static const categories = [
    'profile',
    'preference',
    'relationship',
    'plan',
    'experience',
    'commitment',
    'other',
  ];
  final searched = <String>{};
  final retrievedIds = <String>{};
  bool indexRead = false;
  int toolCalls = 0;

  Map<String, dynamic> index() {
    indexRead = true;
    return {
      'categories': categories,
      'index': [
        for (final subject in ['user', 'self'])
          for (final category in categories) _categoryEntry(subject, category),
      ],
      'note': '旧记忆归入 other。检索候选分类后，也要在 other 中按关键词查重。',
    };
  }

  Map<String, dynamic> _categoryEntry(String subject, String category) {
    final matches = fragments.where(
      (f) => f.isSelf == (subject == 'self') && f.category == category,
    );
    final tags = <String, int>{};
    for (final f in matches) {
      for (final tag in f.tags) {
        tags[tag] = (tags[tag] ?? 0) + 1;
      }
    }
    final ranked = tags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'subject': subject,
      'category': category,
      'count': matches.length,
      'tags': ranked.take(12).map((e) => e.key).toList(),
    };
  }

  Map<String, dynamic> search(Map<String, dynamic> args) {
    if (!indexRead) return {'error': '请先调用 list_memory_categories 查看索引'};
    final subject = args['subject'] as String?;
    final category = args['category'] as String?;
    if (!['user', 'self'].contains(subject) || !categories.contains(category)) {
      return {'error': 'subject 或 category 无效'};
    }
    final hasKey = args.containsKey('key');
    final rawKey = args['key'] as String?;
    final exactKey = rawKey?.trim();
    if (hasKey && (exactKey == null || exactKey.isEmpty)) {
      return {'error': 'key 不能为空'};
    }
    final query = (args['query'] as String? ?? '').trim().toLowerCase();
    final terms = query.split(RegExp(r'\s+')).where((q) => q.isNotEmpty);
    final page = ((args['page'] as num?)?.toInt() ?? 0).clamp(0, 1000);
    final matches = fragments.where((f) {
      if (f.isSelf != (subject == 'self') || f.category != category) {
        return false;
      }
      // 精确 key 是封闭查询：未命中时返回空，不能回退到 query 或分类浏览。
      if (exactKey != null) return f.key == exactKey;
      final text = '${f.key} ${f.value} ${f.tags.join(' ')}'.toLowerCase();
      return terms.isEmpty || terms.any(text.contains);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    searched.add('$subject:$category');
    final hits = matches.skip(page * 5).take(5).toList();
    retrievedIds.addAll(hits.map((f) => f.id));
    debugPrint(
      '[Aliveness][记忆检索] subject=$subject category=$category '
      '${exactKey == null ? 'query=$query' : 'key=$exactKey'} '
      'page=$page hits=${hits.length}/${matches.length}',
    );
    return {
      'total': matches.length,
      'hasMore': (page + 1) * 5 < matches.length,
      'memories': hits
          .map(
            (f) => {
              // 保留 content 供旧调用方读取，同时以 key/value 为新协议。
              ...f.toJson(),
              'id': f.id,
              'key': f.key,
              'value': f.value,
              'content': f.content,
              'subject': subject,
            },
          )
          .toList(),
    };
  }

  bool canWrite(String subject, String category) =>
      indexRead &&
      searched.contains('$subject:$category') &&
      searched.contains('$subject:other');

  Future<String> run(AIAgent agent, String prompt) async {
    final tools = [
      Tool<Map<String, dynamic>>(
        name: 'list_memory_categories',
        description: '先查看用户/自我记忆的分类计数和关键词索引，不返回记忆正文。',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': <String, Object?>{},
        }),
        onCall: (_) async {
          toolCalls++;
          final result = index();
          debugPrint('[Aliveness][记忆检索] 已读取分类索引 | 碎片=${fragments.length}');
          return result;
        },
      ),
      Tool<Map<String, dynamic>>(
        name: 'search_memories',
        description:
            '按主体、分类、关键词或精确 key 检索（含归档），每页最多5条。'
            'query 留空浏览分类；关键词空格分隔，任一命中。提供 key 时只返回该 key，未命中不回退；其他不匹配返回空。',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': {
            'subject': {
              'type': 'string',
              'enum': ['user', 'self'],
            },
            'category': {'type': 'string', 'enum': categories},
            'key': {'type': 'string'},
            'query': {'type': 'string'},
            'page': {'type': 'integer', 'minimum': 0},
          },
          'required': ['subject', 'category'],
        }),
        onCall: (args) async {
          toolCalls++;
          return search(args);
        },
      ),
    ];
    final headers = {
      for (final e in agent.headers.entries) e.key.toLowerCase(): e.value,
    };
    final apiKey = (headers['authorization'] ?? '').replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    final key = apiKey.isNotEmpty
        ? apiKey
        : headers['x-api-key'] ?? headers['api-key'] ?? '';
    final base = agent.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final isAnthropic = agent.apiFormat.toLowerCase() == 'anthropic';
    final Provider provider = isAnthropic
        ? AnthropicProvider(
            apiKey: key,
            baseUrl: Uri.parse(base),
            headers: agent.headers,
          )
        : AppOpenAIProvider(
            apiKey: key,
            baseUrl: Uri.parse(
              base.replaceFirst(RegExp(r'/chat/completions$'), ''),
            ),
            headers: agent.headers,
          );
    final extractor = Agent.forProvider(
      provider,
      chatModelName: agent.model,
      tools: tools,
      temperature: 0,
      chatModelOptions: isAnthropic
          ? const AnthropicChatOptions(maxTokens: 8000)
          : const OpenAIChatOptions(maxTokens: 8000),
    );
    final output = StringBuffer();
    String? finalText;
    await for (final chunk in extractor.sendStream(prompt)) {
      if (toolCalls > 16) throw StateError('记忆检索超过16次，本轮提取跳过');
      if (chunk.output.isNotEmpty) output.write(chunk.output);
      for (final message in chunk.messages) {
        if (message.role != ChatMessageRole.model) continue;
        final text = message.parts
            .whereType<TextPart>()
            .map((p) => p.text)
            .join();
        if (text.trim().isNotEmpty) finalText = text;
      }
    }
    if (!indexRead) throw StateError('提取 Agent 未读取分类索引，本轮提取跳过');
    return (finalText ?? output.toString()).trim();
  }
}
