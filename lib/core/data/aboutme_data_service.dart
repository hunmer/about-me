import 'dart:async';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../app_initializer.dart' show globalStorage;
import '../storage/device_identity.dart';
import '../storage/storage_manager.dart' show StorageManager;

/// 全局统一数据入口：客户端所有插件数据操作只需要调用这里。
///
/// 由 SDK 自动决定走哪条路：
/// - 已配置远端 → `AboutmeData.remote`（离线时保持 HTTP 模式，
///   客户端离线期间服务端/MCP 仍可继续处理同一份数据）
/// - 显式本地配置 → `AboutmeData.local`（本机 app_data 直处理）
///
/// 文件层（readPath/writePath）与业务层（call/get，与 REST/MCP 同一套
/// 处理器）共用同一数据区；本地写操作与远端 WS 变更汇入同一事件流，
/// 插件经 [onPluginChanged] 订阅实现局部刷新。
class AboutmeDataService with WidgetsBindingObserver {
  AboutmeDataService._();

  static final AboutmeDataService instance = AboutmeDataService._();

  AboutmeData? _data;
  bool get isInitialized => _data != null;

  /// 初始化后可用；初始化前访问抛错（时序 bug 早暴露）
  AboutmeData get data {
    final value = _data;
    if (value == null) {
      throw StateError('AboutmeDataService 尚未初始化');
    }
    return value;
  }

  bool get isRemote => _data?.isRemote ?? false;
  void revalidate() => _data?.revalidate();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) revalidate();
  }

  /// 在 StorageManager.initialize() 之后调用：
  /// 按显式配置选择后端，HTTP 离线时不切换数据源。
  Future<void> initialize() async {
    if (_data != null) return;
    WidgetsFlutterBinding.ensureInitialized().addObserver(this);

    if (globalStorage.isRemote) {
      final remote = AboutmeData.remote(
        serverUrl: (globalStorage.backend as HttpStorage).serverUrl,
        apiKey: (globalStorage.backend as HttpStorage).credential,
        deviceId: DeviceIdentity.id,
      );
      _data = remote;
      debugPrint('[AboutmeData] HTTP 模式');
      return;
    }

    _data = kIsWeb
        ? AboutmeData.withPersistence(
            StoragePluginPersistence(
              StorageManager.localBackend,
              identity: 'web-local',
            ),
            source: 'client',
          )
        : AboutmeData.local(
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

  // ==================== configs 设置统一通道（system 域命令封装） ====================
  // key 为 configs/ 下相对路径（如 'app_config.json'、'bill/settings.json'），
  // 落盘与旧 configs/ 布局原位一致（零迁移）。失败（损坏/无效 key 等）抛
  // StateError，调用方按各自缺省语义兜底；configs/ 前缀原始文件写已封闭。

  Future<dynamic> getConfig(String key) async {
    final result = await call('system', 'getConfig', {'key': key});
    if (result['success'] != true) {
      throw StateError('getConfig($key) 失败: ${result['error']}');
    }
    return (result['data'] as Map)['value'];
  }

  Future<void> setConfig(String key, dynamic value) async {
    final result = await call('system', 'setConfig', {
      'key': key,
      'value': value,
    });
    if (result['success'] != true) {
      throw StateError('setConfig($key) 失败: ${result['error']}');
    }
  }

  Future<bool> deleteConfig(String key) async {
    final result = await call('system', 'deleteConfig', {'key': key});
    if (result['success'] != true) {
      throw StateError('deleteConfig($key) 失败: ${result['error']}');
    }
    return (result['data'] as Map)['deleted'] == true;
  }

  // ==================== 局部刷新订阅 ====================

  /// 订阅插件数据变更（远端 REST/MCP/其它设备写入触发；
  /// 本机写入由 controller 自身维护内存状态，自动跳过），
  /// 防抖 [debounceMs] 后回调。返回取消函数。
  ///
  /// 典型用法：controller 构造时订阅并 reload + notifyListeners，
  /// dispose 时调用取消函数。
  VoidCallback onPluginChanged(
    String pluginId,
    VoidCallback onChanged, {
    int debounceMs = 300,
  }) {
    late StreamSubscription<DataChangeEvent> sub;
    Timer? timer;
    sub = data.events.listen((event) {
      if (event.pluginId != pluginId) return;
      // 本机写操作：controller 已同步更新内存状态，无需重载
      if (event.source == 'client' || event.source == 'local') return;

      timer?.cancel();
      timer = Timer(Duration(milliseconds: debounceMs), onChanged);
    });
    return () {
      sub.cancel();
      timer?.cancel();
    };
  }

  /// 远端 WS 变更转发（StorageWebSocketService 调用）
  void publishRemoteEvent(
    String pluginId,
    String filePath, {
    Map<String, dynamic>? metadata,
  }) {
    _data?.publishRemoteEvent(
      DataChangeEvent(
        pluginId: pluginId,
        filePattern: filePath,
        source: 'remote',
        resource: metadata?['resource'] as String?,
        entityId: metadata?['entityId'] as String?,
        version: metadata?['version'] as int?,
        mutationId: metadata?['mutationId'] as String?,
        action: metadata?['action'] as String?,
        sourceDeviceId: metadata?['source_device_id'] as String?,
      ),
    );
  }
}
