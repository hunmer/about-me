import 'dart:typed_data';

/// 存储内文件的元信息（size/updatedAt 可能为 null，取决于后端实现）
class StorageFileInfo {
  const StorageFileInfo({required this.path, this.size, this.updatedAt});

  /// 相对存储根目录的路径
  final String path;

  /// 文件大小（字节）
  final int? size;

  /// 最后修改时间
  final DateTime? updatedAt;
}

/// 存储后端统一接口：客户端本地存储 / Web 存储 / HTTP 远端存储都实现它。
abstract class StorageInterface {
  Future<void> saveData(String key, String value);
  Future<String?> loadData(String key);
  Future<void> removeData(String key);
  Future<bool> hasData(String key);
  Future<void> saveJson(String key, dynamic data);
  Future<dynamic> loadJson(String key, [dynamic defaultValue]);
  Future<List<String>> getKeysWithPrefix(String prefix);
  Future<void> clearWithPrefix(String prefix);

  /// 列出前缀下所有文件的元信息。
  /// 默认实现只回填路径（无 size/updatedAt），支持元数据的后端自行覆写。
  Future<List<StorageFileInfo>> listFileInfos(String prefix) async {
    final keys = await getKeysWithPrefix(prefix);
    return [for (final key in keys) StorageFileInfo(path: key)];
  }

  Future<void> createDirectory(String path);
  Future<String> readString(String path);
  Future<void> writeString(String path, String content);
  Future<void> deleteFile(String path);

  // 二进制文件读写方法
  Future<Uint8List?> readBytes(String path);
  Future<void> writeBytes(String path, Uint8List bytes);
}
