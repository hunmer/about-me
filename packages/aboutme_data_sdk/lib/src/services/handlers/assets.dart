import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../storage_errors.dart';
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
    final id = const Uuid().v4();
    final index = await _assetIndex(data);
    final record = <String, dynamic>{'schemaVersion': 1, 'id': id,
      'fileName': name, 'mediaType': mediaType, 'size': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'content': base64Encode(bytes)};
    await data.write('assets', '$id.json', record);
    index[id] = assetMetadata(record);
    await data.write('assets', 'index.json', {'schemaVersion': 1, 'assets': index});
    return PluginResult.success(assetMetadata(record));
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
