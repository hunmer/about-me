import 'package:flutter/foundation.dart';

import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/aliveness/aliveness_orchestrator.dart';
import 'package:aboutme/plugins/openai/aliveness/services/voice_service.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';

/// 生成结果：AI 消息内容与其消息 ID（分条替换直接定位，避免二次查找歧义）
class AgentChatGenerationResult {
  final String content;
  final String messageId;
  const AgentChatGenerationResult(this.content, this.messageId);
}

/// 生成回调：由 ChatController 提供（内部包装 isSending 并调 executeChain）
/// [mergedText] 缓冲期合并后的用户输入；[systemSuffix] 活人感注入段
typedef FlushCallback =
    Future<AgentChatGenerationResult?> Function(
      String mergedText,
      String? systemSuffix,
    );
typedef CancelFlushCallback = void Function();

/// agent_chat 版活人感通道：
/// 无消息占位（标题"正在输入中"），生成全程在隐藏窗口内，
/// 完成后删除 AI 原消息、一次性写入最终形态（分条文本或纯语音）。
class AgentChatAlivenessSession implements AlivenessSessionChannel {
  AgentChatAlivenessSession({
    required this.agent,
    required this.conversation,
    required this.messageService,
    required this.onFlushGenerate,
    required this.onCancelGenerate,
    required this.onReveal,
    this.onIdle,
  });

  final AIAgent agent;
  final Conversation conversation;
  final MessageService messageService;
  final FlushCallback onFlushGenerate;
  final CancelFlushCallback onCancelGenerate;
  final void Function() onReveal;
  final void Function()? onIdle;

  AgentChatGenerationResult? _generated;

  /// generate 阶段剥离的内联思考内容，sendBubbles 时挂到首条气泡
  String? _pendingThinking;

  @override
  String get scope => 'agent_chat';

  @override
  Future<void> onBufferStart() async {
    // 无占位消息：缓冲期标题"正在输入中"由 ChatController.isThinking 驱动
  }

  @override
  Future<void> onNoReply() async {
    _finish();
  }

  @override
  Future<void> onDelay(int seconds) async {
    debugPrint('[Aliveness][延迟] agent_chat 等待 ${seconds}s（标题保持输入中）');
  }

  @override
  Future<String?> generate(AlivenessGenerationInput input) async {
    final result = await onFlushGenerate(input.mergedText, input.systemSuffix);
    _generated = result;
    if (result == null) return null;
    // 内联 <think> 思考内容不参与分条，否则会被拆成多条消息；
    // 暂存后由 sendBubbles 挂到首条气泡的 thinkingContent
    final (thinking, body) = ChatMessage.splitThink(result.content);
    _pendingThinking = thinking.isEmpty ? null : thinking;
    return body;
  }

  @override
  Future<void> cancelGeneration() async {
    onCancelGenerate();
  }

  @override
  Future<bool> sendVoice(String text) async {
    // 替代模式：删除原 AI 消息后只发语音，失败回退分条文本
    await _deleteGenerated();
    return VoiceService.instance.sendVoiceMessageToConversation(
      agentId: agent.id,
      conversation: conversation,
      messageService: messageService,
      text: text,
      ttsServiceId: agent.alivenessConfig?.ttsServiceId,
    );
  }

  @override
  Future<void> sendBubbles(List<String> bubbles) async {
    await _deleteGenerated();
    for (var i = 0; i < bubbles.length; i++) {
      await messageService.addMessage(
        ChatMessage.ai(
          conversationId: conversation.id,
          content: bubbles[i],
          isGenerating: false,
          generatedByAgentId: agent.id,
          // 思考内容挂首条，渲染端经"查看思考过程"入口展示
          thinkingContent: i == 0 ? _pendingThinking : null,
        ),
      );
    }
    _pendingThinking = null;
    debugPrint('[Aliveness][分条] agent_chat 一次性写入 ${bubbles.length} 条');
  }

  @override
  void reveal() {
    onReveal();
  }

  @override
  Future<void> onError(Object error) async {
    _finish();
  }

  /// 删除生成链路写入的整条 AI 消息（隐藏窗口内用户不可见）
  Future<void> _deleteGenerated() async {
    final generated = _generated;
    if (generated == null) return;
    _generated = null;
    await messageService.deleteMessage(conversation.id, generated.messageId);
  }

  /// 关闭隐藏窗口并复位"正在输入中"状态（无回复/出错的收尾）
  void _finish() {
    onReveal();
    onIdle?.call();
  }
}
