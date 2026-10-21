import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/plugins/store/store_plugin.dart';
import 'package:aboutme/plugins/agent_chat/models/tool_config.dart';
import 'package:aboutme/plugins/agent_chat/services/tool_schema_builder.dart';
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
  Future<void> saveData(String path, String value) => writeString(path, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late StorePlugin plugin;
  late PathProviderPlatform originalPaths;
  late Map<String, dynamic> configs;

  Future<Map<String, dynamic>> invokeCreate(dynamic price) async {
    final result = await JSBridgeManager.instance.pluginTools
        .invoke('store', 'createProduct', {
          'name': '整数解析回归商品',
          'description': '工具调用回归测试',
          'price': price,
          'stock': 10.0,
          'exchangeStart': '2026-10-21T00:00:00.000Z',
          'exchangeEnd': '2027-10-21T23:59:59.999Z',
          'useDuration': 30.0,
        });
    return jsonDecode(result as String) as Map<String, dynamic>;
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp('aboutme-store-tools-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = StorePlugin();
    await PluginManager.instance.registerPlugin(plugin);
    configs =
        jsonDecode(
              File(
                'lib/plugins/agent_chat/tools/store.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  tearDownAll(() async {
    plugin.controller.dispose();
    plugin.dispose();
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test('商品工具整数 schema 与 JSON double 整数参数可创建', () async {
    for (final method in ['createProduct', 'updateProduct']) {
      final tool = configs['store_$method'] as Map<String, dynamic>;
      final schema = ToolSchemaBuilder.buildSchemaMap(
        ToolConfig.fromJson(tool).parameters,
      );
      final properties = schema['properties'] as Map;
      for (final parameter in tool['parameters'] as List<dynamic>) {
        if (['price', 'stock', 'useDuration'].contains(parameter['name'])) {
          expect(
            parameter['type'],
            'integer',
            reason: '$method.${parameter['name']}',
          );
          expect(properties[parameter['name']]['type'], 'integer');
        }
      }
    }

    final result = await invokeCreate(100.0);
    expect(result['error'], isNull);
    expect(result['price'], 100);
    expect(result['stock'], 10);
    expect(result['useDuration'], 30);
    final updated = await plugin.useCase.updateProduct({
      'id': result['id'],
      'price': 200.0,
      'stock': 5.0,
      'useDuration': 60.0,
    });
    expect(updated.isSuccess, isTrue);
    expect(updated.dataOrNull?['price'], 200);
    expect(updated.dataOrNull?['stock'], 5);
    expect(updated.dataOrNull?['useDuration'], 60);
  });

  test('商品价格不接受小数', () async {
    final result = await invokeCreate(100.5);
    expect(result['error'], contains('price 必须是整数'));
  });
}
