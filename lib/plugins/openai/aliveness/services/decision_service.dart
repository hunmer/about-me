import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';

import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/chat/models/message.dart';

/// 回复策略（Jev Choice 选项，与注入指令一一对应）
enum ReplyStrategy { minimal, normal, detailed, shiftTopic }

/// 一次缓冲结束后的全部决策（PRD 5.6.2 决策问题集）
class DecisionResult {
  final bool shouldReplyNow;
  final int delaySeconds;
  final ReplyStrategy strategy;
  final bool useVoice;
  final bool shiftTopic;
  final double userEmotion; // -1 ~ 1
  final String? exploreQuestion; // 适合抛出的偏好探索问题（null = 不探索）
  final String source; // 'jev' | 'rules'
  final Map<String, dynamic> rawAnswers;

  const DecisionResult({
    required this.shouldReplyNow,
    required this.delaySeconds,
    required this.strategy,
    required this.useVoice,
    required this.shiftTopic,
    required this.userEmotion,
    this.exploreQuestion,
    required this.source,
    this.rawAnswers = const {},
  });
}

/// 决策层：优先 Jev（System One）一次调用并行决策；失败/低置信/超时 → 本地规则。
/// Jev 不生成任何文本，只有需要自然语言时才由上层调主 LLM。
class DecisionService {
  DecisionService._();
  static final DecisionService instance = DecisionService._();

  final _store = AlivenessStore.instance;
  final _rng = Random();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(milliseconds: 1500),
    receiveTimeout: const Duration(milliseconds: 1500),
    sendTimeout: const Duration(milliseconds: 1500),
  ));

  Future<DecisionResult> decide({
    required String agentId,
    required AgentState state,
    required List<Message> bufferedMessages,
    required AlivenessConfig config,
    List<String> unaskedQuestions = const [],
    DateTime? lastExploreAt,
  }) async {
    final fallback = _ruleBasedDecision(
      state,
      bufferedMessages,
      config,
      unaskedQuestions: unaskedQuestions,
      lastExploreAt: lastExploreAt,
    );
    try {
      final settings = await _store.loadSettings();
      final apiKey = settings['jevApiKey'] as String?;
      if (apiKey == null || apiKey.isEmpty) return fallback;

      final jevResult = await _callJev(
        baseUrl: settings['jevBaseUrl'] as String? ??
            'https://api.typesafe.ai/v1/systemone',
        apiKey: apiKey,
        model: settings['jevModel'] as String? ?? 'jev-latest',
        threshold:
            (settings['confidenceThreshold'] as num?)?.toDouble() ?? 0.65,
        state: state,
        bufferedMessages: bufferedMessages,
        config: config,
        unaskedQuestions: unaskedQuestions,
      );
      return jevResult ?? fallback;
    } catch (e) {
      developer.log('Jev 决策失败，使用本地规则: $e', name: 'DecisionService');
      return fallback;
    }
  }

  // ---------- Jev REST 调用 ----------

  Future<DecisionResult?> _callJev({
    required String baseUrl,
    required String apiKey,
    required String model,
    required double threshold,
    required AgentState state,
    required List<Message> bufferedMessages,
    required AlivenessConfig config,
    List<String> unaskedQuestions = const [],
  }) async {
    final stateMap = _buildState(state, bufferedMessages);
    final exploreOptions = unaskedQuestions.take(6).toList();
    final response = await _dio.post<Map<String, dynamic>>(
      baseUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      // 请求格式遵循官方文档 docs.typesafe.ai：
      // state 为字符串；问题字段为 instructions；choice 的 criteria 为选项描述映射；
      // score 的 criteria 为等级描述数组；noul 仅需 instructions。
      data: {
        'model': model,
        'state': const JsonEncoder.withIndent('  ').convert(stateMap),
        'questions': {
          'should_reply_now': {
            'type': 'noul',
            'instructions': '缓冲结束后，角色是否应立即生成回复？'
                '（用户在等待回应；闲聊结尾或客套话可以不回）',
          },
          'delay_seconds': {
            'type': 'choice',
            'instructions': '建议延迟多少秒再发送回复？（模拟思考、犹豫、忙）',
            'criteria': {
              '0': '立即发送',
              '15': '短暂思考后发送',
              '45': '思考一会儿再发送',
              '120': '有忙碌感，稍后回复',
              '300': '很久之后才回复',
            },
          },
          'reply_strategy': {
            'type': 'choice',
            'instructions': '应采用哪种回复策略？',
            'criteria': {
              '极简': '一两句话的极简回应，适合疲惫、闲聊或不重要话题',
              '正常': '正常聊天长度，1到3句',
              '详细': '详细认真回应，展现在乎',
              '主动转移': '接住话后主动转移到新话题',
            },
          },
          'should_shift_topic': {
            'type': 'noul',
            'instructions': '当前是否适合由角色主动转移话题？',
          },
          'use_voice': {
            'type': 'noul',
            'instructions': '这条回复是否适合以语音而非文字形式发送？',
          },
          'user_emotion': {
            'type': 'score',
            'instructions': '用户当前情绪效价',
            'criteria': ['非常负面', '负面', '中性', '正面', '非常正面'],
          },
          if (exploreOptions.isNotEmpty) ...{
            'should_explore_preference': {
              'type': 'noul',
              'instructions': '当前是否适合自然地向用户抛出一个了解喜好的问题？',
            },
            'explore_question': {
              'type': 'choice',
              'instructions': '若要探索用户偏好，选哪个问题最合适当前氛围？',
              'criteria': {
                for (final q in exploreOptions) q: q,
                '不探索': '当前不适合探索，保持自然聊天',
              },
            },
          },
        },
      },
    );

    final body = response.data;
    if (body == null) return null;
    final answers = body['answers'] as Map<String, dynamic>?;
    if (answers == null || answers.isEmpty) return null;

    // ---- 解析各决策项，任何一项置信度不足则该项退回保守值 ----
    final shouldReplyNow =
        _readNoul(answers['should_reply_now']) > 0.35 || answers.isEmpty;

    final delayRaw = _readChoice(answers['delay_seconds'], threshold);
    final delaySeconds = int.tryParse(delayRaw ?? '0') ?? 0;

    final strategyRaw = _readChoice(answers['reply_strategy'], threshold);
    final strategy = switch (strategyRaw) {
      '极简' => ReplyStrategy.minimal,
      '详细' => ReplyStrategy.detailed,
      '主动转移' => ReplyStrategy.shiftTopic,
      _ => ReplyStrategy.normal,
    };

    // 语音默认关闭（Phase 4 才执行语音，此处仅记录决策）
    final useVoice =
        config.voiceEnabled && _readNoul(answers['use_voice']) > 0.6;

    final shiftTopic = _readNoul(answers['should_shift_topic']) > 0.55;

    final emotionScore = _readScore(answers['user_emotion']);

    // 偏好探索：两个问题都命中且不是"不探索"才采纳
    String? exploreQuestion;
    if (exploreOptions.isNotEmpty &&
        _readNoul(answers['should_explore_preference']) > 0.55) {
      final picked = _readChoice(answers['explore_question'], threshold);
      if (picked != null &&
          picked != '不探索' &&
          exploreOptions.contains(picked)) {
        exploreQuestion = picked;
      }
    }

    return DecisionResult(
      shouldReplyNow: shouldReplyNow,
      delaySeconds: delaySeconds.clamp(0, 300),
      strategy: strategy,
      useVoice: useVoice,
      shiftTopic: shiftTopic,
      userEmotion: emotionScore,
      exploreQuestion: exploreQuestion,
      source: 'jev',
      rawAnswers: Map<String, dynamic>.from(answers),
    );
  }

  Map<String, dynamic> _buildState(AgentState state, List<Message> messages) {
    final now = DateTime.now();
    return {
      'user_messages_buffer': messages.map((m) => m.content).toList(),
      'character_energy': state.energy,
      'intimacy_level': state.intimacy,
      'current_mood': state.mood > 0.2
          ? 'positive'
          : (state.mood < -0.2 ? 'low' : 'neutral'),
      'character_description': state.describe(),
      'time_of_day':
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'hours_since_last_interaction':
          state.lastInteractionAt == null
              ? null
              : now.difference(state.lastInteractionAt!).inHours,
    };
  }

  // ---------- 响应解析（对字段形状保持宽容） ----------

  double _readNoul(dynamic answer) {
    if (answer is! Map) return 0.5;
    final noul = answer['noul'] ?? answer['probability'] ?? answer['value'];
    return (noul is num) ? noul.toDouble().clamp(0.0, 1.0) : 0.5;
  }

  String? _readChoice(dynamic answer, double threshold) {
    if (answer is! Map) return null;
    final confidence = (answer['confidence'] as num?)?.toDouble() ?? 0.0;
    final choice = answer['choice'] as String?;
    if (choice == null) return null;
    // 低置信 → 返回 null，由调用方落到保守值
    return confidence >= threshold ? choice : null;
  }

  /// score 返回 0~N-1 的索引（配 legend 映射），归一化到 -1~1
  double _readScore(dynamic answer) {
    if (answer is! Map) return 0.0;
    final legend = answer['legend'] as Map?;
    final levels =
        legend != null && legend.isNotEmpty ? legend.length : 5;
    final score = answer['score'];
    if (score is num) {
      return ((score.toDouble() / (levels - 1)) * 2 - 1).clamp(-1.0, 1.0);
    }
    return switch (score as String?) {
      '非常负面' => -1.0,
      '负面' => -0.5,
      '正面' => 0.5,
      '非常正面' => 1.0,
      _ => 0.0,
    };
  }

  // ---------- 本地规则 fallback（无 Jev 也可用，保守取向） ----------

  DecisionResult _ruleBasedDecision(
    AgentState state,
    List<Message> messages,
    AlivenessConfig config, {
    List<String> unaskedQuestions = const [],
    DateTime? lastExploreAt,
  }) {
    final totalLength = messages.fold<int>(0, (sum, m) => sum + m.content.length);
    final complex = totalLength > 50 || messages.length >= 3;

    // 是否回复：低能量且低亲密度时可以"已读不回"一轮，但亲密度高时始终回复
    final shouldReply = state.energy > 0.3 || state.intimacy > 0.6 || complex;

    // 延迟：惰性高且消息复杂 → 思考一会儿；普通 → 立即
    final delay = (config.laziness > 0.5 && complex)
        ? (state.energy < 0.4 ? 45 : 15)
        : 0;

    // 策略：能量低 → 极简；用户连发多条 → 详细；其余 → 正常
    final strategy =
        state.energy < 0.35 && !complex
            ? ReplyStrategy.minimal
            : messages.length >= 3
            ? ReplyStrategy.detailed
            : ReplyStrategy.normal;

    // 偏好探索：关系够近、距上次探索超 1 天、还有未问的问题时，小概率探索
    String? exploreQuestion;
    final exploreAllowed =
        state.intimacy > 0.3 &&
        unaskedQuestions.isNotEmpty &&
        (lastExploreAt == null ||
            DateTime.now().difference(lastExploreAt).inHours >= 24);
    if (exploreAllowed && _rng.nextDouble() < 0.2) {
      exploreQuestion = unaskedQuestions.first;
    }

    return DecisionResult(
      shouldReplyNow: shouldReply,
      delaySeconds: delay,
      strategy: strategy,
      useVoice: false,
      shiftTopic: false,
      userEmotion: 0.0,
      exploreQuestion: exploreQuestion,
      source: 'rules',
    );
  }
}
