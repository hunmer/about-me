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
import 'package:aboutme/plugins/tracker/tracker_plugin.dart';
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
  late TrackerPlugin plugin;
  late PathProviderPlatform originalPaths;
  late Map<String, dynamic> configs;

  Future<dynamic> invoke(String method, Map<String, dynamic> args) =>
      JSBridgeManager.instance.pluginTools.invoke("tracker", method, args);

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp("aboutme-tracker-tools-");
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = TrackerPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    configs = jsonDecode(
      File("lib/plugins/agent_chat/tools/tracker.json").readAsStringSync(),
    );
  });

  tearDownAll(() async {
    plugin.controller.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test("内置工具仅增加 query，所有描述均存在回调", () {
    final methods = plugin.defineJSAPI();
    expect(methods.length, 11);
    for (final key in configs.keys) {
      expect(
        methods.containsKey(key.substring("tracker_".length)),
        isTrue,
        reason: key,
      );
    }
    expect(methods.keys.where((key) => key.startsWith("find")), isEmpty);
    final config = ToolConfig.fromJson(configs["tracker_query"]);
    expect(ToolSchemaBuilder.missingRequiredParameters(config, {}), isEmpty);
  });

  test("统一查询覆盖名称、分组、ID、状态及无匹配", () async {
    expect((await invoke("query", {})).length, 4);
    expect((await invoke("query", {"name": "每日运动"})).single["name"], "每日运动");
    expect(await invoke("query", {"name": "运动"}), isEmpty);
    expect(
      (await invoke("query", {"name": "运动", "fuzzy": true})).single["name"],
      "每日运动",
    );
    expect(await invoke("query", {"name": "减肥", "fuzzy": true}), isEmpty);
    expect(
      (await invoke("query", {"name": "跑步", "fuzzy": true})).single["name"],
      "每周跑步",
    );
    final health = await invoke("query", {"group": "健康", "status": "active"});
    expect(health.length, 3);
    expect(
      await invoke("query", {"group": "健康", "status": "completed"}),
      isEmpty,
    );
    expect(
      (await invoke("query", {"id": health.first["id"]})).single["id"],
      health.first["id"],
    );
    expect(
      (await invoke("query", {"group": "健康", "unitType": "分钟"})).single["name"],
      "每日运动",
    );
  });

  test("先筛选后分页，支持浮点形式整数", () async {
    final result = await invoke("query", {
      "group": "健康",
      "offset": 1.0,
      "count": 1.0,
    });
    expect(result.length, 1);
    expect(result.single["name"], "每日喝水");
    expect(await invoke("query", {"offset": 100.0}), isEmpty);
  });

  test("复用现有 filter 的字段白名单、黑名单、摘要和文本截断", () async {
    final fields = await invoke("query", {
      "fields": ["id", "name"],
      "generateSummary": false,
    });
    expect(fields.length, 4);
    expect(fields.first.keys.toSet(), {"id", "name"});
    final excluded = await invoke("query", {
      "excludeFields": ["icon"],
      "generateSummary": false,
    });
    expect(excluded.first.containsKey("icon"), isFalse);
    final summary = await invoke("query", {"group": "健康", "mode": "summary"});
    expect(summary["sum"]["total"], 3);
    final shortened = await invoke("query", {
      "textLengthLimits": {"name": 2},
      "generateSummary": false,
    });
    expect(shortened.first["name"], isNot("每日阅读"));
  });
}
