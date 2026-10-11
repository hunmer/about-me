import 'plugin_data.dart';

/// Web 平台占位：本地文件后端不可用（Web 无文件系统），
/// 运行时调用会抛错；编译期保证 AboutmeData 可在 Web 引用。
class LocalPluginBackend implements PluginData {
  LocalPluginBackend(String rootDir, {String source = 'local', this.onEvent});

  final void Function(DataChangeEvent event)? onEvent;

  Never get _unsupported =>
      throw UnsupportedError('Web 平台不支持本地文件后端，请使用 AboutmeData.remote');

  @override
  Future<dynamic> read(String pluginId, String fileName) async => _unsupported;

  @override
  Future<void> write(String pluginId, String fileName, dynamic data) async =>
      _unsupported;

  @override
  Future<bool> delete(String pluginId, String fileName) async => _unsupported;

  @override
  Future<List<String>> listFiles(String pluginId, [String? pattern]) async =>
      _unsupported;

  @override
  void notifyChanged(String pluginId, String filePattern) {}

  // 全路径方法（Web 占位，与 IO 版保持签名一致）
  Future<dynamic> readPath(String path) async => _unsupported;
  Future<String> readPathText(String path) async => _unsupported;
  Future<void> writePath(String path, dynamic data) async => _unsupported;
  Future<bool> deletePath(String path) async => _unsupported;
  Future<bool> existsPath(String path) async => _unsupported;
  Future<List<String>> listPathKeys(String prefix) async => _unsupported;
  Future<void> clearPathPrefix(String prefix) async => _unsupported;
}
