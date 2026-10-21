import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/conversation.dart';
import 'package:aboutme/plugins/agent_chat/models/suggested_question.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_question_test_runner.dart';

void main() {
  group('SuggestedQuestionTestRunner', () {
    test(
      'runs in order and starts a fresh conversation after a tool error',
      () async {
        final questions = [
          const SuggestedQuestion(
            category: 'todo',
            categoryName: '待办',
            question: '第一题',
          ),
          const SuggestedQuestion(
            category: 'todo',
            categoryName: '待办',
            question: '第二题',
          ),
        ];
        final sent = <String>[];
        final created = <int>[];
        final saved = <Map<String, dynamic>>[];
        final runner = SuggestedQuestionTestRunner(
          questions: questions,
          createSession: (index) async {
            created.add(index);
            return _FakeSession(index, sent, includeToolError: index == 1);
          },
          writeReport: (_, report) async => saved.add(report),
        );

        await runner.run();

        expect(sent, ['第一题', '第二题']);
        expect(created, [1, 2]);
        expect(runner.results.map((r) => r['status']), ['failed', 'passed']);
        expect(runner.failedConversations, contains('conversation-1'));
        expect(runner.conversationIds, ['conversation-1', 'conversation-2']);
        expect(saved.last['status'], 'completed');
        expect(runner.buildReviewPrompt(), contains('conversation-1'));
      },
    );

    test(
      'manual stop skips remaining questions and saves stopped state',
      () async {
        final sent = <String>[];
        late SuggestedQuestionTestRunner runner;
        runner = SuggestedQuestionTestRunner(
          questions: [
            const SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '执行后中止',
            ),
            const SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '不应执行',
            ),
          ],
          createSession: (index) async =>
              _FakeSession(index, sent, afterSend: runner.stop),
          writeReport: (_, __) async {},
        );

        await runner.run();

        expect(sent, ['执行后中止']);
        expect(runner.stopRequested, isTrue);
        expect(runner.toJson()['status'], 'stopped');
      },
    );

    test(
      'stop during session initialization does not send questions',
      () async {
        final sent = <String>[];
        late SuggestedQuestionTestRunner runner;
        runner = SuggestedQuestionTestRunner(
          questions: [
            const SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '不应执行',
            ),
          ],
          createSession: (index) async {
            runner.stop();
            return _FakeSession(index, sent);
          },
          writeReport: (_, __) async {},
        );

        await runner.run();

        expect(sent, isEmpty);
        expect(runner.results, isEmpty);
        expect(runner.toJson()['status'], 'stopped');
      },
    );

    test(
      'persistence failure stops the batch and records conversation context',
      () async {
        final sent = <String>[];
        var created = 0;
        final runner = SuggestedQuestionTestRunner(
          questions: List.generate(
            2,
            (index) => SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '第${index + 1}题',
            ),
          ),
          createSession: (index) async {
            created++;
            return _FakeSession(index, sent, persistError: 'write failed');
          },
          writeReport: (_, __) async {},
        );

        await runner.run();

        expect(sent, ['第1题']);
        expect(created, 1);
        expect(runner.fatalError, contains('会话保存失败'));
        expect(runner.failedConversations, contains('conversation-1'));
        expect(
          runner.results.single['persistenceError'],
          'Bad state: write failed',
        );
      },
    );

    test('report save errors are exposed for retry', () async {
      var shouldFail = true;
      final runner = SuggestedQuestionTestRunner(
        questions: [
          const SuggestedQuestion(
            category: 'todo',
            categoryName: '待办',
            question: '题目',
          ),
        ],
        createSession: (index) async => _FakeSession(index, []),
        writeReport: (_, __) async {
          if (shouldFail) throw StateError('disk unavailable');
        },
      );

      await runner.run();
      expect(runner.saveError, 'Bad state: disk unavailable');
      expect(runner.fatalError, 'Bad state: disk unavailable');
      shouldFail = false;
      await runner.save();
      expect(runner.saveError, isNull);
    });

    test(
      'successful questions reuse the session and keep their own messages',
      () async {
        final sent = <String>[];
        var created = 0;
        final runner = SuggestedQuestionTestRunner(
          questions: [
            const SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '第一题',
            ),
            const SuggestedQuestion(
              category: 'todo',
              categoryName: '待办',
              question: '第二题',
            ),
          ],
          createSession: (index) async {
            created++;
            return _FakeSession(index, sent, includeToolError: false);
          },
          writeReport: (_, __) async {},
        );

        await runner.run();

        expect(created, 1);
        expect(sent, ['第一题', '第二题']);
        expect(runner.results.map((r) => r['status']), ['passed', 'passed']);
        final firstIds = runner.results[0]['messageIds'] as List;
        final secondIds = runner.results[1]['messageIds'] as List;
        expect(firstIds, hasLength(1));
        expect(secondIds, hasLength(1));
        expect(secondIds.toSet().intersection(firstIds.toSet()), isEmpty);
      },
    );
  });
}

class _FakeSession implements SuggestedQuestionTestSession {
  _FakeSession(
    this.index,
    this.sent, {
    this.afterSend,
    this.includeToolError = true,
    this.persistError,
  });
  final int index;
  final List<String> sent;
  final void Function()? afterSend;
  final bool includeToolError;
  final String? persistError;
  final _messages = <ChatMessage>[];
  bool cancelled = false;

  @override
  Conversation get conversation {
    final now = DateTime(2026);
    return Conversation(
      id: 'conversation-$index',
      title: 'test $index',
      agentId: 'agent',
      createdAt: now,
      lastMessageAt: now,
    );
  }

  @override
  List<ChatMessage> get messages => _messages;
  @override
  Future<void> send(String question, bool Function() shouldCancel) async {
    if (shouldCancel()) return;
    sent.add(question);
    _messages.add(
      ChatMessage.user(conversationId: conversation.id, content: question),
    );
    if (includeToolError) {
      _messages.add(
        ChatMessage.ai(conversationId: conversation.id, content: '').copyWith(
          toolCall: ToolCallResponse(
            steps: [
              ToolCallStep(
                method: 'run_js',
                title: '测试工具',
                desc: '',
                data: 'badCall()',
                status: ToolCallStatus.failed,
                error: 'Undefined method',
              ),
            ],
          ),
        ),
      );
    }
    afterSend?.call();
  }

  @override
  Future<void> persist() async {
    if (persistError != null) throw StateError(persistError!);
  }

  @override
  void cancel() => cancelled = true;
  @override
  void dispose() {}
}
