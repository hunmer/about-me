import 'dart:async';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart';

import '../app_initializer.dart' show globalStorage;
import '../storage/device_identity.dart';
import '../storage/storage_manager.dart' show StorageManager;

/// 全局统一数据入口：客户端所有插件数据操作只需要调用这里。
///
/// 由 SDK 自动决定走哪条路：
/// - 远端已配置且可用 → `AboutmeData.remote`（REST，数据在服务端，
///   客户端离线期间服务端/MCP 仍可继续处理同一份数据）
/// - 否则 → `AboutmeData.local`（本机 app_data 直处理）
///
/// 文件层（readPath/writePath）与业务层（call/get，与 REST/MCP 同一套
/// 处理器）共用同一数据区；本地写操作与远端 WS 变更汇入同一事件流，
/// 插件经 [onPluginChanged] 订阅实现局部刷新。
class AboutmeDataService {
  AboutmeDataService._();

  static final AboutmeDataService instance = AboutmeDataService._();

  AboutmeData? _data;

  /// 初始化后可用；初始化前访问抛错（时序 bug 早暴露）
  AboutmeData get data {
    final value = _data;
    if (value == null) {
      throw StateError('AboutmeDataService 尚未初始化');
    }
    return value;
  }

  bool get isRemote => _data?.isRemote ?? false;

  /// 在 StorageManager.initialize() 之后调用：
  /// 远端可用则 remote，否则本机直处理。
  Future<void> initialize() async {
    if (_data != null) return;

    if (globalStorage.isRemote) {
      final remote = AboutmeData.remote(
        serverUrl: (globalStorage.backend as HttpStorage).serverUrl,
        apiKey: (globalStorage.backend as HttpStorage).credential,
        deviceId: DeviceIdentity.id,
      );
      if (await remote.testConnection()) {
        _data = remote;
        debugPrint('[AboutmeData] 远程模式（REST）');
        return;
      }
      debugPrint('[AboutmeData] 远端不可用，回退本地模式');
    }

    _data = AboutmeData.local(
      (await StorageManager.appDataDirectory()).path,
      source: 'client',
    );
    debugPrint('[AboutmeData] 本地模式');
  }

  // ==================== 文件层（全路径，客户端迁移兼容层） ====================
  // path 形如 'todo/tasks.json'，与原 StorageManager.read/write 语义对齐。

  Future<dynamic> readPath(String path, [dynamic defaultValue]) =>
      data.readPath(path, defaultValue);

  Future<String> readPathText(String path) => data.readPathText(path);

  Future<void> writePath(String path, dynamic content) =>
      data.writePath(path, content);

  Future<bool> deletePath(String path) => data.deletePath(path);

  Future<bool> existsPath(String path) => data.existsPath(path);

  Future<List<String>> listPathKeys(String prefix) => data.listPathKeys(prefix);

  Future<void> clearPathPrefix(String prefix) => data.clearPathPrefix(prefix);

  // ==================== 插件分区文件层 ====================

  Future<dynamic> readFile(String pluginId, String fileName) =>
      data.readFile(pluginId, fileName);

  Future<void> writeFile(String pluginId, String fileName, dynamic content) =>
      data.writeFile(pluginId, fileName, content);

  // ==================== 业务层（与 REST/MCP 同一套处理器） ====================

  Future<Map<String, dynamic>> call(
    String pluginId,
    String action, [
    Map<String, dynamic> params = const {},
  ]) => data.call(pluginId, action, params);

  Future<Map<String, dynamic>> get(
    String pluginId,
    String action, [
    Map<String, dynamic> params = const {},
  ]) => data.get(pluginId, action, params);

  // ==================== 局部刷新订阅 ====================

  final _pluginTimers = <String, Timer?>{};

  /// 订阅插件数据变更（远端 REST/MCP/其它设备写入触发；
  /// 本机写入由 controller 自身维护内存状态，自动跳过），
  /// 防抖 [debounceMs] 后回调。返回取消函数。
  ///
  /// 典型用法：controller 构造时订阅并 reload + notifyListeners，
  /// dispose 时调用取消函数。
  VoidCallback onPluginChanged(String pluginId, VoidCallback onChanged,
      {int debounceMs = 300}) {
    late StreamSubscription<DataChangeEvent> sub;
    sub = data.events.listen((event) {
      if (event.pluginId != pluginId) return;
      // 本机写操作：controller 已同步更新内存状态，无需重载
      if (event.source == 'client' || event.source == 'local') return;

      _pluginTimers[pluginId]?.cancel();
      _pluginTimers[pluginId] = Timer(
        Duration(milliseconds: debounceMs),
        onChanged,
      );
    });
    return () {
      sub.cancel();
      _pluginTimers[pluginId]?.cancel();
      _pluginTimers.remove(pluginId);
    };
  }

  /// 远端 WS 变更转发（StorageWebSocketService 调用）
  void publishRemoteEvent(String pluginId, String filePath) {
    _data?.publishRemoteEvent(
      DataChangeEvent(
        pluginId: pluginId,
        filePattern: filePath,
        source: 'remote',
      ),
    );
  }
}
