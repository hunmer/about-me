import 'package:aboutme/plugins/agent_chat/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimal REST message parses and survives serialization', () {
    final message = ChatMessage.fromJson({
      'id': 'message-1',
      'conversationId': 'conversation-1',
      'role': 'user',
      'content': 'scn hello',
    });
    expect(message.isUser, isTrue);
    expect(message.content, 'scn hello');
    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.isUser, isTrue);
    expect(restored.timestamp, message.timestamp);
  });

  test('stored isUser and timestamp retain precedence', () {
    final message = ChatMessage.fromJson({
      'id': 'message-2',
      'conversationId': 'conversation-1',
      'content': 'reply',
      'role': 'user',
      'isUser': false,
      'timestamp': '2026-10-24T07:54:37.839Z',
    });
    expect(message.isUser, isFalse);
    // 统一入口解析即转本地时区：同一时刻的本地表示
    expect(message.timestamp, DateTime.parse('2026-10-24T07:54:37.839Z').toLocal());
    expect(message.timestamp.isUtc, isFalse);
  });
}
