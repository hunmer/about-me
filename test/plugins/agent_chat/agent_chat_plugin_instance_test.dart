import 'package:aboutme/plugins/agent_chat/agent_chat_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temporary instances do not replace the first plugin instance', () {
    final registeredPlugin = AgentChatPlugin();

    AgentChatPlugin();

    expect(AgentChatPlugin.instance, same(registeredPlugin));
  });
}
