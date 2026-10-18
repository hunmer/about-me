import 'dart:io';

import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:path/path.dart' as path;

/// Agent 与 agent_chat 频道使用的隔离文件空间。
///
/// 所有传入路径都是相对于空间根目录的路径，禁止跳出根目录。
class AgentFileSpaceService {
  AgentFileSpaceService._();

  static final AgentFileSpaceService instance = AgentFileSpaceService._();

  static const agentDirectoryName = 'agent_files';
  static const channelDirectoryName = 'agent_chat_files';

  Future<Directory> directoryForAgent(String agentId) async =>
      _ensureDirectory(path.join(agentDirectoryName, _safeId(agentId)));

  Future<Directory> directoryForChannel(String conversationId) async =>
      _ensureDirectory(
        path.join(channelDirectoryName, _safeId(conversationId)),
      );

  Future<List<Map<String, dynamic>>> listFiles({
    String? agentId,
    String? conversationId,
    String relativePath = '',
    bool recursive = false,
    String space = 'auto',
  }) async {
    final result = <Map<String, dynamic>>[];
    for (final fileSpace in _spaces(
      agentId,
      conversationId,
      requested: space,
    )) {
      final root = await fileSpace.directory();
      final resolved = _resolveInside(root, relativePath);
      final directory = resolved is Directory
          ? resolved
          : Directory(resolved.path);
      if (!await directory.exists()) continue;
      final entities = await directory.list(recursive: recursive).toList();
      for (final entity in entities) {
        final stat = await entity.stat();
        final isDirectory = stat.type == FileSystemEntityType.directory;
        result.add({
          'space': fileSpace.name,
          'path': path.relative(entity.path, from: root.path),
          'name': path.basename(entity.path),
          'type': isDirectory ? 'directory' : 'file',
          'size': isDirectory ? 0 : stat.size,
          'modifiedAt': stat.modified.toIso8601String(),
        });
      }
    }
    result.sort((a, b) {
      final space = _spacePriority(a['space']) - _spacePriority(b['space']);
      if (space != 0) return space;
      return a['path'].toString().compareTo(b['path'].toString());
    });
    return result;
  }

  Future<String?> readFile({
    required String relativePath,
    String? agentId,
    String? conversationId,
    String space = 'auto',
  }) async {
    for (final candidate in _spaces(
      agentId,
      conversationId,
      requested: space,
    )) {
      final entity = _resolveInside(await candidate.directory(), relativePath);
      if (entity is File && await entity.exists()) {
        return entity.readAsString();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> writeFile({
    required String relativePath,
    required String content,
    String? agentId,
    String? conversationId,
    String space = 'agent',
  }) async {
    final candidates = _spaces(agentId, conversationId, requested: space);
    if (candidates.isEmpty) {
      throw ArgumentError('没有可写入的文件空间');
    }
    final root = await candidates.first.directory();
    final target = _resolveInside(root, relativePath);
    if (target.path == root.path) {
      throw ArgumentError('文件路径不能为空');
    }
    await target.parent.create(recursive: true);
    await (target as File).writeAsString(content, flush: true);
    return {
      'space': candidates.first.name,
      'path': path.relative(target.path, from: root.path),
      'size': await target.length(),
    };
  }

  List<_FileSpace> _spaces(
    String? agentId,
    String? conversationId, {
    String requested = 'auto',
  }) {
    final spaces = <_FileSpace>[];
    final wantAgent = requested == 'auto' || requested == 'agent';
    final wantChannel = requested == 'auto' || requested == 'channel';
    if (wantAgent && agentId != null && agentId.trim().isNotEmpty) {
      spaces.add(_FileSpace('agent', () => directoryForAgent(agentId)));
    }
    if (wantChannel &&
        conversationId != null &&
        conversationId.trim().isNotEmpty) {
      spaces.add(
        _FileSpace('channel', () => directoryForChannel(conversationId)),
      );
    }
    return spaces.take(2).toList();
  }

  Future<Directory> _ensureDirectory(String relative) async {
    final base = await StorageManager.appDataDirectory();
    final directory = Directory(path.join(base.path, relative));
    await directory.create(recursive: true);
    return directory;
  }

  FileSystemEntity _resolveInside(Directory root, String relativePath) {
    final normalized = relativePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty || normalized == '.') return root;
    if (path.isAbsolute(normalized) || normalized.split('/').contains('..')) {
      throw ArgumentError('文件路径必须位于空间根目录内');
    }
    final resolved = path.normalize(path.join(root.path, normalized));
    final rootPath = path.normalize(root.path);
    final rootPrefix = rootPath.endsWith(path.separator)
        ? rootPath
        : '$rootPath${path.separator}';
    if (resolved != rootPath && !resolved.startsWith(rootPrefix)) {
      throw ArgumentError('文件路径必须位于空间根目录内');
    }
    return File(resolved);
  }

  String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');

  int _spacePriority(Object? space) => space == 'agent' ? 0 : 1;
}

class _FileSpace {
  final String name;
  final Future<Directory> Function() directory;

  const _FileSpace(this.name, this.directory);
}
