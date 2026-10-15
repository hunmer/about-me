// 回归测试：内联 <think> 思考内容不再被分条为多条消息，
// 生成中以可展开的"思考中"入口展示（muted 小字号）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/message_bubble.dart';
import 'package:aboutme/plugins/agent_chat/screens/chat_screen/components/tool_process_view.dart';

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
  // DSLoadingDots 为无限循环动画，用定长推进
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('纯思考阶段（生成中）：显示思考中入口，点击展开全文', (tester) async {
    await pumpContent(
      tester,
      ChatMessage.ai(
        conversationId: 'c1',
        content: '<think>用户想看日记，我先查一下统计数据</think>',
        isGenerating: true,
      ),
    );

    // 默认收起：入口可见，思考全文不可见
    expect(find.text('思考中...'), findsOneWidget);
    expect(find.textContaining('用户想看日记'), findsNothing);

    // 点击展开：muted 小字全文可见
    await tester.tap(find.text('思考中...'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('用户想看日记'), findsOneWidget);
    expect(find.text('收起思考'), findsOneWidget);

    // 再点收起
    await tester.tap(find.text('收起思考'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('用户想看日记'), findsNothing);
    expect(find.text('思考中...'), findsOneWidget);
  });

  testWidgets('完成后纯思考消息：不显示思考中入口', (tester) async {
    await pumpContent(
      tester,
      ChatMessage.ai(
        conversationId: 'c1',
        content: '<think>只有思考没有正文</think>',
        isGenerating: false,
      ),
    );
    expect(find.text('思考中...'), findsNothing);
    expect(find.textContaining('只有思考没有正文'), findsNothing);
  });

  testWidgets('正文与思考并存：正文正常显示，思考不混入正文', (tester) async {
    await pumpContent(
      tester,
      ChatMessage.ai(
        conversationId: 'c1',
        content: '<think>先想想</think>这是正文回复',
        isGenerating: true,
      ),
    );
    expect(find.textContaining('这是正文回复'), findsWidgets);
    expect(find.textContaining('先想想'), findsNothing);
  });

  testWidgets('ThinkingLiveView 折叠入口独立交互', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DSThemeBridge(
            child: ThinkingLiveView(thinking: '一段很长的思考内容'.padRight(500, '。')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('思考中...'), findsOneWidget);
    expect(find.textContaining('一段很长的思考内容'), findsNothing);

    await tester.tap(find.text('思考中...'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('一段很长的思考内容'), findsOneWidget);
  });
}
