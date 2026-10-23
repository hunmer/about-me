import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../storage_errors.dart';
import '../plugin_data.dart';
import '../types.dart';
import 'assets.dart';
import '../asset_references.dart';

/// 合集沿用旧 JSON 布局，但客户端只提交具体操作，锁内读取最新注册表。
PluginHandlers createChatStickerHandlers(PluginData data) {
  const file = 'collections.json';
  Never corrupt() => throw const StorageException(
    StorageErrorKind.invalidData, '贴图注册表损坏');
  String name(dynamic value) {
    if (value is! String || value.trim().isEmpty || value.length > 255) {
      throw const FormatException('合集名称必须为 1–255 个字符');
    }
    return value.trim();
  }
  String id(dynamic value) {
    if (value is! String || value.isEmpty || value.length > 128 ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
      throw const FormatException('合集 ID 无效');
    }
    return value;
  }
  List<String> paths(dynamic value) {
    bool valid(dynamic entry) {
      if (entry is! String) return false;
      if (entry.startsWith('asset://')) {
        try { checkedAssetId(entry.substring(8)); return true; }
        on FormatException { return false; }
      }
      return entry.startsWith('stickers/') && !entry.contains('\\') && !entry.contains(':') &&
        !entry.split('/').any((part) => part.isEmpty || part == '.' || part == '..');
    }
    if (value is! List || value.any((e) => !valid(e))) {
      throw const FormatException('贴图引用无效');
    }
    return value.cast<String>().toSet().toList();
  }
  Future<List<Map<String, dynamic>>> read() async {
    final raw = await data.read('stickers', file);
    if (raw == null) return [];
    if (raw is! List) corrupt();
    final result = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) corrupt();
      try {
        id(entry['id']); name(entry['name']); paths(entry['stickerPaths']);
        if (!ids.add(entry['id'] as String) ||
            DateTime.tryParse(entry['createdAt']?.toString() ?? '') == null ||
            DateTime.tryParse(entry['updatedAt']?.toString() ?? '') == null ||
            (entry['coverPath'] != null && !(entry['stickerPaths'] as List).contains(entry['coverPath']))) corrupt();
      } on FormatException { corrupt(); }
      result.add(Map<String, dynamic>.from(entry));
    }
    return result;
  }
  Future<void> save(List<Map<String, dynamic>> entries) async {
    final original = await read();
    final report = await data.read('sdk_migrations', 'chat_stickers/v1.json');
    if (report == null) {
      final checksum = sha256.convert(utf8.encode(jsonEncode(original))).toString();
      await data.write('sdk_migrations', 'chat_stickers/v1_backup.json', {
        'schemaVersion': 1, 'collections': original, 'checksum': checksum,
      });
      await data.write('sdk_migrations', 'chat_stickers/v1.json', {
        'schemaVersion': 1, 'entityCount': original.length,
        'ids': original.map((entry) => entry['id']).toList(),
        'checksum': checksum, 'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } else if (report is! Map || report['schemaVersion'] != 1) {
      throw const StorageException(StorageErrorKind.invalidData, '贴图迁移记录损坏');
    }
    Map<String, Set<String>> references(List<Map<String, dynamic>> collections) {
      final result = <String, Set<String>>{};
      for (final collection in collections) {
        for (final reference in (collection['stickerPaths'] as List).cast<String>()) {
          if (reference.startsWith('asset://')) {
            result.putIfAbsent(reference.substring(8), () => {}).add('chat:sticker:${collection['id']}');
          }
        }
      }
      return result;
    }
    final previous = references(original);
    final next = references(entries);
    await updateAssetReferences(data, previous, next);
    await data.write('stickers', file, entries);
  }

  Future<PluginResult> mutate(Map<String, dynamic> params,
      void Function(Map<String, dynamic> collection) change) async {
    final key = id(params['id']);
    final entries = await read();
    final index = entries.indexWhere((entry) => entry['id'] == key);
    if (index < 0) return const PluginResult.failure('贴图合集不存在', 'NOT_FOUND');
    final entry = entries[index];
    change(entry);
    entry['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await save(entries);
    return PluginResult.success(entry);
  }
  return {
    'getStickerCollections': (_, params) async {
      final entries = await read();
      entries.sort((a, b) => DateTime.parse(b['updatedAt'] as String)
        .compareTo(DateTime.parse(a['updatedAt'] as String)));
      return PluginResult.success(entries);
    },
    'createStickerCollection': (_, params) async {
      final title = name(params['name']);
      final references = paths(params['stickerPaths'] ?? []);
      final entries = await read();
      final now = DateTime.now().toUtc().toIso8601String();
      final key = params.containsKey('id') ? id(params['id']) : const Uuid().v4();
      if (entries.any((entry) => entry['id'] == key)) {
        return const PluginResult.failure('合集 ID 已存在', 'CONFLICT');
      }
      final entry = <String, dynamic>{'id': key, 'name': title,
        'stickerPaths': references, 'coverPath': references.firstOrNull,
        'createdAt': now, 'updatedAt': now};
      entries.add(entry);
      await save(entries);
      return PluginResult.success(entry);
    },
    'renameStickerCollection': (_, params) => mutate(params, (entry) {
      entry['name'] = name(params['name']);
    }),
    'addStickers': (_, params) => mutate(params, (entry) {
      final references = paths(params['stickerPaths']);
      entry['stickerPaths'] = <String>{...(entry['stickerPaths'] as List).cast<String>(), ...references}.toList();
      entry['coverPath'] ??= (entry['stickerPaths'] as List).firstOrNull;
    }),
    'removeSticker': (_, params) => mutate(params, (entry) {
      final reference = params['stickerPath'];
      paths([reference]);
      entry['stickerPaths'] = (entry['stickerPaths'] as List).where((path) => path != reference).toList();
      if (entry['coverPath'] == reference) entry['coverPath'] = (entry['stickerPaths'] as List).firstOrNull;
    }),
    'deleteStickerCollection': (_, params) async {
      final key = id(params['id']);
      final entries = await read();
      final index = entries.indexWhere((entry) => entry['id'] == key);
      if (index < 0) return const PluginResult.failure('贴图合集不存在', 'NOT_FOUND');
      final removed = entries.removeAt(index);
      await save(entries);
      return PluginResult.success(removed);
    },
  };
}
