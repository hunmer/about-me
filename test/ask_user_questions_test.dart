import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/ask_user_questions_card.dart';
import 'package:aboutme/plugins/agent_chat/services/ask_user_questions_service.dart';

final _questions = <String, dynamic>{
  'questions': [
    {
      'id': 'style',
      'question': '选择风格',
      'options': [
        {'label': '简洁'},
        {'label': '详细', 'description': '展示更多信息'},
      ],
    },
    {'id': 'notes', 'question': '还有什么要求？'},
  ],
};

ToolCallStep _step(UserQuestionsRequest request) => ToolCallStep(
  method: 'askuserquestions',
  title: '向用户提问',
  desc: '',
  data: jsonEncode(request.toJson()),
  status: ToolCallStatus.running,
);

void main() {
  test('拒绝重复问题 ID、空问题和无效选项', () {
    for (final invalid in [
      {'questions': []},
      {
        'questions': [
          {'id': 'a', 'question': ' '},
        ],
      },
      {
        'questions': [
          {'id': 'a', 'question': '?'},
          {'id': 'a', 'question': '?'},
        ],
      },
      {
        'questions': [
          {
            'id': 'a',
            'question': '?',
            'options': [
              {'label': ''},
            ],
          },
        ],
      },
    ]) {
      expect(() => UserQuestion.parse(invalid), throwsFormatException);
    }
  });

  test('并发提问独立完成，不能重复提交或提交不属于问题的选项', () async {
    final service = AskUserQuestionsService.instance;
    final questions = UserQuestion.parse(_questions);
    final first = service.create(questions);
    final second = service.create(questions);
    addTearDown(() {
      first.cancel();
      second.cancel();
    });
    expect(first.id, isNot(second.id));
    final answers = <Map<String, dynamic>>[
      {
        'id': 'style',
        'selected': <String>['简洁'],
        'text': '',
      },
      {'id': 'notes', 'selected': <String>[], 'text': '支持手机'},
    ];
    expect(
      first.answer([
        {
          ...answers.first,
          'selected': <String>['不存在'],
        },
        answers.last,
      ]),
      isFalse,
    );
    expect(first.answer(answers), isTrue);
    expect((await first.future)['answers'], answers);
    expect(second.isPending, isTrue);
    expect(service.find(second.id), same(second));
    expect(first.answer(answers), isFalse);
    second.cancel();
    expect((await second.future)['status'], 'cancelled');
    expect(service.find(first.id), isNull);
    expect(service.find(second.id), isNull);
  });

  testWidgets('聊天内支持单选切换、自由输入，提交后显示回答', (tester) async {
    final request = AskUserQuestionsService.instance.create(
      UserQuestion.parse(_questions),
    );
    addTearDown(request.cancel);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AskUserQuestionsCard(step: _step(request))),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('详细'));
    await tester.pump();
    await tester.tap(find.text('简洁'));
    await tester.enterText(find.byType(TextField).last, '支持手机');
    await tester.pump();
    await tester.tap(find.text('提交回答'));
    await tester.pump();
    final answers = (await request.future)['answers'] as List;
    expect(answers.first['selected'], ['简洁']);
    expect(answers.last['text'], '支持手机');
    expect(find.text('已回答'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('多选可以选择多个答案', (tester) async {
    final question = Map<String, dynamic>.from(
      (_questions['questions'] as List).first,
    );
    question['multiSelect'] = true;
    final request = AskUserQuestionsService.instance.create(
      UserQuestion.parse({
        'questions': [question],
      }),
    );
    addTearDown(request.cancel);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AskUserQuestionsCard(step: _step(request))),
      ),
    );
    await tester.tap(find.text('简洁'));
    await tester.tap(find.text('详细'));
    await tester.pump();
    await tester.tap(find.text('提交回答'));
    await tester.pump();
    final answers = (await request.future)['answers'] as List;
    expect(answers.single['selected'], ['简洁', '详细']);
  });

  testWidgets('停止生成时释放等待并关闭全局提问弹窗', (tester) async {
    var cancelling = false;
    final request = AskUserQuestionsService.instance.create(
      UserQuestion.parse(_questions),
      isCancelling: () => cancelling,
    );
    addTearDown(request.cancel);
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: Text('原页面'))),
    );
    await tester.pumpAndSettle();
    final shown = showGlobalUserQuestions(request, _step(request));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    cancelling = true;
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await shown;
    expect((await request.future)['reason'], '已取消发送');
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('原页面'), findsOneWidget);
    Get.reset();
  });

  testWidgets('已持久化或已失效的提问不再允许提交', (tester) async {
    final request = AskUserQuestionsService.instance.create(
      UserQuestion.parse(_questions),
    );
    final step = _step(request);
    request.cancel();
    await request.future;
    step.result = jsonEncode({
      'status': 'cancelled',
      'reason': '用户取消回答',
      'answers': [],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AskUserQuestionsCard(step: step)),
      ),
    );
    expect(find.text('用户取消回答'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('提交回答'), findsNothing);
  });
}
