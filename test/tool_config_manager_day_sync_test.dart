import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_config_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
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
  final bundledPath = 'lib/plugins/agent_chat/tools/day.json';

  setUpAll(() async {
    final temporary = await Directory.systemTemp.createTemp('aboutme-day-sync-');
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));

    // 仅提供 day 的 assets 描述，其余 asset 请求返回不存在
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != bundledPath) return null;
      final bytes = await File(key).readAsBytes();
      return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    });

    // 模拟老安装：本地已是旧命名（getMemorialDays 等）的 day 配置
    const legacyMethods = [
      'getMemorialDays',
      'createMemorialDay',
      'updateMemorialDay',
      'deleteMemorialDay',
      'getDaysUntil',
      'getUpcomingDays',
      'findMemorialDayBy',
      'findMemorialDayById',
      'findMemorialDayByName',
    ];
    final legacy = {
      for (final method in legacyMethods)
        method: {
          'title': method,
          'description': method,
          'parameters': <Object?>[],
          'returns': {'type': 'object', 'description': ''},
          'enabled': true,
        },
    };
    await AboutmeDataService.instance.initialize();
    await AboutmeDataService.instance.writePath(
      'agent_chat/tools/day.json',
      jsonEncode(legacy),
    );
    // index 存在即视为老安装，跳过首装全量拷贝
    await AboutmeDataService.instance.writePath(
      'agent_chat/tools/index.json',
      jsonEncode([
        for (final method in legacyMethods) ['day_$method', method],
      ]),
    );
  });

  test('老安装启动后 day 工具配置对齐为新命名', () async {
    await ToolConfigManager.instance.initialize();

    final raw = ToolConfigManager.instance.getPluginTools('day')!.tools.keys;
    // PluginToolSet 内存 key 带插件前缀，与 FC 分发时的 methodName 剥前缀逻辑一致
    final methods = raw
        .map((k) => k.startsWith('day_') ? k.substring(4) : k)
        .toSet();
    expect(methods, {
      'getDays',
      'getDayById',
      'createDay',
      'updateDay',
      'deleteDay',
      'getDaysUntil',
      'getUpcoming',
      'findDayBy',
      'findDayByName',
    });
    expect(methods.where((m) => m.contains('MemorialDay')), isEmpty);
  });
}
