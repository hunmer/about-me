import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 活人感端到端验收（真实 API）：
/// Jev 决策 → DeepSeek 按决策生成 → 分条校验 → 记忆提取。
/// 验证的正是 app 内 DecisionService/Orchestrator 使用的相同请求格式。
void main() {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
  ));

  const jevKey =
      'apikey_278601a56a42a0a4d298d52e2fb5000158c_a1817949613f48c69a84066214f77c352fadf41f0e332a2f0fcfd1a900392409';
  const deepseekKey = 'sk-b921c679a1c644ad8d824a869307a482';

  test('E2E：疲惫倾诉场景 → Jev 决策 → DeepSeek 活人感生成', () async {
    // ---- 1) Jev 决策（官方格式：state 字符串 + instructions + criteria）----
    final stateText = 'user_messages_buffer: ["最近好累啊", "工作压力好大"]\n'
        'character_energy: 0.45\n'
        'intimacy_level: 0.72\n'
        'current_mood: low\n'
        'time_of_day: ${DateTime.now().hour}:${DateTime.now().minute}\n'
        'recent_memory_summary: 用户上周提到加班很多';
    final jevResp = await dio.post<Map<String, dynamic>>(
      'https://api.typesafe.ai/v1/systemone',
      options: Options(headers: {'Authorization': 'Bearer $jevKey'}),
      data: {
        'model': 'jev-latest',
        'state': stateText,
        'questions': {
          'should_reply_now': {
            'type': 'noul',
            'instructions': '缓冲结束后，角色是否应立即生成回复？（用户在等待回应；闲聊结尾或客套话可以不回）',
          },
          'delay_seconds': {
            'type': 'choice',
            'instructions': '建议延迟多少秒再发送回复？（模拟思考、犹豫、忙）',
            'criteria': {
              '0': '立即发送', '15': '短暂思考后发送', '45': '思考一会儿再发送',
              '120': '有忙碌感，稍后回复', '300': '很久之后才回复',
            },
          },
          'reply_strategy': {
            'type': 'choice',
            'instructions': '应采用哪种回复策略？',
            'criteria': {
              '极简': '一两句话的极简回应，适合疲惫、闲聊或不起眼的话题',
              '正常': '正常聊天长度，1到3句',
              '详细': '详细认真回应，展现在乎',
              '主动转移': '接住话后主动转移到新话题',
            },
          },
          'user_emotion': {
            'type': 'score',
            'instructions': '用户当前情绪效价',
            'criteria': ['非常负面', '负面', '中性', '正面', '非常正面'],
          },
        },
      },
    );

    final answers = jevResp.data!['answers'] as Map<String, dynamic>;
    final replyNoul =
        (answers['should_reply_now'] as Map)['noul'] as num;
    final delayAnswer = answers['delay_seconds'] as Map;
    final strategyAnswer = answers['reply_strategy'] as Map;
    final emotionAnswer = answers['user_emotion'] as Map;

    // 决策解析（与 app 内 DecisionService 相同规则）
    final threshold = 0.65;
    final delayConfidence =
        (delayAnswer['confidence'] as num?)?.toDouble() ?? 0.0;
    final delaySeconds =
        (delayConfidence >= threshold
            ? int.tryParse(delayAnswer['choice'] as String? ?? '0') ?? 0
            : 0);
    final strategyConfidence =
        (strategyAnswer['confidence'] as num?)?.toDouble() ?? 0.0;
    final strategy =
        strategyConfidence >= threshold
        ? strategyAnswer['choice'] as String
        : '正常';
    // score 索引归一化到 -1~1（legend 5 级）
    final legendLen = (emotionAnswer['legend'] as Map?)?.length ?? 5;
    final emotionScore =
        (((emotionAnswer['score'] as num).toDouble() / (legendLen - 1)) * 2 - 1)
            .clamp(-1.0, 1.0);

    // 倾诉疲惫场景：应建议回复、情绪应偏负面
    expect(replyNoul, greaterThan(0.3), reason: '用户在倾诉，应建议回复');
    expect(emotionScore, lessThan(-0.1), reason: '"好累压力大"应判为负面情绪');

    // ---- 2) DeepSeek 按决策注入生成（活人感 prompt 同 app 内 _buildContext）----
    final strategyInstruction = switch (strategy) {
      '极简' => '用一句极简的话回应（20字以内），像真人随手回一条消息。',
      '详细' => '认真详细地回应对方，展现你在乎，但保持聊天口吻。',
      '主动转移' => '先简短接住对方的话，再自然转移到新话题。',
      _ => '用自然聊天口吻回复，1~3句话，像真人发消息那样说话。',
    };
    final system = '你是一个陪伴型AI角色"小满"，和用户是亲近的朋友。\n'
        '【你当前的状态】有点累，心情低落，与用户关系非常亲近。'
        '你的回复节奏和语气要符合这个状态。\n'
        '【你想起的关于用户的往事】\n· 用户上周提到加班很多\n'
        '【回复方式】$strategyInstruction\n'
        '绝不使用列表、标题或客服用语。';

    final llmResp = await dio.post<Map<String, dynamic>>(
      'https://api.deepseek.com/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $deepseekKey'}),
      data: {
        'model': 'deepseek-flash',
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': '最近好累啊\n工作压力好大'},
        ],
        'max_tokens': 800,
      },
    );
    final replyText =
        (llmResp.data!['choices'][0] as Map)['message'] as Map;
    final content = (replyText['content'] as String).trim();
    // ignore: avoid_print
    print('── Jev 决策：reply=$replyNoul, delay=${delaySeconds}s(conf $delayConfidence), '
        'strategy=$strategy(conf $strategyConfidence), emotion=$emotionScore');
    // ignore: avoid_print
    print('── DeepSeek 生成：$content');

    expect(content, isNotEmpty);
    expect(content.length, lessThan(300), reason: '聊天式回复不应过长');
    expect(content.contains('#'), isFalse, reason: '不应出现 markdown 标题');

    // ---- 3) 记忆提取（同 app 内 extractFromConversation 的 prompt）----
    final extractResp = await dio.post<Map<String, dynamic>>(
      'https://api.deepseek.com/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $deepseekKey'}),
      data: {
        'model': 'deepseek-flash',
        'messages': [
          {
            'role': 'user',
            'content':
                '从下面这轮对话中提取值得长期记住的用户信息。\n'
                '只输出 JSON，格式：\n'
                '{"memories":[{"content":"一句话事实","tags":["关键词"],"emotion":"neutral|positive|negative","importance":0.0到1.0}],"openLoops":[{"description":"待跟进事件","days":跟进天数}]}\n'
                '规则：只记关于用户的事实/偏好/计划，最多3条memories；没有值得记的输出 {"memories":[],"openLoops":[]}；'
                'openLoops 只收未来1~7天内可跟进的事，最多1条。\n'
                '对话：\n用户：最近好累啊，工作压力好大，而且天天加班\n你：$content',
          },
        ],
        // deepseek-flash 为推理模型，reasoning 也消耗 token，需给足预算
        'max_tokens': 2500,
      },
    );
    final extractContent =
        (((extractResp.data!['choices'][0] as Map)['message'] as Map)['content'] as String)
            .trim();
    final jsonStart = extractContent.indexOf('{');
    final jsonEnd = extractContent.lastIndexOf('}');
    expect(jsonStart, greaterThanOrEqualTo(0), reason: '应输出 JSON');
    final extracted = extractContent.substring(jsonStart, jsonEnd + 1);
    // ignore: avoid_print
    print('── 记忆提取：$extracted');
    final memories = ((extracted.isEmpty
            ? <String, dynamic>{}
            : extractJson(extracted))['memories'] as List?)
        ?.cast<Map>();
    expect(memories, isNotEmpty, reason: '加班信息应被提取为记忆');
    final joined = memories!.map((m) => m['content']).join();
    expect(joined.contains('加班') || joined.contains('累') || joined.contains('压力'),
        isTrue, reason: '记忆内容应与工作压力相关');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('E2E：闲聊场景 → 决策应允许非"详细"策略', () async {
    final jevResp = await dio.post<Map<String, dynamic>>(
      'https://api.typesafe.ai/v1/systemone',
      options: Options(headers: {'Authorization': 'Bearer $jevKey'}),
      data: {
        'model': 'jev-latest',
        'state':
            'user_messages_buffer: ["哈哈", "好的好的"]\ncharacter_energy: 0.3\n'
            'intimacy_level: 0.75\ncurrent_mood: neutral\ntime_of_day: 14:30',
        'questions': {
          'reply_strategy': {
            'type': 'choice',
            'instructions': '应采用哪种回复策略？',
            'criteria': {
              '极简': '一两句话的极简回应，适合疲惫、闲聊或不起眼的话题',
              '正常': '正常聊天长度，1到3句',
              '详细': '详细认真回应，展现在乎',
              '主动转移': '接住话后主动转移到新话题',
            },
          },
          'should_reply_now': {
            'type': 'noul',
            'instructions': '缓冲结束后，角色是否应立即生成回复？（用户在等待回应；闲聊结尾或客套话可以不回）',
          },
        },
      },
    );
    final answers = jevResp.data!['answers'] as Map<String, dynamic>;
    // ignore: avoid_print
    print('── 闲聊决策：${answers['reply_strategy']} / ${answers['should_reply_now']}');
    // 闲聊"哈哈好的"：详细策略的概率不应占绝对主导（校准合理性检查）
    final probs =
        (answers['reply_strategy'] as Map)['probabilities'] as Map;
    final detailed = (probs['详细'] as num?)?.toDouble() ?? 0.0;
    expect(detailed, lessThan(0.8), reason: '闲聊不应倾向详细长回复');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

dynamic extractJson(String text) {
  // 复用 app 内 _extractJson 的宽容解析
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return <String, dynamic>{};
  try {
    return jsonDecode(text.substring(start, end + 1));
  } catch (_) {
    return <String, dynamic>{};
  }
}
