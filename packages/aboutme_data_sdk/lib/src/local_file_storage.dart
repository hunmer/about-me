import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'storage_errors.dart';

const _storageDirName = '.storage';

class RawFileMetadata {
  const RawFileMetadata({
    required this.etag,
    required this.size,
    required this.modifiedAt,
  });

  final String etag;
  final int size;
  final DateTime modifiedAt;
}

class RawFileEntry {
  const RawFileEntry({
    required this.path,
    required this.size,
    required this.updatedAt,
  });

  final String path;
  final int size;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'path': path,
    'size': size,
    'updated_at': updatedAt.toIso8601String(),
  };
}

enum RawFileWriteStatus { written, preconditionFailed }

class RawFileWriteResult {
  const RawFileWriteResult(this.status, this.metadata);

  final RawFileWriteStatus status;
  final RawFileMetadata? metadata;
}

enum RawFileDeleteStatus { deleted, notFound, preconditionFailed }

/// 服务端本地文件存储：按用户隔离的原始字节文件 CRUD，
/// 与 nodejs 服务器 `FileStorageService` 的数据目录布局和语义完全兼容。
///
/// 目录结构:
/// {baseDir}/
/// ├── users/{userId}/.storage/...   ← Storage API 文件（密文）
/// └── logs/storage_audit.log
class LocalFileStorage {
  LocalFileStorage(this.baseDir);

  final String baseDir;
  final _rawFileLocks = <String, Future<void>>{};

  String getUserDir(String userId) => p.join(baseDir, 'users', userId);

  String getStorageDir(String userId) =>
      p.join(getUserDir(userId), _storageDirName);

  Future<void> initialize() async {
    for (final dir in [
      baseDir,
      p.join(baseDir, 'users'),
      p.join(baseDir, 'auth'),
      p.join(baseDir, 'auth', 'api_keys'),
      p.join(baseDir, 'logs'),
      p.join(baseDir, 'exports'),
    ]) {
      await Directory(dir).create(recursive: true);
    }
  }

  /// 将不可信相对路径限制在用户的 Storage API 数据目录中。
  String resolveStoragePath(String userId, String filePath) {
    if (filePath.isEmpty || filePath.contains('\\') || p.isAbsolute(filePath)) {
      throw const StoragePathException();
    }

    final segments = filePath.split('/');
    final windowsDrive = RegExp(r'^[a-zA-Z]:$');
    if (segments.any(
      (segment) =>
          segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          windowsDrive.hasMatch(segment),
    )) {
      throw const StoragePathException();
    }

    final root = p.canonicalize(getStorageDir(userId));
    final resolved = p.canonicalize(p.joinAll([root, ...segments]));
    if (resolved == root || !resolved.startsWith('$root${p.separator}')) {
      throw const StoragePathException();
    }
    return resolved;
  }

  Future<void> assertNoSymlink(String root, String target) async {
    var current = root;
    final relative = p.relative(target, from: root);
    for (final segment in relative.split(p.separator)) {
      current = p.join(current, segment);
      try {
        final stat = await File(current).stat();
        if (stat.type == FileSystemEntityType.link) {
          throw const StoragePathException();
        }
      } on FileSystemException {
        return;
      }
    }
  }

  RawFileMetadata _metadataOf(Uint8List data, FileStat stat) =>
      RawFileMetadata(
        etag: '"${sha256.convert(data).toString()}"',
        size: data.length,
        modifiedAt: stat.modified,
      );

  Future<T> _withRawFileLock<T>(
    String key,
    Future<T> Function() operation,
  ) async {
    final previous = _rawFileLocks[key] ?? Future<void>.value();
    final operationDone = Completer<void>();
    _rawFileLocks[key] = operationDone.future;
    try {
      await previous;
    } catch (_) {
      // 前一个操作失败不阻塞当前操作
    }
    try {
      return await operation();
    } finally {
      operationDone.complete();
      if (identical(_rawFileLocks[key], operationDone.future)) {
        _rawFileLocks.remove(key);
      }
    }
  }

  Future<({Uint8List data, RawFileMetadata metadata})?> readRawFile(
    String userId,
    String filePath,
  ) async {
    final root = p.canonicalize(getStorageDir(userId));
    final fullPath = resolveStoragePath(userId, filePath);
    await assertNoSymlink(root, fullPath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    final data = Uint8List.fromList(await file.readAsBytes());
    final stat = await file.stat();
    return (data: data, metadata: _metadataOf(data, stat));
  }

  Future<RawFileMetadata?> getRawFileMetadata(
    String userId,
    String filePath,
  ) async {
    final result = await readRawFile(userId, filePath);
    return result?.metadata;
  }

  Future<RawFileWriteResult> writeRawFile(
    String userId,
    String filePath,
    Uint8List data, {
    String? ifMatch,
    String? ifNoneMatch,
    bool force = false,
  }) {
    return _withRawFileLock('$userId:$filePath', () async {
      final root = p.canonicalize(getStorageDir(userId));
      final fullPath = resolveStoragePath(userId, filePath);
      await Directory(root).create(recursive: true);
      await assertNoSymlink(root, fullPath);

      final existing = await getRawFileMetadata(userId, filePath);
      if (!force) {
        if (ifMatch != null && existing?.etag != ifMatch) {
          return RawFileWriteResult(
            RawFileWriteStatus.preconditionFailed,
            existing,
          );
        }
        if (ifNoneMatch == '*' && existing != null) {
          return RawFileWriteResult(
            RawFileWriteStatus.preconditionFailed,
            existing,
          );
        }
        if (ifMatch == null && ifNoneMatch != '*') {
          return RawFileWriteResult(
            RawFileWriteStatus.preconditionFailed,
            existing,
          );
        }
      }

      await Directory(p.dirname(fullPath)).create(recursive: true);
      await assertNoSymlink(root, p.dirname(fullPath));
      final tempPath = p.join(
        p.dirname(fullPath),
        '.${p.basename(fullPath)}.$pid.${const Uuid().v4()}.tmp',
      );
      final tempFile = File(tempPath);
      try {
        await tempFile.writeAsBytes(data, flush: true);
        await tempFile.rename(fullPath);
      } finally {
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      }

      final stat = await File(fullPath).stat();
      return RawFileWriteResult(
        RawFileWriteStatus.written,
        _metadataOf(data, stat),
      );
    });
  }

  Future<RawFileDeleteStatus> deleteRawFile(
    String userId,
    String filePath, {
    String? ifMatch,
    bool force = false,
  }) {
    return _withRawFileLock('$userId:$filePath', () async {
      final existing = await getRawFileMetadata(userId, filePath);
      if (existing == null) return RawFileDeleteStatus.notFound;
      if (!force && (ifMatch == null || existing.etag != ifMatch)) {
        return RawFileDeleteStatus.preconditionFailed;
      }
      final fullPath = resolveStoragePath(userId, filePath);
      await File(fullPath).delete();
      return RawFileDeleteStatus.deleted;
    });
  }

  Future<List<RawFileEntry>> listRawFiles(
    String userId, {
    String prefix = '',
  }) async {
    final root = p.canonicalize(getStorageDir(userId));
    final normalizedPrefix = prefix.replaceAll(RegExp(r'/+$'), '');
    if (normalizedPrefix.isNotEmpty) {
      resolveStoragePath(userId, normalizedPrefix);
    }
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return [];

    final files = <RawFileEntry>[];
    await _walk(rootDir, (file, stat) {
      final relative = p.relative(file.path, from: root).replaceAll('\\', '/');
      if (normalizedPrefix.isEmpty || relative.startsWith(normalizedPrefix)) {
        files.add(
          RawFileEntry(
            path: relative,
            size: stat.size,
            updatedAt: stat.modified,
          ),
        );
      }
    });
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<int> clearRawFiles(String userId, String prefix) async {
    final normalizedPrefix = prefix.replaceAll(RegExp(r'/+$'), '');
    if (normalizedPrefix.isEmpty) throw const StoragePathException();
    final files = await listRawFiles(userId, prefix: normalizedPrefix);
    for (final entry in files) {
      await File(resolveStoragePath(userId, entry.path)).delete();
    }
    return files.length;
  }

  Future<void> logStorageAudit({
    required String userId,
    required String action,
    required String filePath,
    String? details,
  }) async {
    final logFile = File(p.join(baseDir, 'logs', 'storage_audit.log'));
    await logFile.parent.create(recursive: true);
    final entry = jsonEncode({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'userId': userId,
      'action': action,
      'filePath': filePath,
      if (details != null) 'details': details,
    });
    await logFile.writeAsString('$entry\n', mode: FileMode.append);
  }

  /// 用户目录存储统计（文件数/目录数/总字节数），供 user-info 接口使用。
  Future<({int fileCount, int folderCount, int totalSize})> userStorageStats(
    String userId,
  ) async {
    final userDir = Directory(getUserDir(userId));
    if (!await userDir.exists()) {
      return (fileCount: 0, folderCount: 0, totalSize: 0);
    }
    var fileCount = 0;
    var folderCount = 0;
    var totalSize = 0;
    await _walk(userDir, (file, stat) {
      fileCount++;
      totalSize += stat.size;
    }, onDirectory: (_) => folderCount++);
    return (
      fileCount: fileCount,
      folderCount: folderCount,
      totalSize: totalSize,
    );
  }

  Future<void> _walk(
    Directory dir,
    FutureOr<void> Function(File file, FileStat stat) visit, {
    void Function(String path)? onDirectory,
  }) async {
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      final stat = await entry.stat();
      if (stat.type == FileSystemEntityType.link) continue;
      if (stat.type == FileSystemEntityType.directory) {
        onDirectory?.call(entry.path);
        await _walk(Directory(entry.path), visit, onDirectory: onDirectory);
      } else if (stat.type == FileSystemEntityType.file) {
        await visit(File(entry.path), stat);
      }
    }
  }
}
