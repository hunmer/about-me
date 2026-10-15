// 回归测试：工具调用消息的 Codex 式过程展示
// 生成中 = 过程视图全展开（思考流/工具步骤/流式正文）；
// 完成 = 仅最终回复 + 可展开的「查看执行过程」
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';

ChatMessage _toolMessage({required bool generating, String? thinking}) {
  return ChatMessage.ai(
    conversationId: 'c1',
    content: '<think>先查统计</think>让我先看看统计信息',
    isGenerating: generating,
    chainExecutionId: null,
  ).copyWith(
    thinkingContent: thinking,
    toolCall: ToolCallResponse(
      steps: [
        ToolCallStep(
          method: 'run_js',
          title: '获取日记统计',
          desc: '参数：{}',
          data: 'getDiaryStats()',
          status: generating ? ToolCallStatus.running : ToolCallStatus.success,
          result: generating ? null : '{"totalEntries":7}',
        ),
      ],
    ),
  );
}

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
  // DSLoadingDots 为无限循环动画，pumpAndSettle 永不空闲，用定长推进
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('生成中：思考流 + 工具步骤 + 流式正文同时展示', (tester) async {
    await pumpContent(tester, _toolMessage(generating: true, thinking: '正在分析用户的请求'));

    expect(find.text('思考中...'), findsOneWidget);
    // thinking 与内联 think 标签合并显示，用包含匹配
    expect(find.textContaining('正在分析用户的请求'), findsOneWidget);
    expect(find.textContaining('工具调用 (1 个步骤)'), findsOneWidget);
    // 内联 think 已剥离，流式正文可见
    expect(find.textContaining('让我先看看统计信息'), findsWidgets);
    expect(find.textContaining('正在生成...'), findsOneWidget);
    // 完成后才有的折叠入口不出现
    expect(find.textContaining('查看执行过程'), findsNothing);
  });

  testWidgets('已完成：仅最终回复 + 可展开过程，思考不直接露出', (tester) async {
    final message = ChatMessage.ai(
      conversationId: 'c1',
      content: '第一轮文本\n\n[工具执行结果]\n步骤 1: xxx\n\n[AI最终回复]\n这是最终回答',
      isGenerating: false,
    ).copyWith(
      thinkingContent: '内部思考内容ABC',
      toolCall: ToolCallResponse(
        steps: [
          ToolCallStep(
            method: 'run_js',
            title: '获取日记统计',
            desc: '',
            data: 'getDiaryStats()',
            status: ToolCallStatus.success,
            result: '{"totalEntries":7}',
          ),
        ],
      ),
    );
    await pumpContent(tester, message);

    // 最终回复可见，过程文本与思考默认折叠
    expect(find.textContaining('这是最终回答'), findsWidgets);
    expect(find.textContaining('第一轮文本'), findsNothing);
    expect(find.textContaining('内部思考内容ABC'), findsNothing);
    expect(find.textContaining('正在生成...'), findsNothing);

    // 展开过程：出现工具步骤与思考内容
    await tester.tap(find.textContaining('查看执行过程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('工具调用 (1 个步骤)'), findsOneWidget);
    expect(find.textContaining('内部思考内容ABC'), findsOneWidget);
    expect(find.textContaining('收起执行过程'), findsOneWidget);
  });

  testWidgets('真实 bf444323 数据（无标记兜底）：完成后显示正文与折叠入口', (tester) async {
    final file = File(
      r'C:\Users\Administrator\Documents\app_data\agent_chat\messages\bf444323-cab3-4925-a880-e8e278f1d563.json',
    );
    if (!file.existsSync()) {
      debugPrint('JSON 文件不存在，跳过');
      return;
    }
    final data = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    final messages =
        data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    // 剥离链式字段，走 AgentMessageContent 工具消息路径
    final ai = messages[1].copyWith(
      chainExecutionId: '',
      chainStepIndex: null,
    );
    await pumpContent(tester, ai);

    // 按钮文案由"查看执行过程"与"(2 个步骤)"两个 Text 组成
    expect(find.text('查看执行过程'), findsOneWidget);
    expect(find.textContaining('2 个步骤'), findsOneWidget);
    expect(find.textContaining('工具调用 (2 个步骤)'), findsNothing); // 默认折叠
    expect(find.textContaining('看到你的日记啦'), findsWidgets); // 正文兜底可见

    // 按钮位于长正文之下，先滚动可见再点击
    final entry = find.text('查看执行过程');
    await tester.ensureVisible(entry);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(entry);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('工具调用 (2 个步骤)'), findsOneWidget);
  });
}
