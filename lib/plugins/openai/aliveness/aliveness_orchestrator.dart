import 'dart:async';
import 'dart:developer' as developer;

import 'package:agentlib/openai_compat.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/models/agent_state.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/buffer_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/decision_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/state_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/voice_service.dart';
import 'package:aboutme/plugins/openai/services/request_service.dart';

/// 「活人感」总编排：缓冲 → 决策（Jev/规则）→ 延迟 → 生成 → 分条发送 → 状态演化。
/// 仅当 agent.alivenessConfig.enabled 时由 ChatEventHandler 进入本路径。
class AlivenessOrchestrator {
  AlivenessOrchestrator._();
  static final AlivenessOrchestrator instance = AlivenessOrchestrator._();

  final _buffer = BufferService.instance;
  final _states = StateService.instance;
  final _decisions = DecisionService.instance;
  final _executor = BehaviorExecutor.instance;
  final _store = AlivenessStore.instance;
  final _memory = MemoryService.instance;

  ChatPlugin get _plugin =>
      PluginManager.instance.getPlugin('chat')! as ChatPlugin;

  /// 入口：用户消息到达（等价于原 _processAgentResponse 的替代路径）
  Future<void> handleUserMessage(
    AIAgent agent,
    Message message, {
    String? absoluteFilePath,
    bool hasImage = false,
  }) async {
    final config = agent.alivenessConfig;
    if (config == null || !config.enabled) return;

    // 状态先读一次，用亲密度决定缓冲时长
    final state = await _states.load(
      agent.id,
      intimacyHalfLifeDays: config.forgettingHalfLifeDays,
    );

    await _buffer.enqueue(
      agentId: agent.id,
      agentName: agent.name,
      agentAvatar: agent.avatarUrl,
      userMessage: message,
      config: config,
      intimacy: state.intimacy,
      onFlush: (buffer) => _onFlush(
        agent,
        buffer,
        config,
        absoluteFilePath: absoluteFilePath,
        hasImage: hasImage,
      ),
    );
  }

  Future<void> _onFlush(
    AIAgent agent,
    AlivenessBuffer buffer,
    AlivenessConfig config, {
    String? absoluteFilePath,
    bool hasImage = false,
  }) async {
    final typingMessage = buffer.typingMessage;
    if (typingMessage == null) return;

    try {
      // 1) 记忆激活扩散：按本次缓冲内容"想起"相关往事（PRD 5.3.1）
      final bufferText = buffer.messages.map((m) => m.content).join('\n');
      final memorySummary = await _memory.buildMemorySummary(
        agent.id,
        bufferText,
        halfLifeDays: config.forgettingHalfLifeDays,
      );

      // 2) 决策（Jev 优先，失败走规则）：探索问题从未问池中选择
      final state = _states.cached(agent.id);
      final stats = await _store.loadStats(agent.id);
      final asked =
          (stats['askedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final unasked = QuestionPool.unlocked(state.intimacy)
          .where((q) => !asked.contains(q))
          .toList();
      final lastExploreAt =
          stats['lastExploreAt'] == null
              ? null
              : DateTime.parse(stats['lastExploreAt'] as String);

      final decision = await _decisions.decide(
        agentId: agent.id,
        state: state,
        bufferedMessages: buffer.messages,
        config: config,
        unaskedQuestions: unasked,
        lastExploreAt: lastExploreAt,
      );
      _store.appendDecision(agent.id, {
        'source': decision.source,
        'strategy': decision.strategy.name,
        'delaySeconds': decision.delaySeconds,
        'shouldReplyNow': decision.shouldReplyNow,
        'userEmotion': decision.userEmotion,
        'exploreQuestion': decision.exploreQuestion,
        'memoryActivated': memorySummary.isNotEmpty,
        'bufferedCount': buffer.messages.length,
        'answers': decision.rawAnswers,
      });

      // 3) 已读不回：删除占位消息，仅保留已读标记（受亲密度保护，防冷暴力）
      if (!decision.shouldReplyNow && state.intimacy > 0.4) {
        await _plugin.channelService.deleteMessage(typingMessage);
        _plugin.refresh();
        return;
      }

      // 4) 决策出的额外延迟：占位消息保持"正在想…"
      if (decision.delaySeconds > 0) {
        typingMessage.content = '正在想…';
        await _plugin.channelService.saveMessage(typingMessage);
        await Future.delayed(Duration(seconds: decision.delaySeconds));
      }

      // 5) 组装上下文：system（含状态/记忆/策略注入）+ 频道历史 + 本次缓冲消息
      final contextMessages = await _buildContext(
        agent,
        buffer,
        state,
        decision,
        memorySummary: memorySummary,
      );

      // 5) 流式生成（复用主 LLM 通道），onToken 实时更新占位消息
      final contentBuffer = StringBuffer();
      await RequestService.streamResponseWithRetry(
        agent: agent,
        prompt: null,
        vision: hasImage,
        filePath: absoluteFilePath,
        contextMessages: contextMessages,
        onToken: (token) async {
          contentBuffer.write(token);
          typingMessage.content = RequestService.processThinkingContent(
            contentBuffer.toString(),
          );
          await _plugin.channelService.saveMessage(typingMessage);
          _plugin.refresh();
        },
        onError: (error) async {
          typingMessage.content = '抱歉，生成回复时出现错误：$error';
          typingMessage.metadata?.addAll({'isError': true, 'isCompleted': true});
          await _plugin.channelService.saveMessage(typingMessage);
          _plugin.refresh();
        },
        onComplete: () {},
        maxRetries: 3,
        retryDelay: 1000,
      );

      // 6) 分条发送（第一条替换占位，其余带随机延迟逐条发出）
      final fullContent = RequestService.processThinkingContent(
        contentBuffer.toString(),
      );
      if (fullContent.trim().isEmpty) return;
      final bubbles = _executor.splitIntoBubbles(fullContent, config.maxBubbles);
      final aiUser = typingMessage.user;
      await _executor.sendBubbles(
        channelId: buffer.channelId,
        aiUser: aiUser,
        typingMessage: typingMessage,
        bubbles: bubbles,
        agentId: agent.id,
        config: config,
      );

      // 6.5) 语音主动发送（PRD 5.1.5）：决策判定后以语音形式追加同内容消息
      if (decision.useVoice && config.voiceEnabled) {
        unawaited(
          VoiceService.instance.sendVoiceMessage(
            agentId: agent.id,
            channelId: buffer.channelId,
            aiUser: aiUser,
            text: fullContent,
            ttsServiceId: await _voiceServiceId(),
            replyToId: typingMessage.replyToId,
          ),
        );
      }

      // 7) 后台状态演化 + 记忆提取 + 探索问题记账（不阻塞发送完成）
      unawaited(
        _states.applyAfterInteraction(
          agent.id,
          generatedLength: fullContent.length.toDouble(),
          userEmotion: decision.userEmotion,
          userMessageCount: buffer.messages.length,
        ),
      );
      unawaited(
        _memory.extractFromConversation(
          agent,
          userText: bufferText,
          assistantText: fullContent,
        ),
      );
      unawaited(_memory.applyForgetting(
        agent.id,
        halfLifeDays: config.forgettingHalfLifeDays,
      ));
      if (decision.exploreQuestion != null) {
        unawaited(_recordExplored(agent.id, decision.exploreQuestion!, stats));
      }
    } catch (e) {
      developer.log('活人感编排失败: $e', name: 'AlivenessOrchestrator');
      typingMessage.metadata?.addAll({'isError': true, 'isCompleted': true});
      await _plugin.channelService.saveMessage(typingMessage);
      _plugin.refresh();
    }
  }

  /// 上下文组装：system 注入状态+记忆+策略指令，历史按 contextCount 截取，
  /// 本次缓冲的所有用户消息显式附在末尾（保证不被历史窗口挤掉）。
  Future<List<ChatCompletionMessage>> _buildContext(
    AIAgent agent,
    AlivenessBuffer buffer,
    AgentState state,
    DecisionResult decision, {
    String memorySummary = '',
  }) async {
    final basePrompt = await RequestService.getEffectiveSystemPrompt(agent);
    final memoryBlock = memorySummary.isEmpty
        ? ''
        : '\n【你想起的关于用户的往事】\n$memorySummary\n';
    final exploreBlock = decision.exploreQuestion == null
        ? ''
        : '\n【探索指令】在回复的末尾，自然地问用户一个问题："${decision.exploreQuestion}"'
            '。要顺着聊天内容带出来，不要突兀。\n';
    final systemContent = '$basePrompt\n\n${_injectState(state)}$memoryBlock'
        '$exploreBlock\n${_strategyInstruction(decision.strategy, state)}';

    final messages = <ChatCompletionMessage>[
      ChatCompletionMessage.system(content: systemContent),
    ];

    // 频道历史（排除本次缓冲消息与占位/错误消息）
    final contextCount =
        (buffer.messages.first.metadata?['contextCount'] as int?) ?? 20;
    final recent = _plugin.channelService.getRecentMessages(
      buffer.channelId,
      contextCount + buffer.messages.length,
    );
    final bufferedIds = buffer.messages.map((m) => m.id).toSet();
    for (final msg in recent) {
      if (bufferedIds.contains(msg.id)) continue;
      if (typingPlaceholderIds(buffer).contains(msg.id)) continue;
      if (msg.metadata?['isThinking'] == true) continue;
      if (msg.content.contains('抱歉，生成回复时出现错误')) continue;
      if (msg.metadata?['isError'] == true) continue;
      if (msg.content.trim().isEmpty) continue;

      if (msg.metadata?['isAI'] == true) {
        messages.add(ChatCompletionMessage.assistant(content: msg.content));
      } else {
        messages.add(
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(msg.content),
          ),
        );
      }
    }

    // 本次缓冲的用户消息
    for (final msg in buffer.messages) {
      messages.add(
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(msg.content),
        ),
      );
    }
    return messages;
  }

  Set<String> typingPlaceholderIds(AlivenessBuffer buffer) => {
    if (buffer.typingMessage != null) buffer.typingMessage!.id,
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

  /// 语音消息使用的 TTS 服务（全局配置，未配置则用 TTS 默认服务）
  Future<String?> _voiceServiceId() async {
    try {
      final settings = await _store.loadSettings();
      return settings['voiceServiceId'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _injectState(AgentState state) =>
      '【你当前的状态】${state.describe()}。'
      '你的回复节奏和语气要符合这个状态：疲惫时回复简短、不想多聊；'
      '心情好时可以更活泼；和不熟的人说话保持礼貌但有边界。';

  String _strategyInstruction(ReplyStrategy strategy, AgentState state) {
    switch (strategy) {
      case ReplyStrategy.minimal:
        return '【回复方式】用一句极简的话回应（20字以内），像真人随手回一条消息，'
            '可以用语气词（嗯、哈、好）。绝不使用列表或长篇解释。';
      case ReplyStrategy.detailed:
        return '【回复方式】认真详细地回应对方，展现你在乎，但保持聊天口吻，'
            '不要用报告或客服的格式。';
      case ReplyStrategy.shiftTopic:
        return '【回复方式】先简短自然地接住对方的话，然后主动把话题引到一件'
            '你突然想到的事上，用"对了"、"说起来"这类真人过渡语。';
      case ReplyStrategy.normal:
        return '【回复方式】用自然聊天口吻回复，1~3句话，像真人发消息那样说话，'
            '不要客套、不要总结陈词。';
    }
  }

  void dispose() {
    _buffer.dispose();
  }
}
