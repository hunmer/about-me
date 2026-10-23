import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../storage_errors.dart';
import '../../legacy_write_policy.dart';
import '../plugin_data.dart';
import '../types.dart';
import '../asset_references.dart';

/// JSON/base64 首版资源协议，内容和描述位于同一事务记录。
/// 仅允许 SDK 生成的资源 ID，调用方不能指定持久化路径。
const maxAssetBytes = 16 * 1024 * 1024;
const maxAssetEncodedLength = ((maxAssetBytes + 2) ~/ 3) * 4;

String checkedAssetId(dynamic value) {
  if (value is! String ||
      !RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$').hasMatch(value)) {
    throw const FormatException('无效资源 ID');
  }
  return value;
}

Future<Map<String, dynamic>?> readAsset(PluginData data, String id) async {
  final raw = await data.read('assets', '${checkedAssetId(id)}.json');
  if (raw == null) return null;
  try {
    if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1 ||
        raw['id'] != id || raw['fileName'] is! String ||
        raw['mediaType'] is! String || raw['createdAt'] is! String ||
        DateTime.tryParse(raw['createdAt'] as String) == null ||
        raw['size'] is! int || raw['size'] < 0 || raw['size'] > maxAssetBytes ||
        raw['content'] is! String || (raw['content'] as String).length > maxAssetEncodedLength) {
      throw const FormatException();
    }
    final bytes = base64Decode(raw['content'] as String);
    if (bytes.length != raw['size'] || sha256.convert(bytes).toString() != raw['sha256']) {
      throw const FormatException();
    }
    return raw;
  } on FormatException {
    throw StorageException(StorageErrorKind.invalidData, '资源内容或描述损坏: $id');
  }
}

Map<String, dynamic> assetMetadata(Map<String, dynamic> raw) =>
    Map<String, dynamic>.from(raw)..remove('content')..remove('schemaVersion')..remove('references');

/// 旧资源迁移白名单：已封闭域 + 已收口待封闭域（openai/toolbox/scripts_center
/// 的二进制通道）+ 贴图目录下的媒体文件。
const _migratableMediaPattern =
    r'\.(png|gif|jpe?g|webp|svg|apng|bmp|mp4|mov|webm|mp3|m4a|aac|wav)$';

bool isMigratableLegacyPath(String path) {
  final normalized = path.replaceAll('\\', '/').toLowerCase();
  final roots = <String>{
    ...LegacyWritePolicy.migratedDomains,
    'openai',
    'toolbox',
    'scripts_center',
    'stickers',
  };
  return roots.any((root) => normalized == root || normalized.startsWith('$root/')) &&
      RegExp(_migratableMediaPattern).hasMatch(normalized);
}

Future<Map<String, dynamic>> _assetIndex(PluginData data) async {
  final value = await data.read('assets', 'index.json');
  if (value == null) return {};
  if (value is! Map<String, dynamic> || value['schemaVersion'] != 1 || value['assets'] is! Map<String, dynamic>) {
    throw const StorageException(StorageErrorKind.invalidData, '资源索引损坏');
  }
  final index = Map<String, dynamic>.from(value['assets'] as Map);
  for (final entry in index.entries) {
    final record = entry.value;
    if (record is! Map || record['id'] != entry.key || record['fileName'] is! String ||
        record['mediaType'] is! String || record['size'] is! int ||
        DateTime.tryParse(record['createdAt']?.toString() ?? '') == null) {
      throw const StorageException(StorageErrorKind.invalidData, '资源索引条目损坏');
    }
  }
  return index;
}

Future<Map<String, dynamic>> _persistAsset(
  PluginData data,
  Map<String, dynamic> index,
  List<int> bytes,
  String fileName,
  String mediaType,
) async {
  final id = const Uuid().v4();
  final record = <String, dynamic>{'schemaVersion': 1, 'id': id,
    'fileName': fileName, 'mediaType': mediaType, 'size': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'content': base64Encode(bytes)};
  await data.write('assets', '$id.json', record);
  index[id] = assetMetadata(record);
  await data.write('assets', 'index.json', {'schemaVersion': 1, 'assets': index});
  return record;
}

/// 旧路径 → 资源 ID 的迁移记录（重复迁移同一路径直接复用既有资源）。
Future<Map<String, dynamic>> _migrationMap(PluginData data) async {
  final value = await data.read('assets', 'legacy_migration.json');
  if (value == null) return <String, dynamic>{};
  if (value is! Map<String, dynamic>) {
    throw const StorageException(StorageErrorKind.invalidData, '资源迁移记录损坏');
  }
  return Map<String, dynamic>.from(value);
}

String _mediaTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'png' => 'image/png', 'gif' => 'image/gif', 'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp', 'svg' => 'image/svg+xml', 'apng' => 'image/apng',
    'bmp' => 'image/bmp', 'mp4' => 'video/mp4', 'mov' => 'video/quicktime',
    'webm' => 'video/webm', 'mp3' => 'audio/mpeg', 'm4a' => 'audio/mp4',
    'aac' => 'audio/aac', 'wav' => 'audio/wav',
    _ => 'application/octet-stream',
  };
}
// ===== 分块上传（大资源）：init → append×N → complete =====
// 暂存位于 assets/uploads/（manifest 为 .json；chunk 无扩展名不进资源索引）。
const _maxChunkedAssetBytes = 256 * 1024 * 1024;
const _uploadChunkBytes = 8 * 1024 * 1024;
const _uploadStaleHours = 24;

Future<Map<String, dynamic>?> _uploadManifest(PluginData data, String uploadId) async {
  final raw = await data.read('assets', 'uploads/$uploadId.json');
  if (raw == null) return null;
  if (raw is! Map<String, dynamic> || raw['schemaVersion'] != 1 ||
      raw['uploadId'] != uploadId || raw['totalChunks'] is! int ||
      raw['receivedChunks'] is! List || raw['createdAt'] is! String) {
    throw const StorageException(StorageErrorKind.invalidData, '分块上传记录损坏');
  }
  return raw;
}

Future<void> _abandonUpload(PluginData data, Map<String, dynamic> manifest) async {
  await data.delete('assets', 'uploads/${manifest['uploadId']}.json');
  for (var i = 0; i < (manifest['totalChunks'] as int); i++) {
    await data.delete('assets', 'uploads/${manifest['uploadId']}.$i');
  }
}



PluginHandlers createAssetHandlers(PluginData data) => {
  'list': (_, params) async {
    final prefix = params['mediaTypePrefix'];
    if (prefix != null && (prefix is! String || !{'image/', 'video/', 'audio/', 'application/'}.contains(prefix))) {
      return const PluginResult.failure('资源类型筛选无效', 'INVALID_PARAMS');
    }
    final limit = params['limit'] as int? ?? 50;
    if (limit > 100) return const PluginResult.failure('资源列表每页上限 100', 'INVALID_PARAMS');
    final offset = params['offset'] as int? ?? 0;
    final items = (await _assetIndex(data)).values
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .where((entry) => prefix == null || (entry['mediaType'] as String).startsWith(prefix as String)).toList();
    items.sort((a, b) {
      final byTime = DateTime.parse(b['createdAt'] as String).compareTo(DateTime.parse(a['createdAt'] as String));
      return byTime != 0 ? byTime : (b['id'] as String).compareTo(a['id'] as String);
    });
    return PluginResult.success({'data': items.skip(offset).take(limit).toList(),
      'total': items.length, 'offset': offset, 'count': limit,
      'hasMore': offset + limit < items.length});
  },
  'readLegacySticker': (_, params) async {
    final path = params['sourcePath'];
    if (path is! String || !path.startsWith('stickers/') ||
        !RegExp(r'\.(png|gif|jpe?g|webp|svg|apng|bmp)$', caseSensitive: false).hasMatch(path)) {
      return const PluginResult.failure('仅支持读取旧贴图目录中的图片', 'INVALID_PARAMS');
    }
    if (data is! LegacyAssetData) {
      return const PluginResult.failure('后端不支持旧资源读取', 'UNSUPPORTED');
    }
    final bytes = await (data as LegacyAssetData).readLegacyAsset(path, maxAssetBytes);
    return bytes == null ? const PluginResult.failure('旧贴图不存在', 'NOT_FOUND')
      : PluginResult.success({'content': base64Encode(bytes), 'fileName': path.split('/').last});
  },
  'upload': (_, params) async {
    if (params.keys.any((key) => !{'content', 'fileName', 'mediaType'}.contains(key))) {
      return const PluginResult.failure('资源上传包含未知字段', 'INVALID_PARAMS');
    }
    final name = params['fileName'];
    final mediaType = params['mediaType'];
    final content = params['content'];
    if (name is! String || name.trim().isEmpty || name.length > 255 ||
        name.contains('/') || name.contains('\\') || RegExp(r'[\x00-\x1f]').hasMatch(name) ||
        mediaType is! String || !RegExp(r'^[\w.+-]+/[\w.+-]+$').hasMatch(mediaType) ||
        content is! String || content.length > maxAssetEncodedLength) {
      return const PluginResult.failure('无效资源参数，单个资源上限 16 MiB', 'INVALID_PARAMS');
    }
    final bytes = base64Decode(content);
    if (bytes.length > maxAssetBytes) {
      return const PluginResult.failure('单个资源上限 16 MiB', 'INVALID_PARAMS');
    }
    final index = await _assetIndex(data);
    final record = await _persistAsset(data, index, bytes, name, mediaType);
    return PluginResult.success(assetMetadata(record));
  },
  // 批量迁移分区外旧媒体文件（各域历史本地图片/贴图二进制）为正式资源。
  // 迁移记录保证幂等：同一路径重复迁移返回既有资源；成功后删除旧文件。
  'migrateLegacyAssets': (_, params) async {
    final items = params['items'];
    if (items is! List || items.isEmpty) {
      return const PluginResult.failure('items required', 'INVALID_PARAMS');
    }
    if (items.length > 50) {
      return const PluginResult.failure('单次迁移上限 50 项', 'INVALID_PARAMS');
    }
    if (data is! LegacyAssetData) {
      return const PluginResult.failure('后端不支持旧资源读取', 'UNSUPPORTED');
    }
    final backend = data as LegacyAssetData;
    final index = await _assetIndex(data);
    final migration = await _migrationMap(data);
    final migrated = <Map<String, dynamic>>[];
    final failed = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map || item['sourcePath'] is! String) {
        failed.add({'item': item, 'error': '缺少 sourcePath'});
        continue;
      }
      final sourcePath = (item['sourcePath'] as String).replaceAll('\\', '/');
      if (!isMigratableLegacyPath(sourcePath)) {
        failed.add({'sourcePath': sourcePath, 'error': '路径不在可迁移范围（须为已迁移业务域或贴图目录下的媒体文件）'});
        continue;
      }
      final existing = migration[sourcePath];
      if (existing is String) {
        // 幂等：已迁移路径直接复用既有资源，不重复上传
        final record = await readAsset(data, existing);
        if (record != null) {
          migrated.add({'sourcePath': sourcePath, 'id': existing, 'reference': 'asset://$existing'});
          continue;
        }
      }
      try {
        final bytes = await backend.readLegacyAsset(sourcePath, maxAssetBytes);
        if (bytes == null) {
          failed.add({'sourcePath': sourcePath, 'error': '旧文件不存在'});
          continue;
        }
        final fileName = item['fileName'] as String? ?? sourcePath.split('/').last;
        final mediaType = item['mediaType'] as String? ?? _mediaTypeFor(fileName);
        final record = await _persistAsset(data, index, bytes, fileName, mediaType);
        migration[sourcePath] = record['id'];
        await data.write('assets', 'legacy_migration.json', migration);
        await backend.removeLegacyAsset(sourcePath);
        migrated.add({'sourcePath': sourcePath, 'id': record['id'], 'reference': 'asset://${record['id']}'});
      } on StorageException catch (error) {
        failed.add({'sourcePath': sourcePath, 'error': error.message});
      } catch (error) {
        failed.add({'sourcePath': sourcePath, 'error': '$error'});
      }
    }
    return PluginResult.success({'migrated': migrated, 'failed': failed});
  },
  'initUpload': (_, params) async {
    if (params.keys.any((key) => !{'fileName', 'mediaType', 'size', 'sha256'}.contains(key))) {
      return const PluginResult.failure('分块上传包含未知字段', 'INVALID_PARAMS');
    }
    final name = params['fileName'];
    final mediaType = params['mediaType'];
    final size = params['size'];
    if (name is! String || name.trim().isEmpty || name.length > 255 ||
        name.contains('/') || name.contains('\\') ||
        mediaType is! String || !RegExp(r'^[\w.+-]+/[\w.+-]+$').hasMatch(mediaType) ||
        size is! int || size <= 0 || size > _maxChunkedAssetBytes) {
      return const PluginResult.failure('无效分块上传参数，单资源上限 256 MiB', 'INVALID_PARAMS');
    }
    final sha256hash = params['sha256'];
    if (sha256hash != null && (sha256hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256hash))) {
      return const PluginResult.failure('sha256 须为 64 位十六进制', 'INVALID_PARAMS');
    }
    // GC：清理超龄未完成的暂存
    final staleBefore = DateTime.now().toUtc().subtract(const Duration(hours: _uploadStaleHours));
    for (final file in await data.listFiles('assets', 'uploads/*.json')) {
      final manifest = await _uploadManifest(data, file.substring('uploads/'.length, file.length - '.json'.length));
      if (manifest != null &&
          DateTime.tryParse(manifest['createdAt'] as String)?.isBefore(staleBefore) == true) {
        await _abandonUpload(data, manifest);
      }
    }
    final uploadId = const Uuid().v4();
    final totalChunks = (size + _uploadChunkBytes - 1) ~/ _uploadChunkBytes;
    final manifest = <String, dynamic>{
      'schemaVersion': 1, 'uploadId': uploadId,
      'fileName': name, 'mediaType': mediaType, 'size': size,
      if (sha256hash != null) 'sha256': sha256hash,
      'totalChunks': totalChunks, 'receivedChunks': <int>[],
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    await data.write('assets', 'uploads/$uploadId.json', manifest);
    return PluginResult.success({'uploadId': uploadId, 'chunkBytes': _uploadChunkBytes, 'totalChunks': totalChunks});
  },
  'appendChunk': (_, params) async {
    final uploadId = checkedAssetId(params['uploadId']);
    final index = params['index'];
    final content = params['content'];
    if (index is! int || content is! String) {
      return const PluginResult.failure('index/content required', 'INVALID_PARAMS');
    }
    final manifest = await _uploadManifest(data, uploadId);
    if (manifest == null) return const PluginResult.failure('分块上传不存在或已完成', 'NOT_FOUND');
    if (index < 0 || index >= (manifest['totalChunks'] as int)) {
      return const PluginResult.failure('分块序号越界', 'INVALID_PARAMS');
    }
    final bytes = base64Decode(content);
    if (bytes.isEmpty || bytes.length > _uploadChunkBytes) {
      return const PluginResult.failure('分块须为 1-8 MiB 字节', 'INVALID_PARAMS');
    }
    await data.write('assets', 'uploads/$uploadId.$index', content);
    final received = (manifest['receivedChunks'] as List).toSet()..add(index);
    manifest['receivedChunks'] = received.toList()..sort();
    await data.write('assets', 'uploads/$uploadId.json', manifest);
    return PluginResult.success({'uploadId': uploadId, 'receivedChunks': received.length, 'totalChunks': manifest['totalChunks']});
  },
  'completeUpload': (_, params) async {
    final uploadId = checkedAssetId(params['uploadId']);
    final manifest = await _uploadManifest(data, uploadId);
    if (manifest == null) return const PluginResult.failure('分块上传不存在或已完成', 'NOT_FOUND');
    final total = manifest['totalChunks'] as int;
    if ((manifest['receivedChunks'] as List).length != total) {
      return const PluginResult.failure('分块未全部接收', 'INVALID_PARAMS');
    }
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < total; i++) {
      final chunk = await data.read('assets', 'uploads/$uploadId.$i');
      if (chunk is! String) {
        return const PluginResult.failure('分块内容缺失', 'INVALID_PARAMS');
      }
      builder.add(base64Decode(chunk));
    }
    final bytes = builder.takeBytes();
    if (bytes.length != manifest['size'] as int) {
      return const PluginResult.failure('分块合并大小与声明不符', 'INVALID_PARAMS');
    }
    final digest = sha256.convert(bytes).toString();
    if (manifest['sha256'] is String && digest != manifest['sha256']) {
      return const PluginResult.failure('sha256 校验失败', 'INVALID_PARAMS');
    }
    final index = await _assetIndex(data);
    final record = await _persistAsset(
      data, index, bytes, manifest['fileName'] as String, manifest['mediaType'] as String);
    await _abandonUpload(data, manifest);
    return PluginResult.success(assetMetadata(record)..addAll({'sha256': digest}));
  },

  // 回收引用计数为 0 的资源（默认仅 dryRun 列出候选；minAgeHours 保护
  // 刚上传尚未建立引用的资源）。
  'sweep': (_, params) async {
    final dryRun = params['dryRun'] != false;
    final minAgeHours = params['minAgeHours'] as int? ?? 24;
    if (minAgeHours < 0) {
      return const PluginResult.failure('minAgeHours 不能为负', 'INVALID_PARAMS');
    }
    final index = await _assetIndex(data);
    final cutoff = DateTime.now().toUtc().subtract(Duration(hours: minAgeHours));
    final affected = <String>[];
    // 候选先收集，删除与索引移除放在迭代外（避免遍历 index.values 时并发修改）
    final orphans = <String>[];
    for (final entry in index.values) {
      final id = (entry as Map)['id'] as String;
      if (DateTime.parse(entry['createdAt'] as String).isAfter(cutoff)) continue;
      if ((await readAssetReferences(data, id)).isNotEmpty) continue;
      if (dryRun) {
        affected.add(id);
        continue;
      }
      orphans.add(id);
    }
    for (final id in orphans) {
      await data.delete('assets', '$id.json');
      await data.delete('asset_references', '$id.json');
      index.remove(id);
      affected.add(id);
    }
    if (!dryRun && affected.isNotEmpty) {
      await data.write('assets', 'index.json', {'schemaVersion': 1, 'assets': index});
    }
    return PluginResult.success({'dryRun': dryRun, 'count': affected.length, 'ids': affected});
  },
  'read': (_, params) async {
    final record = await readAsset(data, checkedAssetId(params['id']));
    return record == null ? const PluginResult.failure('资源不存在', 'NOT_FOUND')
        : PluginResult.success({...assetMetadata(record), 'content': record['content']});
  },
  'getMetadata': (_, params) async {
    final record = await readAsset(data, checkedAssetId(params['id']));
    return record == null ? const PluginResult.failure('资源不存在', 'NOT_FOUND')
        : PluginResult.success(assetMetadata(record));
  },
  'remove': (_, params) async {
    final id = checkedAssetId(params['id']);
    final record = await readAsset(data, id);
    if (record == null) return const PluginResult.failure('资源不存在', 'NOT_FOUND');
    if ((await readAssetReferences(data, id)).isNotEmpty) {
      return const PluginResult.failure('资源仍被业务数据引用，请先移除引用', 'CONFLICT');
    }
    final removed = await data.delete('assets', '$id.json');
    await data.delete('asset_references', '$id.json');
    final index = await _assetIndex(data)..remove(id);
    await data.write('assets', 'index.json', {'schemaVersion': 1, 'assets': index});
    return removed ? PluginResult.success({'id': id, 'removed': true})
        : const PluginResult.failure('资源不存在', 'NOT_FOUND');
  },
};
