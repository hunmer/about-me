import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'plugin_data.dart';

/// 本地插件数据后端：明文 JSON 直接读写本地目录。
///
/// 客户端本地模式传入应用数据目录（如 app_data），
/// 服务端传入用户目录（DATA_DIR/users/{userId}）。
class LocalPluginBackend implements PluginData {
  LocalPluginBackend(this.rootDir, {String source = 'local', this.onEvent})
    : _source = source;

  final String rootDir;

  /// 变更事件接收者（服务端转 WS 广播；本地模式默认由事件总线接管）。
  final void Function(DataChangeEvent event)? onEvent;
  final String _source;

  @override
  Future<dynamic> read(String pluginId, String fileName) async {
    final file = File(p.join(rootDir, pluginId, fileName));
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String pluginId, String fileName, dynamic data) async {
    final file = File(p.join(rootDir, pluginId, fileName));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data), flush: true);
    notifyChanged(pluginId, fileName);
  }

  @override
  Future<bool> delete(String pluginId, String fileName) async {
    final file = File(p.join(rootDir, pluginId, fileName));
    if (!await file.exists()) return false;
    await file.delete();
    notifyChanged(pluginId, fileName);
    return true;
  }

  @override
  Future<List<String>> listFiles(String pluginId, [String? pattern]) async {
    final dir = Directory(p.join(rootDir, pluginId));
    if (!await dir.exists()) return [];
    final files = <String>[];
    await for (final entity in dir.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.endsWith('.json')) {
        if (pattern == null ||
            RegExp('^' + pattern.replaceAll('*', '.*') + r'$').hasMatch(name)) {
          files.add(name);
        }
      }
    }
    return files;
  }

  @override
  void notifyChanged(String pluginId, String filePattern) {
    onEvent?.call(
      DataChangeEvent(
        pluginId: pluginId,
        filePattern: filePattern,
        source: _source,
      ),
    );
  }

  // ==================== 全路径读写（客户端迁移兼容层） ====================
  // path 形如 'todo/tasks.json'（首段为插件 ID，用于事件归属）

  Future<dynamic> readPath(String path) async {
    final file = File(p.join(rootDir, path));
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<String> readPathText(String path) async {
    final file = File(p.join(rootDir, path));
    return await file.exists() ? await file.readAsString() : '';
  }

  Future<void> writePath(String path, dynamic data) async {
    final file = File(p.join(rootDir, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      data is String ? data : jsonEncode(data),
      flush: true,
    );
    _notifyPathChanged(path);
  }

  Future<bool> deletePath(String path) async {
    final file = File(p.join(rootDir, path));
    if (!await file.exists()) return false;
    await file.delete();
    _notifyPathChanged(path);
    return true;
  }

  Future<bool> existsPath(String path) =>
      File(p.join(rootDir, path)).exists();

  Future<List<String>> listPathKeys(String prefix) async {
    final dir = Directory(p.join(rootDir, prefix));
    if (!await dir.exists()) return [];
    final keys = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        keys.add(p.relative(entity.path, from: rootDir).replaceAll('\\', '/'));
      }
    }
    return keys;
  }

  Future<void> clearPathPrefix(String prefix) async {
    for (final key in await listPathKeys(prefix)) {
      await File(p.join(rootDir, key)).delete();
    }
  }

  void _notifyPathChanged(String path) {
    final pluginId = path.contains('/') ? path.split('/').first : path;
    notifyChanged(pluginId, path.contains('/') ? path.split('/').skip(1).join('/') : path);
  }
}
