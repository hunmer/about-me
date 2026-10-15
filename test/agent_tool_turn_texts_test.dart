// 回归测试：工具调用多轮文本的轮次拆分与展示
// 生成端：runToolLoop 按轮冻结正文、剥除模型重复前缀，最终回复干净落地
// 渲染端：过程轮文本存 metadata['processTexts']，「查看执行过程」展开显示
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';
import 'package:aboutme/plugins/agent_chat/services/native_tool_agent_service.dart';

void main() {
  group('stripRepeatedPrefix（模型重复上一轮正文的剥离）', () {
    test('A → A+B：剥离重复前缀得到增量 B', () {
      expect(
        stripRepeatedPrefix('你好呀我看看统计\n你一共写了7篇', '你好呀我看看统计'),
        '你一共写了7篇',
      );
    });

    test('无重复前缀：原文保留', () {
      expect(stripRepeatedPrefix('全新一轮内容', '上一轮内容'), '全新一轮内容');
    });

    test('空前缀/空前一轮：不剥离', () {
      expect(stripRepeatedPrefix('内容', null), '内容');
      expect(stripRepeatedPrefix('内容', ''), '内容');
    });

    test('当前文本不长于前轮：不剥离', () {
      expect(stripRepeatedPrefix('短', '上一轮比较长的内容'), '短');
    });

    test('bf444323 实际形态：A / A+B / B+C 三轮依次剥离', () {
      const a = '你好呀！让我帮你看看写了什么';
      const b = '你一共写了7篇日记，让我看看具体内容';
      final turn2 = stripRepeatedPrefix('$a\n$b', a);
      final turn3 = stripRepeatedPrefix('$b\n看到你的日记啦', turn2);
      expect(turn2, b);
      expect(turn3, '看到你的日记啦');
    });
  });

  group('processTexts 渲染', () {
    Future<void> pumpContent(WidgetTester tester, ChatMessage message) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DSThemeBridge(
                child: AgentMessageContent(message: message, textColor: null),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    ChatMessage buildMessage({required bool generating}) {
      return ChatMessage.ai(
        conversationId: 'c1',
        content: generating ? '当前轮流式文本' : '最终回复正文',
        isGenerating: generating,
        metadata: const {
          'processTexts': ['第一轮说了什么', '第二轮基于工具结果分析'],
        },
      ).copyWith(
        toolCall: ToolCallResponse(
          steps: [
            ToolCallStep(
              method: 'run_js',
              title: '获取日记统计',
              desc: '',
              data: 'getDiaryStats()',
              status: generating ? ToolCallStatus.success : ToolCallStatus.success,
            ),
          ],
        ),
      );
    }

    testWidgets('生成中：已完成轮文本以"第 N 轮"块展示', (tester) async {
      await pumpContent(tester, buildMessage(generating: true));
      expect(find.text('第 1 轮'), findsOneWidget);
      expect(find.text('第一轮说了什么'), findsOneWidget);
      expect(find.text('第 2 轮'), findsOneWidget);
      expect(find.text('第二轮基于工具结果分析'), findsOneWidget);
      expect(find.textContaining('当前轮流式文本'), findsWidgets);
    });

    testWidgets('已完成：展开过程显示各轮文本与轮次统计', (tester) async {
      await pumpContent(tester, buildMessage(generating: false));
      expect(find.textContaining('最终回复正文'), findsWidgets);
      // 按钮统计含轮次数
      expect(find.textContaining('2 轮回复'), findsOneWidget);
      // 默认折叠
      expect(find.text('第 1 轮'), findsNothing);

      await tester.tap(find.text('查看执行过程'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('第 1 轮'), findsOneWidget);
      expect(find.text('第二轮基于工具结果分析'), findsOneWidget);
    });
  });
}
