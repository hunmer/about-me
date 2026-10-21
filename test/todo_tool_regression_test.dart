import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
import 'package:aboutme/plugins/todo/todo_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _TemporaryStorage implements StorageInterface {
  _TemporaryStorage(this.directory);
  final Directory directory;

  Future<File> _file(String key) async {
    final file = File('${directory.path}/$key');
    await file.parent.create(recursive: true);
    return file;
  }

  @override
  Future<String> readString(String path) async {
    final file = await _file(path);
    return await file.exists() ? file.readAsString() : '';
  }

  @override
  Future<void> writeString(String path, String value) async =>
      (await _file(path)).writeAsString(value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late TodoPlugin plugin;
  late Map<String, dynamic> configs;
  late PathProviderPlatform originalPaths;

  ToolConfig config(String method) =>
      ToolConfig.fromJson(configs['todo_$method'] as Map<String, dynamic>);

  Future<Map<String, dynamic>> create(dynamic tags) async {
    final result = await JSBridgeManager.instance.pluginTools
        .invoke('todo', 'createTask', {
          'title': '明天下午3点前提交报告',
          'priority': 'high',
          'dueDate': '2026-10-22T15:00:00+08:00',
          if (tags != null) 'tags': tags,
        });
    return jsonDecode(result as String) as Map<String, dynamic>;
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('aboutme-todo-tools-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(
      storage: _TemporaryStorage(
        await Directory.systemTemp.createTemp('aboutme-data-'),
      ),
    );
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = TodoPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    await plugin.taskController.reload();
    configs =
        jsonDecode(
              File('lib/plugins/agent_chat/tools/todo.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  tearDownAll(() async {
    plugin.taskController.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test('今日任务平铺和 params 包装参数都通过校验并调用真实 Dart API', () async {
    final toolConfig = config('getTodayTasks');
    final parameters = ToolSchemaBuilder.invocationParameters(toolConfig);
    expect(parameters.map((p) => p.name), ['offset', 'count']);
    for (final input in <Map<String, dynamic>>[
      {'offset': 0, 'count': 50},
      {
        'params': {'offset': 0, 'count': 50},
      },
      {},
    ]) {
      final args = ToolSchemaBuilder.invocationArgs(toolConfig, input);
      expect(
        ToolSchemaBuilder.missingRequiredParameters(toolConfig, args),
        isEmpty,
      );
      final result = await JSBridgeManager.instance.pluginTools.invoke(
        'todo',
        'getTodayTasks',
        args,
      );
      expect(
        ToolSchemaBuilder.resultError(jsonDecode(result as String)),
        isNull,
      );
    }
  });

  test('创建任务平铺与包装参数都校验实际必填 title，null 也不能通过', () {
    final toolConfig = config('createTask');
    for (final input in <Map<String, dynamic>>[
      {},
      {'params': {}},
      {
        'params': {'title': null},
      },
    ]) {
      final args = ToolSchemaBuilder.invocationArgs(toolConfig, input);
      expect(ToolSchemaBuilder.missingRequiredParameters(toolConfig, args), [
        'title',
      ]);
    }
    for (final input in <Map<String, dynamic>>[
      {'title': '报告'},
      {
        'params': {'title': '报告'},
      },
    ]) {
      final args = ToolSchemaBuilder.invocationArgs(toolConfig, input);
      expect(
        ToolSchemaBuilder.missingRequiredParameters(toolConfig, args),
        isEmpty,
      );
    }
  });

  test('创建紧急任务支持数组与旧 JSON 字符串，保留标签、优先级和时区', () async {
    for (final tags in <dynamic>[
      ['紧急'],
      '["紧急"]',
      [],
      null,
    ]) {
      final result = await create(tags);
      expect(result, isNot(contains('error')));
      final expectedTags = tags == null || tags is List && tags.isEmpty
          ? <String>[]
          : ['紧急'];
      expect(result['tags'], expectedTags);
      expect(result['priority'], 2);
      expect(
        DateTime.parse(result['dueDate'] as String),
        DateTime.utc(2026, 10, 22, 7),
      );
      final saved = await AboutmeDataService.instance.readFile(
        'todo',
        'tasks.json',
      );
      final tasks = (saved as Map)['tasks'] as List;
      expect(
        tasks.singleWhere((t) => t['id'] == result['id'])['tags'],
        expectedTags,
      );
    }
  });

  test('非法标签返回工具错误且不创建任务', () async {
    final count = plugin.taskController.tasks.length;
    for (final tags in <dynamic>[
      'invalid-json',
      '{"tag":"紧急"}',
      3,
      [3],
    ]) {
      expect(ToolSchemaBuilder.resultError(await create(tags)), isNotNull);
    }
    expect(plugin.taskController.tasks.length, count);
  });
}
