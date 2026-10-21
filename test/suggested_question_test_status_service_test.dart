import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/agent_chat/services/suggested_question_test_status_service.dart';

Map<String, Object?> _report({
  required String finishedAt,
  required String category,
  required String question,
  required String status,
  String resultFinishedAt = '2026-01-02T10:00:00.000',
}) => {
  'finishedAt': finishedAt,
  'results': [
    {
      'category': category,
      'question': question,
      'status': status,
      'startedAt': '2026-01-02T09:59:00.000',
      'finishedAt': resultFinishedAt,
    },
  ],
};

void main() {
  test('最新记录决定错误标记，通过即清除', () {
    final reports = [
      _report(
        finishedAt: '2026-01-02T10:01:00.000',
        category: 'todo',
        question: '题目A',
        status: 'failed',
        resultFinishedAt: '2026-01-02T10:00:30.000',
      ),
      _report(
        finishedAt: '2026-01-03T10:01:00.000',
        category: 'todo',
        question: '题目A',
        status: 'passed',
        resultFinishedAt: '2026-01-03T10:00:30.000',
      ),
    ];

    final status = latestSuggestedQuestionTestStatus(
      reports,
      category: 'todo',
      question: '题目A',
    );

    expect(status, isNotNull);
    expect(status!.hasError, isFalse);
    expect(status.lastTestAt, DateTime.parse('2026-01-03T10:00:30.000'));
  });

  test('通过后再失败会重新标记错误', () {
    final reports = [
      _report(
        finishedAt: '2026-01-02T10:01:00.000',
        category: 'todo',
        question: '题目B',
        status: 'passed',
      ),
      _report(
        finishedAt: '2026-01-03T10:01:00.000',
        category: 'todo',
        question: '题目B',
        status: 'failed',
        resultFinishedAt: '2026-01-03T10:00:40.000',
      ),
    ];

    final status = latestSuggestedQuestionTestStatus(
      reports,
      category: 'todo',
      question: '题目B',
    );

    expect(status!.hasError, isTrue);
    expect(status.lastTestAt, DateTime.parse('2026-01-03T10:00:40.000'));
  });

    test('工具错误但状态为 passed（已兜底恢复）不标记错误', () {
      final status = latestSuggestedQuestionTestStatus(
        [
          {
            'results': [
              {
                'category': 'todo',
                'question': '题目C',
                'status': 'passed',
                'finishedAt': '2026-01-04T10:00:00.000',
                'toolErrors': [
                  {'method': 'run_js', 'error': '调用失败'},
                ],
              },
            ],
          },
        ],
        category: 'todo',
        question: '题目C',
      );

      expect(status!.hasError, isFalse);
    });

  test('取消测试不会清除之前的错误标记', () {
    final status = latestSuggestedQuestionTestStatus(
      [
        _report(
          finishedAt: '2026-01-02T10:01:00.000',
          category: 'todo',
          question: '题目D',
          status: 'failed',
        ),
        _report(
          finishedAt: '2026-01-03T10:01:00.000',
          category: 'todo',
          question: '题目D',
          status: 'cancelled',
          resultFinishedAt: '2026-01-03T10:00:30.000',
        ),
      ],
      category: 'todo',
      question: '题目D',
    );

    expect(status!.hasError, isTrue);
  });

  test('未知问题没有状态记录', () {
    final status = latestSuggestedQuestionTestStatus(
      [
        _report(
          finishedAt: '',
          category: 'todo',
          question: '别的题',
          status: 'failed',
        ),
      ],
      category: 'todo',
      question: '不在报告中的题',
    );
    expect(status, isNull);
  });
}
