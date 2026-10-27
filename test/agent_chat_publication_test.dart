import 'dart:async';

import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/services/message_service.dart';
import 'package:aboutme/plugins/openai/aliveness/aliveness_orchestrator.dart';
import 'package:aboutme/plugins/openai/aliveness/channels/agent_chat_aliveness_channel.dart';
import 'package:aboutme/plugins/openai/models/ai_agent.dart';
import 'package:flutter_test/flutter_test.dart';

class _Messages implements MessageService {
  final messages = <ChatMessage>[];
  final operations = <String>[];
  final writeError = StateError('first bubble could not be saved');
  bool failFirstAdd = false;
  Completer<void>? secondAddGate;
  final secondAddStarted = Completer<void>();
  int addAttempts = 0;

  @override
  Future<void> addMessage(ChatMessage message) async {
    addAttempts++;
    if (failFirstAdd && addAttempts == 1) throw writeError;
    if (addAttempts == 2) {
      secondAddStarted.complete();
      await secondAddGate?.future;
    }
    messages.add(message);
    operations.add('add:${message.content}');
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) async {
    messages.removeWhere(
      (message) =>
          message.conversationId == conversationId && message.id == messageId,
    );
    operations.add('delete:$messageId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Messages messages;
  late ChatMessage original;
  late AgentChatAlivenessSession channel;

  setUp(() async {
    final now = DateTime(2026);
    final agent = AIAgent(
      id: 'agent',
      name: 'test',
      description: '',
      tags: const [],
      serviceProviderId: 'test',
      baseUrl: '',
      headers: const {},
      createdAt: now,
      updatedAt: now,
      model: 'test',
    );
    final conversation = Conversation(
      id: 'conversation',
      title: 'test',
      agentId: agent.id,
      createdAt: now,
      lastMessageAt: now,
    );
    original = ChatMessage.ai(
      conversationId: conversation.id,
      content: '完整原文',
      isGenerating: false,
    );
    messages = _Messages()..messages.add(original);
    channel = AgentChatAlivenessSession(
      agent: agent,
      conversation: conversation,
      messageService: messages,
      onFlushGenerate: (_, _) async =>
          AgentChatGenerationResult(original.content, original.id),
      onCancelGenerate: () {},
      onReveal: () {},
    );
    // 通过真实 generate 设置原文关联，不访问或复制通道的私有状态。
    expect(
      await channel.generate(
        const AlivenessGenerationInput(
          mergedText: '输入',
          systemSuffix: '',
          useVoice: false,
        ),
      ),
      original.content,
    );
  });

  test('首条气泡保存失败时保留完整原文且不执行删除', () async {
    messages.failFirstAdd = true;

    await expectLater(
      channel.sendBubbles(['第一条', '第二条']),
      throwsA(same(messages.writeError)),
    );

    expect(messages.addAttempts, 1);
    expect(messages.messages, [same(original)]);
    expect(messages.messages.single.content, '完整原文');
    expect(messages.operations, isEmpty);
  });

  test('全部气泡保存成功后删除原文并保留气泡', () async {
    final gate = Completer<void>();
    messages.secondAddGate = gate;

    final publication = channel.sendBubbles(['第一条', '第二条']);
    await messages.secondAddStarted.future;
    try {
      // 第二条保存尚未完成时，第一条和完整原文都必须还在。
      expect(
        messages.messages.map((message) => message.id),
        contains(original.id),
      );
      expect(messages.operations, ['add:第一条']);
    } finally {
      gate.complete();
      await publication;
    }

    expect(
      messages.messages.map((message) => message.id),
      isNot(contains(original.id)),
    );
    expect(messages.messages.map((message) => message.content), ['第一条', '第二条']);
    expect(messages.messages.every((message) => !message.isGenerating), isTrue);
    expect(
      messages.messages.every(
        (message) => message.conversationId == 'conversation',
      ),
      isTrue,
    );
    expect(
      messages.messages.every(
        (message) => message.generatedByAgentId == 'agent',
      ),
      isTrue,
    );
    expect(messages.operations, [
      'add:第一条',
      'add:第二条',
      'delete:${original.id}',
    ]);
  });

  test('空气泡列表不删除原文', () async {
    await channel.sendBubbles(const []);

    expect(messages.messages, [same(original)]);
    expect(messages.addAttempts, 0);
    expect(messages.operations, isEmpty);
  });
}
