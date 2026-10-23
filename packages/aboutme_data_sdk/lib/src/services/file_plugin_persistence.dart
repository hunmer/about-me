import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../storage_errors.dart';
import 'persistent_plugin_backend.dart';

/// 文件系统只能在 SDK 平台适配层使用。临时文件与目标处于同一目录。
class FilePluginPersistence implements PluginPersistence, BinaryPluginPersistence {
  FilePluginPersistence(String rootDir) : identity = p.canonicalize(rootDir);
  @override
  final String identity;
  static int _sequence = 0;

  Future<File> _file(String path) async {
    final parts = path.split('/');
    if (parts.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.contains('\\') ||
          part.contains(':') ||
          part.contains('\u0000'),
    )) {
      throw const StoragePathException();
    }
    var current = identity;
    for (final part in parts) {
      current = p.join(current, part);
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const StoragePathException();
      }
    }
    return File(current);
  }

  @override
  Future<String?> read(String path) async {
    final file = await _file(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<Uint8List?> readBytes(String path, int maxBytes) async {
    final file = await _file(path);
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      throw const StorageException(StorageErrorKind.invalidRequest, '旧资源超过导入大小上限');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const StorageException(StorageErrorKind.invalidRequest, '旧资源超过导入大小上限');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  Future<void> write(String path, String content) async {
    final target = await _file(path);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.sdk-$pid-${_sequence++}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
      await temp.rename(target.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  @override
  Future<bool> remove(String path) async {
    final file = await _file(path);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<List<String>> keys(String prefix) async {
    final root = Directory(identity);
    if (!await root.exists()) return [];
    final result = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final key = p.relative(entity.path, from: identity).replaceAll('\\', '/');
      if (key.startsWith(prefix) &&
          !key.startsWith('.sdk/') &&
          !key.contains('.sdk-'))
        result.add(key);
    }
    return result..sort();
  }
}
