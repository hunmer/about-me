import 'dart:convert';
import 'dart:typed_data';

import 'http_storage.dart';
import 'storage_interface.dart';

/// 纯 Dart 数据管理门面：在 [StorageInterface] 之上提供键值/JSON/文件
/// 三类数据操作与内存缓存，是客户端 StorageManager 与服务端共用的数据核心。
///
/// 缓存策略与客户端历史行为保持一致：仅本地后端缓存（远端后端不缓存，
/// 由服务端 WebSocket 广播驱动刷新）。
class DataStore {
  DataStore({required StorageInterface storage}) : _storage = storage;

  final _cache = <String, dynamic>{};

  StorageInterface _storage;

  /// 当前存储后端
  StorageInterface get backend => _storage;

  bool get isRemote => _storage is HttpStorage;

  /// 初始化/回退时替换后端（同时清空缓存避免跨后端脏读）。
  /// 仅供宿主（如客户端 StorageManager）在初始化阶段调用。
  void setBackend(StorageInterface storage) {
    _storage = storage;
    clearCache();
  }

  /// 保存数据
  Future<void> save(String key, dynamic value) async {
    if (value is String) {
      await _saveString(key, value);
    } else {
      await _saveJson(key, value);
    }
  }

  /// 读取数据
  Future<dynamic> load(String key, [dynamic defaultValue]) async {
    return await _readJson(key, defaultValue);
  }

  /// 删除数据
  Future<void> remove(String key) async {
    _cache.remove(key);
    await _storage.removeData(key);
  }

  /// 检查数据是否存在
  Future<bool> exists(String key) async {
    return _cache.containsKey(key) || await _storage.hasData(key);
  }

  /// 清除指定前缀的数据
  Future<void> clearPrefix(String prefix) async {
    await _storage.clearWithPrefix(prefix);
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// 获取指定前缀的所有键
  Future<List<String>> getKeysWithPrefix(String prefix) async {
    return await _storage.getKeysWithPrefix(prefix);
  }

  /// 获取插件存储路径
  String getPluginPath(String pluginId) => pluginId;

  /// 插件数据操作
  Future<void> savePluginData(String pluginId, String key, dynamic value) =>
      save('${getPluginPath(pluginId)}/$key', value);

  Future<dynamic> loadPluginData(
    String pluginId,
    String key, [
    dynamic defaultValue,
  ]) => load('${getPluginPath(pluginId)}/$key', defaultValue);

  /// 清除内存缓存
  void clearCache() => _cache.clear();

  /// 读取数据 (别名方法)
  Future<dynamic> read(String key, [dynamic defaultValue]) =>
      readJson(key, defaultValue);

  /// 写入数据 (别名方法)
  Future<void> write(String key, dynamic value) => save(key, value);

  /// 读取文件内容
  Future<String> readFile(String path, [String defaultValue = '']) async {
    try {
      final String str = await readString(path);
      return str.isEmpty ? defaultValue : str;
    } catch (e) {
      return defaultValue;
    }
  }

  /// 写入文件内容
  Future<void> writeFile(String path, String content) =>
      writeString(path, content);

  /// 获取插件存储路径 (公开方法)
  String getPluginStoragePath(String id) => getPluginPath(id);

  /// 创建目录
  Future<void> createDirectory(String path) async {
    await _storage.createDirectory(path);
  }

  /// 读取字符串内容
  Future<String> readString(String path) async {
    return await _storage.readString(path);
  }

  /// 写入字符串内容
  Future<void> writeString(String path, String content) async {
    await _storage.writeString(path, content);
  }

  /// 删除文件
  Future<void> deleteFile(String path) async {
    await _storage.deleteFile(path);
  }

  /// 写入JSON数据
  Future<void> writeJson(String path, dynamic data) async {
    await _storage.saveJson(path, data);
  }

  /// 检查文件是否存在
  Future<bool> fileExists(String path) async {
    return await exists(path);
  }

  /// 删除数据 (别名方法)
  Future<void> delete(String key) async {
    await remove(key);
  }

  /// 获取字符串数据
  Future<String?> getString(String key) async {
    try {
      return await readString(key);
    } catch (e) {
      return null;
    }
  }

  /// 设置字符串数据
  Future<void> setString(String key, String value) async {
    await writeString(key, value);
  }

  /// 读取JSON数据
  Future<dynamic> readJson(String path, [dynamic defaultValue]) async {
    return await _storage.loadJson(path, defaultValue);
  }

  // ignore: unintended_html_in_doc_comment
  /// 安全读取JSON数据，确保返回Map<String, dynamic>
  Future<Map<String, dynamic>> readSafeJson(String path) async {
    final dynamic jsonData = await _storage.loadJson(path);
    if (jsonData == null) return {};

    final Map<String, dynamic> data = {};
    if (jsonData is Map) {
      jsonData.forEach((key, value) {
        data[key.toString()] = value;
      });
    }
    return data;
  }

  /// 确保插件目录存在
  Future<void> ensurePluginDirectoryExists(String pluginId) async {
    await createDirectory(getPluginPath(pluginId));
  }

  /// 读取插件文件
  Future<String> readPluginFile(String pluginId, String fileName) async {
    final path = '${getPluginPath(pluginId)}/$fileName';
    return await readString(path);
  }

  /// 写入插件文件
  Future<void> writePluginFile(
    String pluginId,
    String fileName,
    String content,
  ) async {
    final path = '${getPluginPath(pluginId)}/$fileName';
    await writeString(path, content);
  }

  /// 读取二进制文件
  Future<Uint8List?> readBytes(String path) async {
    return await _storage.readBytes(path);
  }

  /// 写入二进制文件
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await _storage.writeBytes(path, bytes);
  }

  // 私有方法
  Future<void> _saveString(String key, String value) async {
    if (!isRemote) _cache[key] = value;
    await _storage.saveData(key, value);
  }

  Future<String> _readString(String key) async {
    if (!isRemote && _cache.containsKey(key)) return _cache[key] as String;
    final content = await _storage.loadData(key);
    if (content == null) throw Exception('数据不存在: $key');
    if (!isRemote) _cache[key] = content;
    return content;
  }

  Future<void> _saveJson(String key, dynamic data) async {
    final jsonStr = jsonEncode(data);
    await _saveString(key, jsonStr);
  }

  Future<dynamic> _readJson(String key, [dynamic defaultValue]) async {
    try {
      final jsonStr = await _readString(key);
      return jsonDecode(jsonStr);
    } catch (e) {
      return defaultValue;
    }
  }
}
