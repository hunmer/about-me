import 'package:flutter_test/flutter_test.dart';
import 'package:aboutme/core/js_bridge/plugin_tool_registry.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_call_step.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_service.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  test('待办 schema 的 params 包装转换为 Dart 回调实参，保存后可重放', () async {
    final configs = jsonDecode(
      File('lib/plugins/agent_chat/tools/todo.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final config = ToolConfig.fromJson(
      configs['todo_createTask'] as Map<String, dynamic>,
    );
    final args = {'params': {'title': '健身', 'priority': 'medium'}};
    final invocationArgs = ToolSchemaBuilder.invocationArgs(config, args);
    expect(invocationArgs['title'], '健身');
    expect(args.containsKey('params'), isTrue);
    JSBridgeManager.instance.pluginTools.register('test_todo', {
      'createTask': (Map<String, dynamic> params) =>
          params['title'] == null ? {'error': '缺少 title'} : {'title': params['title']},
    });
    final result = await ToolService.executeToolStep(ToolCallStep(
      method: 'plugin_tool', title: '创建任务', desc: '',
      data: jsonEncode({'pluginId': 'test_todo', 'method': 'createTask', 'args': invocationArgs}),
    ));
    expect(jsonDecode(result), {'title': '健身'});
  });

  test('业务失败识别 error 和 success=false，不误报成功', () {
    expect(ToolSchemaBuilder.resultError({'error': '缺少必需参数: title'}),
        '缺少必需参数: title');
    expect(ToolSchemaBuilder.resultError({'success': false, 'message': '失败'}), '失败');
    expect(ToolSchemaBuilder.resultError({'success': true, 'data': {}}), isNull);
  });

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
