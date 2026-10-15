// 回归测试：MessageBubble 入场动画
// 历史消息（>5s）不播动画时，控制器必须直接停在完成态；
// 否则 ScaleTransition 停留在 scale=0，气泡不绘制 → 历史会话全部空白
// （复现：agent_chat bf444323 会话气泡空白）
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/plugins/chat/models/message.dart';
import 'package:aboutme/plugins/chat/models/user.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/widgets/message_bubble/index.dart'
    as chat_bubble;
import 'package:aboutme/widgets/swipe_action/index.dart';

void main() {
  Future<void> pumpWithDate(WidgetTester tester, DateTime date) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: chat_bubble.MessageBubble(
            message: Message(
              id: 'm1',
              content: '我写了几篇日记',
              user: User(id: 'u1', username: '我'),
              type: MessageType.sent,
              date: date,
            ),
            isSelected: false,
            isMultiSelectMode: false,
            onEdit: () {},
            onDelete: () {},
            onCopy: () {},
            onSetFixedSymbol: (_) {},
            currentUserId: 'u1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<double> bubbleScales(WidgetTester tester) => tester
      .widgetList<ScaleTransition>(
        find.descendant(
          of: find.byType(SwipeActionWrapper),
          matching: find.byType(ScaleTransition),
        ),
      )
      .map((w) => w.scale.value)
      .toList();

  testWidgets('历史消息入场缩放直接为 1.0（不播动画）', (tester) async {
    await pumpWithDate(
      tester,
      DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final scales = bubbleScales(tester);
    expect(scales, isNotEmpty);
    expect(scales.every((v) => v == 1.0), isTrue);
    expect(find.text('我写了几篇日记'), findsWidgets);
  });

  testWidgets('新消息入场动画播完后为 1.0', (tester) async {
    await pumpWithDate(tester, DateTime.now());
    final scales = bubbleScales(tester);
    expect(scales, isNotEmpty);
    expect(scales.every((v) => v == 1.0), isTrue);
  });
}
