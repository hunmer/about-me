import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/plugins/habits/habits_plugin.dart';
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
    return await file.exists() ? await file.readAsString() : '';
  }

  @override
  Future<void> writeString(String path, String value) async =>
      (await _file(path)).writeAsString(value);

  @override
  Future<void> createDirectory(String path) async {
    await Directory('${directory.path}/$path').create(recursive: true);
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = await _file(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> hasData(String key) async => await (await _file(key)).exists();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late HabitsPlugin plugin;
  late Map<String, dynamic> configs;

  Future<dynamic> invoke(String method, Map<String, dynamic> args) async {
    final raw = await JSBridgeManager.instance.pluginTools.invoke(
      "habits",
      method,
      args,
    );
    return jsonDecode(raw as String);
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp("aboutme-habits-tools-");
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = HabitsPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    configs = jsonDecode(
      File("lib/plugins/agent_chat/tools/habits.json").readAsStringSync(),
    );
  });

  tearDownAll(() async {
    await temporary.delete(recursive: true);
  });

  test("工具描述方法名均有 JS API 回调", () {
    final methods = plugin.defineJSAPI();
    for (final key in configs.keys) {
      expect(methods.containsKey(key), isTrue, reason: key);
    }
  });

  test("createHabit 按扁平化 schema 传空串 id 时自动生成非空 id", () async {
    // 扁平化 schema 会把未用参数填成空串/0，映射层需视为未传
    final created = await invoke("createHabit", {
      "title": "每天阅读",
      "durationMinutes": 30,
      "id": "",
      "habitId": "",
      "icon": "",
      "image": "",
      "notes": "",
      "skillId": "",
    });
    expect(created.containsKey("error"), isFalse, reason: '$created');
    final habitId = created["id"] as String;
    expect(habitId.isNotEmpty, isTrue, reason: '$created');

    final habits = await invoke("getHabits", {"offset": 0, "count": 100});
    final list = (habits as Map)["data"] as List;
    expect(list.any((h) => h["id"] == habitId), isTrue);

    final habit = await invoke("getHabitById", {"habitId": habitId});
    expect(habit["skillId"], anyOf(isNull, isNot("")));

    expect(
      (await invoke("deleteHabit", {"habitId": habitId}))["success"],
      isTrue,
    );
  });

  test("createHabit 传入不存在的 skillId 时自动创建并绑定技能", () async {
    const skillId = "skill-auto-created-regression";
    final created = await invoke("createHabit", {
      "title": "学习 React",
      "durationMinutes": 90,
      "skillId": skillId,
    });
    expect(created.containsKey("error"), isFalse, reason: '$created');
    expect(created["skillId"], skillId);

    final habitId = created["id"] as String;
    final skill = await invoke("getSkillById", {"skillId": skillId});
    expect(skill.containsKey("error"), isFalse, reason: '$skill');
    expect(skill["id"], skillId);
    expect(skill["title"], skillId);

    expect(
      (await invoke("deleteHabit", {"habitId": habitId}))["success"],
      isTrue,
    );
    expect(
      (await invoke("deleteSkill", {"skillId": skillId}))["success"],
      isTrue,
    );
  });

  test("createHabit 传入已有 skillId 时复用技能", () async {
    const skillId = "skill-existing-regression";
    final createdSkill = await invoke("createSkill", {
      "id": skillId,
      "title": "已有技能",
    });
    expect(createdSkill.containsKey("error"), isFalse, reason: '$createdSkill');

    final created = await invoke("createHabit", {
      "title": "练习已有技能",
      "durationMinutes": 30,
      "skillId": skillId,
    });
    expect(created.containsKey("error"), isFalse, reason: '$created');
    expect(created["skillId"], skillId);

    final skill = await invoke("getSkillById", {"skillId": skillId});
    expect(skill["title"], "已有技能");

    expect(
      (await invoke("deleteHabit", {"habitId": created["id"]}))["success"],
      isTrue,
    );
    expect(
      (await invoke("deleteSkill", {"skillId": skillId}))["success"],
      isTrue,
    );
  });

  test("无记录的习惯查询完成记录返回空数组而非幻影记录", () async {
    final created = await invoke("createHabit", {
      "title": "冥想",
      "durationMinutes": 15,
    });
    final habitId = created["id"] as String;

    // 修复前：readPath 缺文件返回 {} 默认值，被当成单条记录
    // （id 空、时长 0、date 为查询时刻）
    final records = await invoke("getCompletionRecords", {
      "habitId": habitId,
      "count": 100,
    });
    final recordList = records is Map ? records["data"] as List : records as List;
    expect(recordList, isEmpty);

    final stats = await invoke("getStats", {"habitId": habitId});
    expect(stats["completionCount"], 0);
    expect(stats["totalDurationMinutes"], 0);

    await invoke("deleteHabit", {"habitId": habitId});
  });

  test("checkIn 未传时长时回退习惯目标时长", () async {
    final created = await invoke("createHabit", {
      "title": "健身",
      "durationMinutes": 60,
    });
    final habitId = created["id"] as String;

    // 扁平化 schema 把未用数值参数填成 0，须视为未传
    final record = await invoke("checkIn", {
      "habitId": habitId,
      "durationSeconds": 0,
      "durationMinutes": 0,
      "notes": "",
    });
    expect(record.containsKey("error"), isFalse, reason: '$record');
    expect(record["durationSeconds"], 3600);

    final stats = await invoke("getStats", {"habitId": habitId});
    expect(stats["completionCount"], 1);
    expect(stats["totalDurationMinutes"], 60);

    await invoke("deleteHabit", {"habitId": habitId});
  });

  test("getTimerStatus 对编造的 habitId 报错而非返回已停止", () async {
    final created = await invoke("createHabit", {
      "title": "阅读",
      "durationMinutes": 30,
    });
    final habitId = created["id"] as String;

    // 修复前：任意不存在的 habitId 都返回 {isRunning: false}，误导模型
    final fabricated = await invoke("getTimerStatus", {
      "habitId": "habit-not-exist-999",
    });
    expect((fabricated as Map)["error"], contains("习惯不存在"));

    final real = await invoke("getTimerStatus", {"habitId": habitId});
    expect((real as Map)["isRunning"], isFalse);

    await invoke("deleteHabit", {"habitId": habitId});
  });

  test("首次种子完成记录写入 habits/records/<id>.json（无双重后缀）", () async {
    // createDefaultHabits 仅在习惯列表为空时写入，先清掉前面用例的残留
    await AboutmeDataService.instance.writePath('habits/habits.json', []);
    await plugin.getHabitController().createDefaultHabits();

    // 修复前写入 <id>.json.json，读取路径永远找不到种子记录
    final raw = await AboutmeDataService.instance.readPath(
      'habits/records/habit-run-001.json',
    );
    expect(raw is List, isTrue, reason: '$raw');
    expect((raw as List).length, 5);

    final records = await invoke("getCompletionRecords", {
      "habitId": "habit-run-001",
      "count": 100,
    });
    final list = records is Map ? records["data"] as List : records as List;
    expect(list.length, 5);
    for (final record in list) {
      expect((record["id"] as String).isNotEmpty, isTrue);
    }
  });
}
