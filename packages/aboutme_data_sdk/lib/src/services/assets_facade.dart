import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_models/shared_models.dart';

import 'aboutme_data.dart';
import 'query_store.dart';
import 'asset_materialization.dart';
import 'host_file_input.dart';

class AssetsFacade {
  AssetsFacade(this.data);
  final AboutmeData data;
  final _handles = <String, Future<MaterializedAsset>>{};
  final _paths = <String, String>{};
  bool _closed = false;

  Future<PaginatedResult<AssetDto>> list({String? mediaTypePrefix, int offset = 0, int limit = 50}) async {
    final response = await data.get('assets', 'list', {
      if (mediaTypePrefix != null) 'mediaTypePrefix': mediaTypePrefix, 'offset': offset, 'limit': limit});
    return PaginatedResult.fromJson(_value(response),
      (raw) => AssetDto.fromJson(Map<String, dynamic>.from(raw as Map)));
  }

  Future<Uint8List> readSelectedFile(String selectedPath) =>
    readHostSelectedFile(selectedPath, 16 * 1024 * 1024);

  Future<Uint8List?> readLegacySticker(String sourcePath) async {
    final result = await data.get('assets', 'readLegacySticker', {'sourcePath': sourcePath});
    if (result['code'] == 'NOT_FOUND') return null;
    return base64Decode(_value(result)['content'] as String);
  }

  Future<AssetDto> importSelectedFile(String selectedPath, {
    required String fileName, String mediaType = 'application/octet-stream',
    String? clientMutationId,
  }) async => upload(await readHostSelectedFile(selectedPath, 16 * 1024 * 1024),
      fileName: fileName, mediaType: mediaType, clientMutationId: clientMutationId);

  Future<MaterializedAsset> materialize(String id) async {
    if (_closed) throw StateError('SDK 资源服务已关闭');
    final metadata = await getMetadata(id);
    final handle = await materializeAssetBytes(await read(id), metadata.fileName);
    if (_closed) {
      await handle.dispose();
      throw StateError('SDK 资源服务已关闭');
    }
    return handle;
  }

  /// 兼容仍要求同步路径的播放器，生命周期限定为当前 SDK 会话。
  Future<String> resolvePath(String id) async {
    if (_closed) throw StateError('SDK 资源服务已关闭');
    final operation = _handles.putIfAbsent(id, () => materialize(id));
    try {
      final handle = await operation;
      if (_closed) throw StateError('SDK 资源服务已关闭');
      return _paths[id] = handle.path;
    } catch (_) {
      if (identical(_handles[id], operation)) _handles.remove(id);
      rethrow;
    }
  }

  String? resolvedPath(String id) => _paths[id];
  String? referenceForResolvedPath(String path) {
    for (final entry in _paths.entries) {
      if (entry.value == path) return 'asset://${entry.key}';
    }
    return null;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final operations = _handles.values.toList();
    _handles.clear();
    _paths.clear();
    for (final operation in operations) {
      MaterializedAsset handle;
      try { handle = await operation; } catch (_) { continue; }
      await handle.dispose();
    }
  }

  Future<AssetDto> upload(Uint8List bytes, {required String fileName,
    String mediaType = 'application/octet-stream', String? clientMutationId}) async {
    if (bytes.length > 16 * 1024 * 1024) throw ArgumentError('单个资源上限 16 MiB');
    final result = await data.call('assets', 'upload', {'content': base64Encode(bytes),
      'fileName': fileName, 'mediaType': mediaType,
      if (clientMutationId != null) 'clientMutationId': clientMutationId});
    return AssetDto.fromJson(_value(result));
  }

  /// 原地替换资源内容（id/fileName/mediaType 不变，size/sha256 随内容更新）。
  /// 引用不变，持有该资产的业务数据无需变更；已物化句柄随之失效，
  /// 下次 resolvePath 重新物化新内容。
  Future<AssetDto> replace(String id, Uint8List bytes) async {
    if (bytes.length > 16 * 1024 * 1024) throw ArgumentError('单个资源上限 16 MiB');
    final result = await data.call('assets', 'replace',
        {'id': id, 'content': base64Encode(bytes)});
    final operation = _handles.remove(id);
    _paths.remove(id);
    if (operation != null) {
      final handle = await operation;
      await handle.dispose();
    }
    return AssetDto.fromJson(_value(result));
  }

  static const chunkedUploadLimit = 256 * 1024 * 1024;

  /// 分块上传大资源（上限 256 MiB）：init → append×N → complete，
  /// 端到端 sha256 校验；[onProgress] 每块回调（已传块数/总块数）。
  Future<AssetDto> uploadChunked(Uint8List bytes, {required String fileName,
    String mediaType = 'application/octet-stream',
    void Function(int received, int total)? onProgress}) async {
    if (bytes.isEmpty || bytes.length > chunkedUploadLimit) {
      throw ArgumentError('分块上传上限 256 MiB');
    }
    final init = _value(await data.call('assets', 'initUpload', {
      'fileName': fileName, 'mediaType': mediaType,
      'size': bytes.length, 'sha256': sha256.convert(bytes).toString(),
    }));
    final uploadId = init['uploadId'] as String;
    final chunkBytes = init['chunkBytes'] as int;
    final totalChunks = init['totalChunks'] as int;
    for (var index = 0; index < totalChunks; index++) {
      final start = index * chunkBytes;
      final chunk = bytes.sublist(start,
          (start + chunkBytes) > bytes.length ? bytes.length : start + chunkBytes);
      _value(await data.call('assets', 'appendChunk',
          {'uploadId': uploadId, 'index': index, 'content': base64Encode(chunk)}));
      onProgress?.call(index + 1, totalChunks);
    }
    return AssetDto.fromJson(
        _value(await data.call('assets', 'completeUpload', {'uploadId': uploadId})));
  }

  Future<AssetDto> getMetadata(String id) async => AssetDto.fromJson(
    _value(await data.get('assets', 'getMetadata', {'id': id})));

  Future<Uint8List> read(String id) async {
    final record = _value(await data.get('assets', 'read', {'id': id}));
    final bytes = base64Decode(record['content'] as String);
    if (record['id'] != id || bytes.length != record['size'] ||
        sha256.convert(bytes).toString() != record['sha256']) {
      throw QueryFailure({'success': false, 'code': 'CORRUPT_DATA', 'error': '资源校验失败'});
    }
    return bytes;
  }

  Future<bool> remove(String id, {int? expectedVersion, String? clientMutationId}) async {
    final result = await data.call('assets', 'remove', {'id': id,
      if (expectedVersion != null) 'expectedVersion': expectedVersion,
      if (clientMutationId != null) 'clientMutationId': clientMutationId});
    if (result['code'] == 'NOT_FOUND') return false;
    _value(result);
    final operation = _handles.remove(id);
    _paths.remove(id);
    if (operation != null) {
      final handle = await operation;
      await handle.dispose();
    }
    return true;
  }

  Map<String, dynamic> _value(Map<String, dynamic> result) {
    if (result['success'] != true) throw QueryFailure(result);
    return Map<String, dynamic>.from(result['data'] as Map);
  }
}
