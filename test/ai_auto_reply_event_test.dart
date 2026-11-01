import 'package:aboutme/core/event/ai_auto_reply_event_args.dart';
import 'package:aboutme/core/event/event_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manager = EventManager.instance;

  AiAutoReplyEventArgs reply() => AiAutoReplyEventArgs(
    text: 'reply',
    agentId: 'agent',
    sourceEvent: 'task_completed',
  );

  test('unhandled replies retain the default display fallback', () {
    final args = reply();
    manager.broadcast(AiAutoReplyEventArgs.event, args);
    expect(args.handled, isFalse);
    expect(args.eventName, AiAutoReplyEventArgs.event);
    expect(args.text, 'reply');
    expect(args.agentId, 'agent');
    expect(args.sourceEvent, 'task_completed');
  });

  test('a consumer intercepts synchronously before broadcast returns', () {
    void consume(EventArgs args) {
      (args as AiAutoReplyEventArgs).handled = true;
    }

    manager.subscribe(AiAutoReplyEventArgs.event, consume);
    addTearDown(() => manager.unsubscribe(AiAutoReplyEventArgs.event, consume));
    final args = reply();
    manager.broadcast(AiAutoReplyEventArgs.event, args);
    expect(args.handled, isTrue);
  });

  test('an unsubscribed consumer no longer suppresses fallback', () {
    void consume(EventArgs args) {
      (args as AiAutoReplyEventArgs).handled = true;
    }

    manager.subscribe(AiAutoReplyEventArgs.event, consume);
    addTearDown(() => manager.unsubscribe(AiAutoReplyEventArgs.event, consume));
    manager.unsubscribe(AiAutoReplyEventArgs.event, consume);
    final args = reply();
    manager.broadcast(AiAutoReplyEventArgs.event, args);
    expect(args.handled, isFalse);
  });
}
