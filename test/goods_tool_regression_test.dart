import 'dart:convert';
import 'dart:io';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/js_bridge/js_bridge_manager.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:aboutme/plugins/goods/goods_plugin.dart';
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
  late GoodsPlugin plugin;
  late PathProviderPlatform originalPaths;
  late Map<String, dynamic> configs;

  Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    final raw = await JSBridgeManager.instance.pluginTools.invoke(
      "goods",
      method,
      args,
    );
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp("aboutme-goods-tools-");
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(temporary.path);
    SharedPreferences.setMockInitialValues({});
    globalStorage = StorageManager(storage: _TemporaryStorage(temporary));
    await AboutmeDataService.instance.initialize();
    await PluginManager.instance.setStorageManager(globalStorage);
    plugin = GoodsPlugin();
    await PluginManager.instance.registerPlugin(plugin);
    configs = jsonDecode(
      File("lib/plugins/agent_chat/tools/goods.json").readAsStringSync(),
    );
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = originalPaths;
    await temporary.delete(recursive: true);
  });

  test("工具描述方法名均有 JS API 回调，且无废弃 find* 残留", () {
    final methods = plugin.defineJSAPI();
    for (final key in configs.keys) {
      final methodName = key.startsWith("goods_")
          ? key.substring("goods_".length)
          : key;
      expect(methods.containsKey(methodName), isTrue, reason: key);
    }
    const obsolete = [
      "findWarehouseBy",
      "findWarehouseById",
      "findWarehouseByName",
      "findGoodsItemBy",
      "findGoodsItemById",
      "findGoodsItemByName",
    ];
    for (final method in obsolete) {
      expect(configs.containsKey(method), isFalse, reason: method);
      expect(configs.containsKey("goods_$method"), isFalse, reason: method);
      expect(methods.containsKey(method), isFalse, reason: method);
    }
  });

  test("按 schema 契约参数（title/warehouseId）完成仓库增查改删", () async {
    // 扁平化 schema 会把未用参数填成空串/0，映射层需视为未传
    final created = await invoke("createWarehouse", {
      "title": "书房",
      "id": "",
      "iconCode": 0,
      "colorValue": 0,
      "name": "",
    });
    expect(created.containsKey("error"), isFalse, reason: '$created');
    expect(created["name"], "书房");
    final warehouseId = created["id"] as String;

    final fetched = await invoke("getWarehouse", {"warehouseId": warehouseId});
    expect(fetched["id"], warehouseId);
    expect(fetched["name"], "书房");

    final updated = await invoke("updateWarehouse", {
      "warehouseId": warehouseId,
      "title": "藏书阁",
      "iconCode": 0,
    });
    expect(updated.containsKey("error"), isFalse, reason: '$updated');
    expect(updated["name"], "藏书阁");

    final deleted = await invoke("deleteWarehouse", {
      "warehouseId": warehouseId,
    });
    expect(deleted["success"], isTrue);
    expect(
      (await invoke("getWarehouse", {"warehouseId": warehouseId}))["error"],
      isNotNull,
    );
  });

  test("warehouseId 为空串时回退取 id 参数", () async {
    final created = await invoke("createWarehouse", {"title": "车库"});
    final id = created["id"] as String;
    final fetched = await invoke("getWarehouse", {
      "warehouseId": "",
      "id": id,
    });
    expect(fetched["id"], id);
  });

  test("getGoodsItem 按 schema 契约参数 itemId 取物品", () async {
    final warehouse = await invoke("createWarehouse", {"title": "书房"});
    final item = await invoke("createGoodsItem", {
      "warehouseId": warehouse["id"],
      "itemData": jsonEncode({"title": "MacBook Pro"}),
    });
    expect(item.containsKey("error"), isFalse, reason: '$item');

    final fetched = await invoke("getGoodsItem", {"itemId": item["id"]});
    expect(fetched["id"], item["id"]);
    expect(fetched["name"], "MacBook Pro");

    await invoke("deleteWarehouse", {"warehouseId": warehouse["id"]});
  });
}
