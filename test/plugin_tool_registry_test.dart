import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/js_bridge/plugin_tool_registry.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_service.dart';

void main() {
  test('plugin_tool 步骤无需 JS 引擎即可重放', () async {
    JSBridgeManager.instance.pluginTools.register('test_replay', {
      'echo': (Map<String, dynamic> args) => args,
    });
    final result = await ToolService.executeToolStep(
      ToolCallStep(
        method: 'plugin_tool',
        title: 'echo',
        desc: '',
        data: '{"pluginId":"test_replay","method":"echo","args":{"id":3}}',
      ),
    );
    expect(result, '{"id":3}');
  });

  test('无需 JS 引擎即可直接执行注册的同步和异步接口', () async {
    final registry = PluginToolRegistry();
    registry.register('test', {
      'echo': (Map<String, dynamic> args) => args,
      'asyncEcho': (Map<String, dynamic> args) async => args,
    });
    expect(await registry.invoke('test', 'echo', {'id': 1}), {'id': 1});
    expect(await registry.invoke('test', 'asyncEcho', {'id': 2}), {'id': 2});
  });

  test('支持描述插件到实际注册插件的别名路由', () async {
    final registry = PluginToolRegistry();
    registry.register('openai', {
      'getMemory': (Map<String, dynamic> args) => [],
    });
    expect(await registry.invoke('memory', 'getMemory', {}), isEmpty);
    expect(() => registry.invoke('memory', 'missing', {}), throwsStateError);
  });

  test('接口异常回传给调用方且不执行其他接口', () async {
    final registry = PluginToolRegistry();
    registry.register('test', {
      'fail': (Map<String, dynamic> args) => throw StateError('failed'),
    });
    expect(() => registry.invoke('test', 'fail', {}), throwsStateError);
  });
}
