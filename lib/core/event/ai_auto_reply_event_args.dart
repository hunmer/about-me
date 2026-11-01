import 'event_manager.dart';

/// AI 自动回复广播；展示方同步标记已处理，阻止默认 Toast 重复展示。
class AiAutoReplyEventArgs extends EventArgs {
  static const event = 'ai_auto_reply';

  final String text;
  final String agentId;
  final String sourceEvent;
  bool handled = false;

  AiAutoReplyEventArgs({
    required this.text,
    required this.agentId,
    required this.sourceEvent,
  }) : super(event);
}
