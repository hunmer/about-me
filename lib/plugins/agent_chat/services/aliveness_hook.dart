import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/aliveness/data/question_pool.dart';
import 'package:aboutme/plugins/openai/aliveness/models/aliveness_config.dart';
import 'package:aboutme/plugins/openai/aliveness/services/aliveness_store.dart';
import 'package:aboutme/plugins/openai/aliveness/services/behavior_executor.dart';
import 'package:aboutme/plugins/openai/aliveness/services/decision_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/memory_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/state_service.dart';
import 'package:aboutme/plugins/openai/aliveness/services/voice_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:aboutme/plugins/openai/openai_plugin.dart';

/// 缓冲中的 agent_chat 会话
class _AgentChatBuffer {
  final String conversationId;
  final List<String> texts = [];
  final List<String> messageIds = [];
  Timer? timer;
  _AgentChatBuffer(this.conversationId);
}

/// 生成结果：AI 消息内容与其消息 ID（分条替换直接定位，避免二次查找歧义）
class AgentChatGenerationResult {
  final String content;
  final String messageId;
  const AgentChatGenerationResult(this.content, this.messageId);
}

/// 生成回调：由 ChatController 提供（内部包装 isSending 并调 executeChain）
/// [mergedText] 缓冲期合并后的用户输入；[systemSuffix] 活人感注入段
typedef FlushCallback = Future<AgentChatGenerationResult?> Function(
  String mergedText,
  String? systemSuffix,
);

/// agent_chat（AI 对话插件）的活人感接入：
/// 与 chat 插件版（AlivenessOrchestrator）同构——
/// 缓冲思考 → 已读标记 → Jev/规则决策 → 延迟 → 注入生成 → 分条 → 状态/记忆演化。
/// 由 ChatController.sendMessage 在普通路径前调用，返回 false 表示未接管（走原路径）。
class AgentChatAlivenessHook {
  AgentChatAlivenessHook._();
  static final AgentChatAlivenessHook instance = AgentChatAlivenessHook._();

  final _buffers = <String, _AgentChatBuffer>{};
  final _states = StateService.instance;
  final _decisions = DecisionService.instance;
  final _memory = MemoryService.instance;
  final _executor = BehaviorExecutor.instance;
  final _store = AlivenessStore.instance;

  /// 生成回调由 ChatController 提供（见顶层 FlushCallback 定义）

  Future<bool> onUserMessage({
    required Conversation conversation,
    required ChatMessage userMessage,
    required MessageService messageService,
    required FlushCallback onFlushGenerate,
    required void Function() onReveal,
  }) async {
    // 仅单 agent 会话支持（链式模式走原路径）
    final agentId = conversation.agentId;
    if (agentId == null || conversation.isChainMode) return false;

    final agent = await OpenAIPlugin.instance.controller.getAgent(agentId);
    final config = agent?.alivenessConfig;
    if (agent == null || config == null || !config.enabled) return false;

    // 1) 已读标记
    userMessage.metadata ??= {};
    userMessage.metadata!['readAt'] = DateTime.now().millisecondsSinceEpoch;
    await messageService.updateMessage(userMessage);
    debugPrint('[Aliveness][已读] ${agent.name} 已读 agent_chat 消息');

    // 2) 记录互动频道统计（主动消息目标沿用 agent_chat 体系时记录会话）
    unawaited(_recordConversation(agentId, conversation.id));

    // 3) 缓冲
    final state = await _states.load(
      agentId,
      intimacyHalfLifeDays: config.forgettingHalfLifeDays,
    );
    var buffer = _buffers[conversation.id];
    final isNew = buffer == null;
    buffer ??= _AgentChatBuffer(conversation.id);
    _buffers[conversation.id] = buffer;
    buffer.texts.add(userMessage.content);
    buffer.messageIds.add(userMessage.id);

    debugPrint('[Aliveness][缓冲] agent_chat ${isNew ? "开始新缓冲" : "并入缓冲"} | '
        'agent=${agent.name} 累计=${buffer.texts.length}条');

    // 4) 计时（亲密度低→短等待）
    final range = (config.bufferMaxSec - config.bufferMinSec).clamp(0, 600);
    final t = (state.intimacy * 0.6 + config.laziness * 0.4).clamp(0.0, 1.0);
    final seconds =
        (config.bufferMinSec + range * (t * 0.8 + 0.1)).round().clamp(
              config.bufferMinSec,
              config.bufferMaxSec,
            );
    buffer.timer?.cancel();
    buffer.timer = Timer(Duration(seconds: seconds), () {
      final b = _buffers.remove(conversation.id);
      b?.timer?.cancel();
      if (b != null) {
        unawaited(
          _flush(agent, config, conversation, b, messageService, onFlushGenerate, onReveal),
        );
      }
    });
    return true;
  }

  Future<void> _flush(
    AIAgent agent,
    AlivenessConfig config,
    Conversation conversation,
    _AgentChatBuffer buffer,
    MessageService messageService,
    FlushCallback onFlushGenerate,
    void Function() onReveal,
  ) async {
    try {
      // 0) 设置当前 agent 上下文（记忆工具调用时定位记忆库）
      _memory.currentAgentId = agent.id;

      // 1) 记忆：核心记忆常驻（元问题兜底）+ 话题激活（联想）
      final mergedText = buffer.texts.join('\n');
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
      debugPrint('[Aliveness][记忆] 核心常驻=${coreMemory.isEmpty ? 0 : coreMemory.split("\n").length}条 '
          '话题激活=${activatedMemory.isEmpty ? 0 : activatedMemory.split("\n").length}条');

      // 2) 决策
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
        bufferedTexts: buffer.texts,
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
        'scope': 'agent_chat',
        'bufferedCount': buffer.texts.length,
      }));

      // 3) 已读不回（亲密度保护）
      if (!decision.shouldReplyNow && state.intimacy > 0.4) {
        debugPrint('[Aliveness][回复] agent_chat 决策为已读不回');
        return;
      }

      // 4) 延迟
      if (decision.delaySeconds > 0) {
        debugPrint('[Aliveness][延迟] agent_chat 决策延迟 ${decision.delaySeconds}s');
        await Future.delayed(Duration(seconds: decision.delaySeconds));
      }

      // 5) 注入段 + 生成（复用 executeChain 原链路）
      final suffix = _buildSuffix(
        state.describe(),
        coreMemory,
        activatedMemory,
        decision,
        config,
      );
      final generated = await onFlushGenerate(mergedText, suffix);
      final fullContent = generated?.content.trim() ?? '';
      if (fullContent.isEmpty) return;

      // 6) 处理完毕后一次性展示：生成全程在隐藏窗口内（标题"正在输入中"），
      //    此处删原消息并写入最终形态（分条文本或纯语音），随后揭示。
      //    语音决策命中时只发语音消息，不再出现文本+语音双份；
      //    语音合成失败回退文本分条。
      if (generated != null) {
        await messageService.deleteMessage(conversation.id, generated.messageId);

        var voiceSent = false;
        if (decision.useVoice && config.voiceEnabled) {
          debugPrint('[Aliveness][语音] 决策以语音消息呈现（替代文本）| '
              '服务=${config.ttsServiceId ?? "默认"}');
          voiceSent = await VoiceService.instance.sendVoiceMessageToConversation(
            agentId: agent.id,
            conversation: conversation,
            messageService: messageService,
            text: fullContent,
            ttsServiceId: config.ttsServiceId,
          );
        }

        if (!voiceSent) {
          final bubbles = _executor.splitIntoBubbles(
            fullContent,
            config.maxBubbles,
          );
          for (var i = 0; i < bubbles.length; i++) {
            await messageService.addMessage(
              ChatMessage.ai(
                conversationId: conversation.id,
                content: bubbles[i],
                isGenerating: false,
                generatedByAgentId: agent.id,
              ),
            );
          }
          debugPrint('[Aliveness][分条] agent_chat 一次性写入 ${bubbles.length} 条');
        }
      }
      // 关闭隐藏窗口，所有消息一次性展示
      onReveal();

      // 7) 后台演化与记忆提取
      unawaited(
        _states.applyAfterInteraction(
          agent.id,
          generatedLength: fullContent.length.toDouble(),
          userEmotion: decision.userEmotion,
          userMessageCount: buffer.texts.length,
        ),
      );
      unawaited(
        _memory.extractFromConversation(
          agent,
          userText: mergedText,
          assistantText: fullContent,
        ),
      );
      if (decision.exploreQuestion != null) {
        debugPrint('[Aliveness][探索] agent_chat 注入探索问题');
        unawaited(_recordExplored(agent.id, decision.exploreQuestion!, stats));
      }
    } catch (e) {
      debugPrint('[Aliveness][错误] agent_chat 编排失败: $e');
      onReveal(); // 兜底关窗，避免消息永久隐藏
    }
  }

  String _buildSuffix(
    String stateDesc,
    String coreMemory,
    String activatedMemory,
    DecisionResult decision,
    AlivenessConfig config,
  ) {
    final buffer = StringBuffer('【你当前的状态】$stateDesc。'
        '你的回复节奏和语气要符合这个状态：疲惫时简短、不想多聊。\n'
        '【消息格式】你通过聊天软件发消息：每一行是一条独立的消息（会以多条气泡发出），'
        '像真人连发一样，想发几条就写几行（最多 ${config.maxBubbles} 行）。'
        '每一行必须是完整表达一个意思的短句，绝不要把一句话拆到多行，'
        '也不要输出列表编号或项目符号；单条消息内不要换行，不要使用任何 markdown 格式。');
    if (coreMemory.isNotEmpty) {
      buffer.write('\n【关于用户你一直记得的事】（用户问起你的了解时，'
          '基于这些内容自然地回答，不要说不知道）\n$coreMemory');
    }
    if (activatedMemory.isNotEmpty) {
      buffer.write('\n【当前话题让你想起的往事】\n$activatedMemory');
    }
    if (decision.exploreQuestion != null) {
      buffer.write('\n【探索指令】回复末尾自然地问用户："${decision.exploreQuestion}"');
    }
    buffer.write('\n【回复方式】${_strategyText(decision.strategy)}');
    return buffer.toString();
  }

  String _strategyText(ReplyStrategy strategy) => switch (strategy) {
    ReplyStrategy.minimal => '用一句极简的话回应（20字以内），像真人随手回一条消息，'
        '可以用语气词（嗯、哈、好）。绝不使用列表或长篇解释。',
    ReplyStrategy.detailed => '认真详细地回应对方，展现你在乎，但保持聊天口吻。',
    ReplyStrategy.shiftTopic => '先简短自然地接住对方的话，然后主动把话题引到一件'
        '你突然想到的事上，用"对了"、"说起来"这类真人过渡语。',
    ReplyStrategy.normal => '用自然聊天口吻回复，1~3句话，像真人发消息那样说话，'
        '不要客套、不要总结陈词。',
  };

  Future<void> _recordConversation(String agentId, String conversationId) async {
    try {
      final stats = await _store.loadStats(agentId);
      stats['lastAgentChatConversationId'] = conversationId;
      await _store.saveStats(agentId, stats);
    } catch (_) {}
  }

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

  void dispose() {
    for (final b in _buffers.values) {
      b.timer?.cancel();
    }
    _buffers.clear();
  }
}
