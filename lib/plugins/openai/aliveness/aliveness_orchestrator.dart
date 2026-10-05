import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/decision_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/state_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

/// 生成输入：编排器把缓冲合并文本与注入段交给宿主通道，
/// 通道用自己的 AI 聊天链路（chat 流式 / agent_chat executeChain）完成生成。
class AlivenessGenerationInput {
  final String mergedText; // 缓冲期合并后的用户输入
  final String systemSuffix; // 活人感注入段（状态/记忆/策略/格式）
  final bool useVoice; // 本轮决策以语音呈现（流式展示可按需关闭）
  final List<Object> bufferedHandles; // 宿主原始消息对象（chat: Message；agent_chat: 空）

  const AlivenessGenerationInput({
    required this.mergedText,
    required this.systemSuffix,
    required this.useVoice,
    this.bufferedHandles = const [],
  });
}

/// 活人感会话通道：宿主（chat 频道 / agent_chat 会话）实现本接口，
/// 编排器通过它读写宿主自己的消息体系。生命周期 = 一次缓冲
/// （首条消息入队 → flush 完成），由 [AlivenessOrchestrator] 创建与持有。
abstract class AlivenessSessionChannel {
  /// 决策日志中的来源标识（'chat' / 'agent_chat'）
  String get scope;

  /// 缓冲开始（chat：创建"正在想…"占位消息；agent_chat：无占位，标题态由宿主管理）
  Future<void> onBufferStart();

  /// 本轮无回复（已读不回 / 生成内容为空），宿主收尾清理
  Future<void> onNoReply();

  /// 决策延迟开始（占位/标题保持等待态）
  Future<void> onDelay(int seconds);

  /// 生成回复：走宿主自己的 AI 聊天链路，返回完整回复文本（空/失败返回 null）
  Future<String?> generate(AlivenessGenerationInput input);

  /// 以语音形式发布（替代文本）；失败返回 false，编排器回退分条文本
  Future<bool> sendVoice(String text);

  /// 分条发布文本（chat：逐条延迟落库；agent_chat：删除重建一次性揭示）
  Future<void> sendBubbles(List<String> bubbles);

  /// 本轮处理收尾（agent_chat：关隐藏窗口；chat：刷新界面）
  void reveal();

  /// 编排失败兜底（chat：占位消息标错；agent_chat：关窗并复位输入中状态）
  Future<void> onError(Object error);
}

/// 一次缓冲会话：通道 + 累积文本 + 计时器
class _AlivenessSession {
  final AlivenessSessionChannel channel;
  final List<String> texts = [];
  final List<Object> handles = [];
  Timer? timer;
  _AlivenessSession(this.channel);
}

/// 「活人感」通用编排（chat 与 agent_chat 共用同一套逻辑）：
/// 缓冲 → 已读不回判定 → 决策延迟 → 注入生成（宿主通道）→ 语音/分条发布
/// → 状态演化 + 记忆提取 + 探索记账。
/// 宿主差异（消息模型、生成链路、展示方式）全部收敛在 AlivenessSessionChannel。
class AlivenessOrchestrator {
  AlivenessOrchestrator._();
  static final AlivenessOrchestrator instance = AlivenessOrchestrator._();

  final _states = StateService.instance;
  final _decisions = DecisionService.instance;
  final _memory = MemoryService.instance;
  final _executor = BehaviorExecutor.instance;
  final _store = AlivenessStore.instance;
  final _random = Random();

  final _sessions = <String, _AlivenessSession>{};

  /// 通用入口：提交一条用户消息进入活人感缓冲。
  /// 返回 false 表示未接管（agent 未开启活人感），宿主走原路径。
  Future<bool> submit({
    required AIAgent agent,
    required String targetId, // chat: channelId；agent_chat: conversationId
    required String text,
    required AlivenessSessionChannel Function() createSession,
    Object? messageHandle, // 宿主原始消息对象（生成时透传给通道）
  }) async {
    final config = agent.alivenessConfig;
    if (config == null || !config.enabled) return false;

    // 状态先读一次，用亲密度决定缓冲时长
    final state = await _states.load(
      agent.id,
      intimacyHalfLifeDays: config.forgettingHalfLifeDays,
    );

    final key = '${agent.id}_$targetId';
    var session = _sessions[key];
    final isNew = session == null;
    if (isNew) {
      session = _AlivenessSession(createSession());
      _sessions[key] = session;
      await session.channel.onBufferStart();
    }
    session.texts.add(text);
    if (messageHandle != null) session.handles.add(messageHandle);
    debugPrint('[Aliveness][缓冲] ${session.channel.scope} '
        '${isNew ? "开始新缓冲" : "并入缓冲并重置计时"} | agent=${agent.name} '
        '累计=${session.texts.length}条');

    session.timer?.cancel();
    final seconds = _bufferSeconds(config, state.intimacy);
    debugPrint('[Aliveness][缓冲] 本次等待 ${seconds}s 后统一回复 '
        '(亲密度=${state.intimacy.toStringAsFixed(2)} 惰性=${config.laziness})');
    session.timer = Timer(Duration(seconds: seconds), () {
      final s = _sessions.remove(key);
      s?.timer?.cancel();
      if (s != null) {
        debugPrint('[Aliveness][缓冲] 计时结束，进入决策生成 | '
            'agent=${agent.id} 共${s.texts.length}条消息');
        unawaited(_flush(agent, config, s));
      }
    });
    return true;
  }

  /// 缓冲时长：亲密度低 → 短等待（体验优先）；亲密度高且惰性高 → 允许更长思考
  int _bufferSeconds(AlivenessConfig config, double intimacy) {
    final range = (config.bufferMaxSec - config.bufferMinSec).clamp(0, 600);
    final t = (intimacy * 0.6 + config.laziness * 0.4).clamp(0.0, 1.0);
    final jitter = _random.nextDouble() * 0.15;
    return (config.bufferMinSec + range * ((t * 0.8 + jitter).clamp(0.0, 1.0)))
        .round();
  }

  Future<void> _flush(
    AIAgent agent,
    AlivenessConfig config,
    _AlivenessSession session,
  ) async {
    final channel = session.channel;
    try {
      // 0) 设置当前 agent 上下文（记忆工具调用时定位记忆库）
      _memory.currentAgentId = agent.id;

      // 1) 记忆：核心常驻（元问题兜底）+ 话题激活联想
      final mergedText = session.texts.join('\n');
      final state = _states.cached(agent.id);
      final coreMemory = await _memory.buildCoreMemorySummary(
        agent.id,
        halfLifeDays: config.forgettingHalfLifeDays,
      );
      final activatedMemory = await _memory.buildMemorySummary(
        agent.id,
        mergedText,
        halfLifeDays: config.forgettingHalfLifeDays,
      );
      debugPrint('[Aliveness][记忆] 核心常驻='
          '${coreMemory.isEmpty ? 0 : coreMemory.split("\n").length}条 '
          '话题激活=${activatedMemory.isEmpty ? 0 : activatedMemory.split("\n").length}条');

      // 2) 决策（Jev 优先，失败走规则）：探索问题从未问池中选择
      final stats = await _store.loadStats(agent.id);
      final asked =
          (stats['askedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final unasked =
          QuestionPool.unlocked(state.intimacy)
              .where((q) => !asked.contains(q))
              .toList();
      final decision = await _decisions.decideTexts(
        agentId: agent.id,
        state: state,
        bufferedTexts: session.texts,
        config: config,
        unaskedQuestions: unasked,
        lastExploreAt:
            stats['lastExploreAt'] == null
                ? null
                : DateTime.parse(stats['lastExploreAt'] as String),
      );
      unawaited(_store.appendDecision(agent.id, {
        'source': decision.source,
        'strategy': decision.strategy.name,
        'delaySeconds': decision.delaySeconds,
        'shouldReplyNow': decision.shouldReplyNow,
        'userEmotion': decision.userEmotion,
        'exploreQuestion': decision.exploreQuestion,
        'memoryActivated': activatedMemory.isNotEmpty,
        'scope': channel.scope,
        'bufferedCount': session.texts.length,
        'answers': decision.rawAnswers,
      }));

      // 3) 已读不回（亲密度保护，防冷暴力）
      if (!decision.shouldReplyNow && state.intimacy > 0.4) {
        debugPrint('[Aliveness][回复] ${channel.scope} 决策为已读不回（亲密度 '
            '${state.intimacy.toStringAsFixed(2)}）');
        await channel.onNoReply();
        return;
      }

      // 4) 决策出的额外延迟
      if (decision.delaySeconds > 0) {
        debugPrint('[Aliveness][延迟] 决策延迟 ${decision.delaySeconds}s 后再回复');
        await channel.onDelay(decision.delaySeconds);
        await Future.delayed(Duration(seconds: decision.delaySeconds));
      }

      // 5) 注入段 + 生成（宿主通道：chat 流式 / agent_chat executeChain）
      final suffix = _buildSuffix(
        state,
        coreMemory,
        activatedMemory,
        decision,
        config,
      );
      final content = await channel.generate(
        AlivenessGenerationInput(
          mergedText: mergedText,
          systemSuffix: suffix,
          useVoice: decision.useVoice && config.voiceEnabled,
          bufferedHandles: List.unmodifiable(session.handles),
        ),
      );
      final fullContent = content?.trim() ?? '';
      if (fullContent.isEmpty) {
        await channel.onNoReply();
        return;
      }
      debugPrint('[Aliveness][生成] 完成 | 长度=${fullContent.length}字 '
          '策略=${decision.strategy.name} | 内容='
          '"${fullContent.length > 60 ? "${fullContent.substring(0, 60)}…" : fullContent}"');

      // 6) 发布最终形态：决策命中语音时只发语音（替代文本），失败回退分条文本
      var voiceSent = false;
      if (decision.useVoice && config.voiceEnabled) {
        debugPrint('[Aliveness][语音] 决策以语音消息呈现（替代文本）| '
            '服务=${config.ttsServiceId ?? "默认"}');
        voiceSent = await channel.sendVoice(fullContent);
      }
      if (!voiceSent) {
        final bubbles = _executor.splitIntoBubbles(
          fullContent,
          config.maxBubbles,
        );
        await channel.sendBubbles(bubbles);
      }
      channel.reveal();

      // 7) 后台演化与记忆提取（不阻塞发布完成）
      unawaited(
        _states.applyAfterInteraction(
          agent.id,
          generatedLength: fullContent.length.toDouble(),
          userEmotion: decision.userEmotion,
          userMessageCount: session.texts.length,
        ).then((next) => debugPrint(
            '[Aliveness][状态] 演化完成 | 能量=${next.energy.toStringAsFixed(2)} '
            '亲密度=${next.intimacy.toStringAsFixed(2)} '
            '心情=${next.mood.toStringAsFixed(2)}')),
      );
      unawaited(
        _memory
            .extractFromConversation(
              agent,
              userText: mergedText,
              assistantText: fullContent,
            )
            .then((_) => debugPrint('[Aliveness][记忆] 对话提取与遗忘整理已执行')),
      );
      unawaited(
        _memory.applyForgetting(
          agent.id,
          halfLifeDays: config.forgettingHalfLifeDays,
        ),
      );
      if (decision.exploreQuestion != null) {
        debugPrint('[Aliveness][探索] 已注入探索问题: ${decision.exploreQuestion}');
        unawaited(_recordExplored(agent.id, decision.exploreQuestion!, stats));
      }
    } catch (e) {
      debugPrint('[Aliveness][错误] ${channel.scope} 编排失败: $e');
      await channel.onError(e);
    }
  }

  /// 注入段：状态 + 消息格式 + 记忆 + 探索指令 + 语音说明 + 策略
  String _buildSuffix(
    AgentState state,
    String coreMemory,
    String activatedMemory,
    DecisionResult decision,
    AlivenessConfig config,
  ) {
    final buffer = StringBuffer('【你当前的状态】${state.describe()}。'
        '你的回复节奏和语气要符合这个状态：疲惫时回复简短、不想多聊；'
        '心情好时可以更活泼；和不熟的人说话保持礼貌但有边界。\n'
        '【消息格式】你通过聊天软件发消息：每一行是一条独立的消息（会以多条气泡发出），'
        '像真人连发一样，想发几条就写几行（最多 ${config.maxBubbles} 行）。'
        '每一行必须是完整表达一个意思的短句，绝不要把一句话拆到多行，'
        '也不要输出列表编号或项目符号；单条消息内不要换行，不要使用任何 markdown 格式。'
        '\n【回复长度】对等回应：对方只发了几个字，你也只回几个字、最多一条短消息；'
        '对方发得长、内容多，你才可以相应多回。绝不因为对方一句短话就回一大段。'
        '\n【反问克制】${_questionRule(state.intimacy)}');
    if (coreMemory.isNotEmpty) {
      buffer.write('\n【关于用户你一直记得的事】（用户问起你的了解时，'
          '基于这些内容自然地回答，不要说不知道）\n$coreMemory');
    }
    if (activatedMemory.isNotEmpty) {
      buffer.write('\n【当前话题让你想起的往事】\n$activatedMemory');
    }
    if (decision.exploreQuestion != null) {
      buffer.write('\n【探索指令】在回复的末尾，自然地问用户一个问题：'
          '"${decision.exploreQuestion}"。要顺着聊天内容带出来，不要突兀。');
    }
    if (config.voiceEnabled) {
      buffer.write('\n【语音能力】你拥有发送语音消息的能力：'
          '系统会自动把合适的回复转成语音送达，无需你生成音频或说明。'
          '当用户明确要求"发语音/说给我听"时，正常用文字回复并答应即可，'
          '语音会随后自动跟上。绝不要说"我发不了语音"。');
    }
    buffer.write('\n${_strategyText(decision.strategy)}');
    return buffer.toString();
  }

  /// 反问频率与亲密度挂钩：不熟的人用陈述句回应，熟了才自然反问
  /// （决策层【探索指令】明确要求的问题不受此限制）
  String _questionRule(double intimacy) {
    if (intimacy < 0.4) {
      return '你们还不太熟：用陈述句回应就好，不要反问对方'
          '（【探索指令】明确要求问的问题除外）。';
    }
    if (intimacy > 0.7) {
      return '你们关系很亲近：可以自然地反问一句推进聊天，'
          '但不要每条回复都以问句结尾。';
    }
    return '以陈述句为主，偶尔（而不是每轮）反问一句就好'
        '（【探索指令】明确要求问的问题除外）。';
  }

  String _strategyText(ReplyStrategy strategy) => switch (strategy) {
    ReplyStrategy.minimal => '【回复方式】用一句极简的话回应（20字以内），'
        '像真人随手回一条消息，可以用语气词（嗯、哈、好）。'
        '绝不使用列表或长篇解释。',
    ReplyStrategy.detailed => '【回复方式】认真详细地回应对方，展现你在乎，'
        '但保持聊天口吻，不要用报告或客服的格式。',
    ReplyStrategy.shiftTopic => '【回复方式】先简短自然地接住对方的话，'
        '然后主动把话题引到一件你突然想到的事上，'
        '用"对了"、"说起来"这类真人过渡语。',
    ReplyStrategy.normal => '【回复方式】用自然聊天口吻发 1~3 条短消息，'
        '像真人发消息那样说话，不要客套、不要总结陈词。',
  };

  /// 记录已抛出的探索问题，避免重复问同一个问题
  Future<void> _recordExplored(
    String agentId,
    String question,
    Map<String, dynamic> stats,
  ) async {
    try {
      final asked =
          (stats['askedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      asked.add(question);
      stats['askedQuestions'] = asked;
      stats['lastExploreAt'] = DateTime.now().toIso8601String();
      await _store.saveStats(agentId, stats);
    } catch (_) {}
  }

  /// 应用退出/插件 dispose 时清理所有计时器
  void dispose() {
    for (final session in _sessions.values) {
      session.timer?.cancel();
    }
    _sessions.clear();
  }
}
