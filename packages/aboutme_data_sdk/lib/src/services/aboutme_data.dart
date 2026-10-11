import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../http_storage.dart';
import '../storage_config.dart' show StorageAuthType;
import '../storage_errors.dart';
import 'action_resolver.dart';
import 'invoker.dart';
// 条件导入：IO 平台用真实文件后端，Web 用占位
import 'local_plugin_backend_stub.dart'
    if (dart.library.io) 'local_plugin_backend.dart';
import 'plugin_data.dart';

export 'plugin_data.dart' show DataChangeEvent;

/// Aboutme 数据入口：客户端只需要调用这里的方法，
/// SDK 自动决定走本机直处理还是远程 REST：
/// - 本地模式：业务 handler 直接读写本地目录（明文 JSON），零网络
/// - 远程模式：文件层走 `/api/v1/storage/files/*`，业务层走 `/api/v1/plugins/*`
///
/// 两种模式的调用方代码完全一致；数据变更通过 [events] 流对外广播。
class AboutmeData {
  AboutmeData._({
    required this.isRemote,
    LocalPluginBackend? localBackend,
    RemotePluginBackend? remoteBackend,
    HttpStorage? fileStorage,
  }) : _localBackend = localBackend,
       _remoteBackend = remoteBackend,
       _fileStorage = fileStorage;

  /// 本地模式：数据直接读写 [rootDir]（如客户端 app_data 目录）。
  factory AboutmeData.local(String rootDir, {String source = 'local'}) {
    final controller = StreamController<DataChangeEvent>.broadcast();
    final backend = LocalPluginBackend(
      rootDir,
      source: source,
      onEvent: controller.add,
    );
    return AboutmeData._(isRemote: false, localBackend: backend)
      .._events = controller;
  }

  /// 远程模式：连接存储服务器（X-API-Key 认证，明文传输）。
  factory AboutmeData.remote({
    required String serverUrl,
    required String apiKey,
    String? deviceId,
    http.Client? client,
    Duration timeout = const Duration(seconds: 15),
  }) {
    final storage = HttpStorage(
      serverUrl: serverUrl,
      authType: StorageAuthType.apiKey,
      credential: apiKey,
      client: client,
      timeout: timeout,
      deviceId: deviceId,
    );
    return AboutmeData._(
      isRemote: true,
      remoteBackend: RemotePluginBackend(storage),
      fileStorage: storage,
    ).._events = StreamController<DataChangeEvent>.broadcast();
  }

  final bool isRemote;
  final LocalPluginBackend? _localBackend;
  final RemotePluginBackend? _remoteBackend;
  final HttpStorage? _fileStorage;
  final PluginInvoker _invoker = PluginInvoker();
  StreamController<DataChangeEvent>? _events;

  /// 数据变更事件流（本地模式自动广播；远程模式由宿主接入 WS 后转发）。
  Stream<DataChangeEvent> get events =>
      _events?.stream ?? const Stream.empty();

  /// 远程事件转发：宿主（客户端 WS 服务）收到服务端广播后调用，
  /// 让本地订阅者与远端变更保持一致。
  void publishRemoteEvent(DataChangeEvent event) => _events?.add(event);

  PluginData get _pluginData => isRemote ? _remoteBackend! : _localBackend!;

  // ==================== 文件层（通用数据文件读写） ====================

  /// 读取插件数据文件（明文 JSON；不存在返回 null）。
  Future<dynamic> readFile(String pluginId, String fileName) async {
    if (!isRemote) {
      return _localBackend!.read(pluginId, fileName);
    }
    return _remoteBackend!.read(pluginId, fileName);
  }

  /// 写入插件数据文件（对象或数组，明文 JSON）。
  Future<void> writeFile(String pluginId, String fileName, dynamic data) {
    return _pluginData.write(pluginId, fileName, data);
  }

  /// 删除插件数据文件。
  Future<bool> deleteFile(String pluginId, String fileName) {
    return _pluginData.delete(pluginId, fileName);
  }

  // ==================== 全路径读写（客户端迁移兼容层） ====================
  // path 形如 'todo/tasks.json'；本地/远程行为一致。

  /// 读取 JSON（不存在/解析失败返回 [defaultValue]，缺省 `{}`，
  /// 与 StorageManager.read 的历史语义对齐）。
  Future<dynamic> readPath(String path, [dynamic defaultValue]) async {
    if (!isRemote) {
      final result = await _localBackend!.readPath(path);
      return result ?? defaultValue ?? <String, dynamic>{};
    }
    final text = await _fileStorage!.readString(path);
    if (text.isEmpty) return defaultValue ?? <String, dynamic>{};
    try {
      return jsonDecode(text);
    } catch (_) {
      return defaultValue ?? <String, dynamic>{};
    }
  }

  /// 读取文本文件（不存在返回空串）。
  Future<String> readPathText(String path) async {
    if (!isRemote) return _localBackend!.readPathText(path);
    final text = await _fileStorage!.readString(path);
    return text;
  }

  /// 写入 JSON（或字符串原样写入），本地写触发变更事件。
  Future<void> writePath(String path, dynamic data) async {
    if (!isRemote) {
      await _localBackend!.writePath(path, data);
      return;
    }
    final content = data is String ? data : jsonEncode(data);
    await _fileStorage!.writeBytes(
      path,
      Uint8List.fromList(utf8.encode(content)),
    );
  }

  /// 删除文件（路径不存在返回 false）。
  Future<bool> deletePath(String path) async {
    if (!isRemote) return _localBackend!.deletePath(path);
    try {
      await _fileStorage!.deleteFile(path);
      return true;
    } on StorageException {
      return false;
    }
  }

  /// 文件是否存在。
  Future<bool> existsPath(String path) async {
    if (!isRemote) return _localBackend!.existsPath(path);
    return await _fileStorage!.hasData(path);
  }

  /// 列出前缀下所有文件键。
  Future<List<String>> listPathKeys(String prefix) {
    if (!isRemote) return _localBackend!.listPathKeys(prefix);
    return _fileStorage!.getKeysWithPrefix(prefix);
  }

  /// 清除前缀下所有文件。
  Future<void> clearPathPrefix(String prefix) {
    if (!isRemote) return _localBackend!.clearPathPrefix(prefix);
    return _fileStorage!.clearWithPrefix(prefix);
  }

  // ==================== 业务层（统一插件服务） ====================

  /// 调用插件业务方法：action 为 handler 名（如 `create` / `getStats` /
  /// `completeTask`），SDK 依据路由表自动解析出 method 与路径
  /// （路径中的 `:param` 从 [params] 填充），与 REST/MCP 使用完全相同的
  /// 处理器（一套逻辑）。返回 `{success, data?, error?, code?, timestamp}`。
  Future<Map<String, dynamic>> call(
    String pluginId,
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    final resolved = resolveAction(pluginId, action, params);
    if (resolved == null) {
      return {
        'success': false,
        'error': '未知业务方法: $pluginId.$action',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
    final (method, path) = resolved;
    final isQuery = method == 'get';
    if (!isRemote) {
      return _invoker.invoke(
        _localBackend!,
        method,
        '/api/v1/plugins/$pluginId$path',
        query: isQuery ? params : null,
        body: isQuery ? null : params,
      );
    }
    if (isQuery) {
      return _remoteBackend!.get(pluginId, path.substring(1), params);
    }
    return _remoteBackend!.call(pluginId, path.substring(1), params);
  }

  /// GET 类业务调用的语义别名（与 [call] 相同，按路由表解析）。
  Future<Map<String, dynamic>> get(
    String pluginId,
    String action, [
    Map<String, dynamic> params = const {},
  ]) => call(pluginId, action, params);

  /// 探测远程服务器可用性；远程不可用返回 false（宿主可据此回退本地）。
  Future<bool> testConnection() async {
    if (!isRemote) return true;
    try {
      await _fileStorage!.testConnection();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 远程插件业务后端：文件层走 storage files API，业务层走插件 REST。
class RemotePluginBackend implements PluginData {
  RemotePluginBackend(this._storage);

  final HttpStorage _storage;

  Future<Map<String, dynamic>> call(
    String pluginId,
    String action,
    Map<String, dynamic> params,
  ) {
    return _storage.postJson('/api/v1/plugins/$pluginId/$action', params);
  }

  Future<Map<String, dynamic>> get(
    String pluginId,
    String action,
    Map<String, dynamic> params,
  ) {
    return _storage.getJson('/api/v1/plugins/$pluginId/$action', params);
  }

  @override
  Future<dynamic> read(String pluginId, String fileName) async {
    final bytes = await _storage.readBytes('$pluginId/$fileName');
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String pluginId, String fileName, dynamic data) {
    return _storage.writeBytes(
      '$pluginId/$fileName',
      Uint8List.fromList(utf8.encode(jsonEncode(data))),
    );
  }

  @override
  Future<bool> delete(String pluginId, String fileName) async {
    try {
      await _storage.deleteFile('$pluginId/$fileName');
      return true;
    } on StorageException {
      return false;
    }
  }

  @override
  Future<List<String>> listFiles(String pluginId, [String? pattern]) async {
    final keys = await _storage.getKeysWithPrefix('$pluginId/');
    final fileNames = keys
        .map(
          (k) =>
              k.startsWith('$pluginId/')
                  ? k.substring(pluginId.length + 1)
                  : k,
        )
        .toList();
    if (pattern == null) return fileNames;
    final regex = RegExp('^' + pattern.replaceAll('*', '.*') + r'$');
    return fileNames.where((name) => regex.hasMatch(name)).toList();
  }

  @override
  void notifyChanged(String pluginId, String filePattern) {
    // 远程模式：服务端负责 WS 广播，本地无需处理
  }
}
