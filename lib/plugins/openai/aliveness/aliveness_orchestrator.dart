import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/decision_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/schedule_service.dart';
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

  /// 中断正在进行的模型请求。新用户消息到达时由编排器调用。
  Future<void> cancelGeneration() async {}

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
  bool flushing = false;
  bool rerunRequested = false;
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
  static const _bufferWaitSeconds = 5;

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

    // 今日首次聊天：后台生成/复用今日日程（不阻塞缓冲，注入时再取）
    unawaited(ScheduleService.instance.ensureTodaySchedule(agent));

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
    debugPrint(
      '[Aliveness][缓冲] ${session.channel.scope} '
      '${isNew ? "开始新缓冲" : "并入缓冲并重置计时"} | agent=${agent.name} '
      '累计=${session.texts.length}条',
    );

    // 生成阶段收到新消息：取消当前请求，等 5 秒后用合并后的消息重新生成。
    if (session.flushing) {
      session.rerunRequested = true;
      await session.channel.cancelGeneration();
    }
    session.timer?.cancel();
    // 固定给用户 5 秒补充消息；计时器会在每条新消息到达时重置。
    const seconds = _bufferWaitSeconds;
    debugPrint('[Aliveness][缓冲] 固定等待 ${seconds}s 后统一回复（期间新消息会重置计时）');
    session.timer = Timer(Duration(seconds: seconds), () {
      final s = _sessions[key];
      s?.timer?.cancel();
      if (s != null) {
        s.rerunRequested = false;
        s.flushing = true;
        debugPrint(
          '[Aliveness][缓冲] 计时结束，进入决策生成 | '
          'agent=${agent.id} 共${s.texts.length}条消息',
        );
        unawaited(_flush(agent, config, s));
      }
    });
    return true;
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

      // 1) 记忆：核心常驻（元问题兜底）+ 自我近况 + 话题激活联想 + 今日日程
      final mergedText = session.texts.join('\n');
      final state = _states.cached(agent.id);
      final coreMemory = await _memory.buildCoreMemorySummary(
        agent.id,
        halfLifeDays: config.forgettingHalfLifeDays,
      );
      final selfMemory = await _memory.buildSelfSummary(
        agent.id,
        halfLifeDays: config.forgettingHalfLifeDays,
      );
      final activatedMemory = await _memory.buildMemorySummary(
        agent.id,
        mergedText,
        halfLifeDays: config.forgettingHalfLifeDays,
      );
      final schedule = await ScheduleService.instance.loadToday(agent.id);
      final scheduleContext = schedule == null
          ? ''
          : ScheduleService.instance.buildScheduleContext(schedule);
      debugPrint(
        '[Aliveness][记忆] 核心常驻='
        '${coreMemory.isEmpty ? 0 : coreMemory.split("\n").length}条 '
        '自我=${selfMemory.isEmpty ? 0 : selfMemory.split("\n").length}条 '
        '话题激活=${activatedMemory.isEmpty ? 0 : activatedMemory.split("\n").length}条 '
        '日程=${schedule == null ? "未生成" : "${schedule.entries.length}项"}',
      );

      // 2) 决策（Jev 优先，失败走规则）：探索问题从未问池中选择
      final stats = await _store.loadStats(agent.id);
      final asked =
          (stats['askedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final unasked = QuestionPool.unlocked(
        state.intimacy,
      ).where((q) => !asked.contains(q)).toList();
      final decision = await _decisions.decideTexts(
        agentId: agent.id,
        state: state,
        bufferedTexts: session.texts,
        config: config,
        unaskedQuestions: unasked,
        lastExploreAt: stats['lastExploreAt'] == null
            ? null
            : DateTime.parse(stats['lastExploreAt'] as String),
      );
      unawaited(
        _store.appendDecision(agent.id, {
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
        }),
      );

      // 3) 已读不回（亲密度保护，防冷暴力）
      if (!decision.shouldReplyNow && state.intimacy > 0.4) {
        debugPrint(
          '[Aliveness][回复] ${channel.scope} 决策为已读不回（亲密度 '
          '${state.intimacy.toStringAsFixed(2)}）',
        );
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
        selfMemory,
        activatedMemory,
        scheduleContext,
        decision,
        config,
      );
      var content = await channel.generate(
        AlivenessGenerationInput(
          mergedText: mergedText,
          systemSuffix: suffix,
          useVoice: decision.useVoice && config.voiceEnabled,
          bufferedHandles: List.unmodifiable(session.handles),
        ),
      );
      var fullContent = content?.trim() ?? '';
      if (session.rerunRequested) {
        session.flushing = false;
        session.timer ??= Timer(
          const Duration(seconds: _bufferWaitSeconds),
          () {
            session.timer = null;
            session.rerunRequested = false;
            session.flushing = true;
            unawaited(_flush(agent, config, session));
          },
        );
        debugPrint('[Aliveness][缓冲] 生成期间收到新消息，等待 5 秒后合并重生成');
        return;
      }
      if (fullContent.isNotEmpty && config.humanScoreEnabled) {
        final score = await _decisions.scoreHumanity(
          state: '${agent.effectiveSystemPrompt}\n用户：$mergedText',
          reply: fullContent,
        );
        debugPrint(
          '[Aliveness][拟人度] score=${score ?? "不可用"} threshold=${config.humanScoreThreshold}',
        );
        if (score != null && score < config.humanScoreThreshold) {
          final feedback =
              '\n【拟人度修订】上一版回复评分为 $score/3，AI味偏重。请重新生成：少用客套和总结，加入符合你人设的口头禅或具体反应，句子长短不一，允许停顿或不完整表达，不要解释你在遵守规则。只输出最终聊天内容。';
          content = await channel.generate(
            AlivenessGenerationInput(
              mergedText: mergedText,
              systemSuffix: '$suffix\n$feedback',
              useVoice: decision.useVoice && config.voiceEnabled,
              bufferedHandles: List.unmodifiable(session.handles),
            ),
          );
          fullContent = content?.trim() ?? '';
        }
      }
      if (fullContent.isEmpty) {
        await channel.onNoReply();
        return;
      }
      debugPrint(
        '[Aliveness][生成] 完成 | 长度=${fullContent.length}字 '
        '策略=${decision.strategy.name} | 内容='
        '"${fullContent.length > 60 ? "${fullContent.substring(0, 60)}…" : fullContent}"',
      );

      // 6) 发布最终形态：决策命中语音时只发语音（替代文本），失败回退分条文本
      var voiceSent = false;
      if (decision.useVoice && config.voiceEnabled) {
        debugPrint(
          '[Aliveness][语音] 决策以语音消息呈现（替代文本）| '
          '服务=${config.ttsServiceId ?? "默认"}',
        );
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
        _states
            .applyAfterInteraction(
              agent.id,
              generatedLength: fullContent.length.toDouble(),
              userEmotion: decision.userEmotion,
              userMessageCount: session.texts.length,
            )
            .then(
              (next) => debugPrint(
                '[Aliveness][状态] 演化完成 | 能量=${next.energy.toStringAsFixed(2)} '
                '亲密度=${next.intimacy.toStringAsFixed(2)} '
                '心情=${next.mood.toStringAsFixed(2)}',
              ),
            ),
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
    } finally {
      if (!session.rerunRequested) {
        _sessions.removeWhere((key, value) => identical(value, session));
      }
    }
  }

  /// 注入段：状态 + 消息格式 + 记忆（用户/自我/激活）+ 今日日程
  /// + 探索指令 + 语音说明 + 策略
  String _buildSuffix(
    AgentState state,
    String coreMemory,
    String selfMemory,
    String activatedMemory,
    String scheduleContext,
    DecisionResult decision,
    AlivenessConfig config,
  ) {
    final buffer = StringBuffer(
      '【你当前的状态】${state.describe()}。'
      '你的回复节奏和语气要符合这个状态：疲惫时回复简短、不想多聊；'
      '心情好时可以更活泼；和不熟的人说话保持礼貌但有边界。\n'
      '【消息格式】你通过聊天软件发消息：每一行是一条独立的消息（会以多条气泡发出），'
      '像真人连发一样，想发几条就写几行（最多 ${config.maxBubbles} 行）。'
      '每一行必须是完整表达一个意思的短句，绝不要把一句话拆到多行，'
      '也不要输出列表编号或项目符号；单条消息内不要换行，不要使用任何 markdown 格式。'
      '\n【回复长度】对等回应：对方只发了几个字，你也只回几个字、最多一条短消息；'
      '对方发得长、内容多，你才可以相应多回。绝不因为对方一句短话就回一大段。'
      '\n【反问克制】${_questionRule(state.intimacy)}',
    );
    if (coreMemory.isNotEmpty) {
      buffer.write(
        '\n【关于用户你一直记得的事】（用户问起你的了解时，'
        '基于这些内容自然地回答，不要说不知道）\n$coreMemory',
      );
    }
    if (activatedMemory.isNotEmpty) {
      buffer.write('\n【当前话题让你想起的往事】\n$activatedMemory');
    }
    if (selfMemory.isNotEmpty) {
      buffer.write(
        '\n【你自己的近况】（你亲自说过/做过的事，'
        '聊到相关话题时自然带出，不要刻意汇报）\n$selfMemory',
      );
    }
    if (scheduleContext.isNotEmpty) {
      buffer.write(
        '\n【你今天的真实生活】$scheduleContext'
        '\n这是你今天真实的日程，用户问"你在干嘛/今天做了什么"时据此回答，'
        '不要编造与它矛盾的内容。',
      );
    }
    if (decision.exploreQuestion != null) {
      buffer.write(
        '\n【探索指令】在回复的末尾，自然地问用户一个问题：'
        '"${decision.exploreQuestion}"。要顺着聊天内容带出来，不要突兀。',
      );
    }
    if (config.voiceEnabled) {
      buffer.write(
        '\n【语音能力】你拥有发送语音消息的能力：'
        '系统会自动把合适的回复转成语音送达，无需你生成音频或说明。'
        '当用户明确要求"发语音/说给我听"时，正常用文字回复并答应即可，'
        '语音会随后自动跟上。绝不要说"我发不了语音"。',
      );
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
    ReplyStrategy.minimal =>
      '【回复方式】用一句极简的话回应（20字以内），'
          '像真人随手回一条消息，可以用语气词（嗯、哈、好）。'
          '绝不使用列表或长篇解释。',
    ReplyStrategy.detailed =>
      '【回复方式】认真详细地回应对方，展现你在乎，'
          '但保持聊天口吻，不要用报告或客服的格式。',
    ReplyStrategy.shiftTopic =>
      '【回复方式】先简短自然地接住对方的话，'
          '然后主动把话题引到一件你突然想到的事上，'
          '用"对了"、"说起来"这类真人过渡语。',
    ReplyStrategy.normal =>
      '【回复方式】用自然聊天口吻发 1~3 条短消息，'
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

  /// 丢弃指定目标的缓冲会话（清空聊天记录时调用），
  /// 避免清空前的输入并入后续合并文本重新发给模型
  void discardBuffer(String targetId) {
    _sessions.removeWhere((key, session) {
      if (!key.endsWith('_$targetId')) return false;
      session.timer?.cancel();
      debugPrint('[Aliveness][缓冲] $targetId 缓冲已随聊天记录清空而丢弃');
      return true;
    });
  }

  /// 应用退出/插件 dispose 时清理所有计时器
  void dispose() {
    for (final session in _sessions.values) {
      session.timer?.cancel();
    }
    _sessions.clear();
  }
}
