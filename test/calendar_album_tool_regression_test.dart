import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/calendar_album/calendar_album_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';

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
  Future<void> saveData(String path, String value) => writeString(path, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late CalendarAlbumPlugin plugin;
  late PathProviderPlatform originalPaths;
  late Map<String, dynamic> configs;

  Future<dynamic> invoke(String method, Map<String, dynamic> args) async {
    final result = await JSBridgeManager.instance.pluginTools
        .invoke('calendar_album', method, args);
    return jsonDecode(result as String);
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('aboutme-calendar-tools-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = CalendarAlbumPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    configs =
        jsonDecode(
              File(
                'lib/plugins/agent_chat/tools/calendar_album.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  tearDownAll(() async {
    plugin.calendarController?.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test('getEntriesForDate 接受 dateStr 参数（回归: 缺少必需参数 date）', () async {
    final result = await invoke('getEntriesForDate', {'dateStr': '2025-11-15'});
    expect(result, isA<List<dynamic>>());
  });

  test('addEntry 接受 dateStr 并在缺省时默认当前时间（回归: 缺少必需参数 createdAt）', () async {
    final created = await invoke('addEntry', {
      'title': '工具回归日记',
      'content': 'dateStr 创建回归',
      'dateStr': '2025-11-15',
    }) as Map<String, dynamic>;
    expect(created['error'], isNull);
    expect(created['createdAt'], startsWith('2025-11-15'));

    final byDate =
        await invoke('getEntriesForDate', {'dateStr': '2025-11-15'})
            as List<dynamic>;
    expect(byDate.any((e) => e['id'] == created['id']), isTrue);

    final createdNow = await invoke('addEntry', {
      'title': '工具回归日记(默认时间)',
      'content': '默认当前时间',
    }) as Map<String, dynamic>;
    expect(createdNow['error'], isNull);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    expect(createdNow['createdAt'], startsWith(today));

    // 清理
    expect(
      (await invoke('deleteEntry', {'id': createdNow['id']}))
          as Map<String, dynamic>,
      isNotNull,
    );
    await invoke('deleteEntry', {'id': created['id']});
  });

  test('updateEntry/getEntryById/deleteEntry 按 id 完成 CRUD', () async {
    final created = await invoke('addEntry', {
      'title': 'CRUD 回归',
      'content': '初始内容',
      'dateStr': '2025-11-15',
    }) as Map<String, dynamic>;
    final id = created['id'] as String;

    final updated =
        await invoke('updateEntry', {'id': id, 'content': '更新后的内容'})
            as Map<String, dynamic>;
    expect(updated['error'], isNull);
    expect(updated['content'], '更新后的内容');

    final fetched = await invoke('getEntryById', {'id': id});
    expect(fetched['error'], isNull);
    expect(fetched['title'], 'CRUD 回归');

    final deleted = await invoke('deleteEntry', {'id': id});
    expect(deleted['success'], isTrue);

    final byDate =
        await invoke('getEntriesForDate', {'dateStr': '2025-11-15'})
            as List<dynamic>;
    expect(byDate.any((e) => e['id'] == id), isFalse);
  });

  test('工具 schema 参数名与实现对齐', () {
    String? requiredParam(String method) {
      final params = configs[method]['parameters'] as List<dynamic>?;
      if (params == null) return null;
      for (final p in params) {
        if (p['required'] == true) return p['name'] as String;
      }
      return null;
    }

    expect(requiredParam('getEntriesForDate'), 'dateStr');
    for (final method in ['updateEntry', 'deleteEntry', 'getEntryById']) {
      expect(requiredParam(method), 'id', reason: method);
    }

    final addParams = (configs['addEntry']['parameters'] as List<dynamic>)
        .map((p) => p['name'])
        .toList();
    expect(addParams, contains('dateStr'));
    expect(addParams, isNot(contains('createdAt')));
  });
}
