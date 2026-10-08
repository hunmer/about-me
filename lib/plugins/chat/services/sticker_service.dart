import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/storage/storage_manager.dart';
import 'package:aboutme/plugins/chat/models/sticker_collection.dart';

/// 贴图合集管理服务
///
/// - 注册表：`stickers/collections.json`（StorageManager JSON 文件）
/// - 贴图文件：`stickers/{collectionId}/xxx.png`（相对 app_data）
/// - 同时作为脚本桥接后端（Aboutme.plugins.chat.importStickerCollection）
class StickerService {
  StickerService._();

  static final StickerService instance = StickerService._();

  static const String _registryPath = 'stickers/collections.json';

  StorageManager? get _storage => PluginManager.instance.storageManager;

  /// 列出全部合集（按更新时间倒序）
  Future<List<StickerCollection>> listCollections() async {
    final storage = _storage;
    if (storage == null) return [];
    try {
      final raw = await storage.readString(_registryPath);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final collections = list
          .map(
            (e) => StickerCollection.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      collections.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return collections;
    } catch (e) {
      debugPrint('[StickerService] 读取贴图注册表失败: $e');
      return [];
    }
  }

  /// 创建合集（可同时导入源文件）
  ///
  /// [sourcePaths] 支持两类路径：
  /// - 存储相对路径（如脚本下载产物 `stickers/downloads/x.png`）→ 移动（复制后删除源）
  /// - 本地绝对路径（如图库选择的照片）→ 复制
  Future<StickerCollection> createCollection(
    String name, {
    List<String> sourcePaths = const [],
  }) async {
    final storage = _requireStorage();
    final id = const Uuid().v4();
    final collection = StickerCollection(id: id, name: name.trim());

    await storage.createDirectory('stickers/$id');
    final stored = <String>[];
    for (final src in sourcePaths) {
      final storedPath = await _copyIn(storage, id, src);
      if (storedPath != null) stored.add(storedPath);
    }
    collection.stickerPaths = stored;
    if (stored.isNotEmpty) collection.coverPath = stored.first;

    final collections = await listCollections();
    collections.insert(0, collection);
    await _saveRegistry(collections);
    return collection;
  }

  /// 重命名合集
  Future<StickerCollection?> renameCollection(
    String id,
    String newName,
  ) async {
    return _updateCollection(id, (c) {
      c.name = newName.trim();
    });
  }

  /// 向合集添加贴图（sourcePaths 语义同 createCollection）
  Future<StickerCollection?> addStickers(
    String id,
    List<String> sourcePaths,
  ) async {
    return _updateCollection(id, (c) async {
      final storage = _requireStorage();
      for (final src in sourcePaths) {
        final storedPath = await _copyIn(storage, id, src);
        if (storedPath != null && !c.stickerPaths.contains(storedPath)) {
          c.stickerPaths.add(storedPath);
        }
      }
      c.coverPath ??= c.stickerPaths.isNotEmpty ? c.stickerPaths.first : null;
    });
  }

  /// 从合集移除单张贴图（同时删除存储中的文件）
  Future<StickerCollection?> removeSticker(String id, String stickerPath) async {
    return _updateCollection(id, (c) async {
      c.stickerPaths.remove(stickerPath);
      if (c.coverPath == stickerPath) {
        c.coverPath = c.stickerPaths.isNotEmpty ? c.stickerPaths.first : null;
      }
      try {
        await _requireStorage().deleteFile(stickerPath);
      } catch (e) {
        debugPrint('[StickerService] 删除贴图文件失败: $stickerPath - $e');
      }
    });
  }

  /// 删除合集（注册表 + 全部贴图文件）
  Future<bool> deleteCollection(String id) async {
    final storage = _storage;
    if (storage == null) return false;
    final collections = await listCollections();
    final target = collections.where((c) => c.id == id).firstOrNull;
    if (target == null) return false;

    collections.removeWhere((c) => c.id == id);
    await _saveRegistry(collections);

    for (final stickerPath in target.stickerPaths) {
      try {
        await storage.deleteFile(stickerPath);
      } catch (e) {
        debugPrint('[StickerService] 删除贴图文件失败: $stickerPath - $e');
      }
    }
    return true;
  }

  /// 读取贴图字节（供聊天发送附件使用）
  Future<Uint8List?> readStickerBytes(String stickerPath) async {
    try {
      return await _storage?.readBytes(stickerPath);
    } catch (e) {
      debugPrint('[StickerService] 读取贴图失败: $stickerPath - $e');
      return null;
    }
  }

  // ==================== 内部实现 ====================

  /// APNG → 动画 GIF（在 isolate 中执行，供 compute 调用）
  ///
  /// Flutter 原生只播放 GIF 动画（APNG 仅显示首帧），
  /// LINE 动态贴图源为 APNG，导入时统一转为 GIF 以支持播放。
  /// 返回 null 表示不是动画或转换失败（调用方按原格式保存）。
  static Uint8List? apngToGif(Uint8List bytes) {
    try {
      final decoded = img.decodePng(bytes);
      if (decoded == null || decoded.numFrames < 2) return null;

      // 控制体积：宽度上限 320（LINE @2x 源较大）
      var target = decoded;
      if (decoded.width > 320) {
        target = img.copyResize(decoded, width: 320);
      }
      // octree 量化远快于默认 neural，质量对贴图足够
      final encoder = img.GifEncoder(
        quantizerType: img.QuantizerType.octree,
        numColors: 256,
      );
      return encoder.encode(target);
    } catch (e) {
      debugPrint('[StickerService] APNG 转 GIF 失败: $e');
      return null;
    }
  }

  StorageManager _requireStorage() {
    final storage = _storage;
    if (storage == null) {
      throw StateError('StorageManager 未初始化');
    }
    return storage;
  }

  /// 将源文件拷入合集目录，返回存储相对路径；失败返回 null
  Future<String?> _copyIn(
    StorageManager storage,
    String collectionId,
    String sourcePath,
  ) async {
    try {
      Uint8List? bytes;
      var fileName = '';
      var deleteSource = false;

      if (path.isAbsolute(sourcePath)) {
        // 本地绝对路径（图库/文件选择器产物）→ 读取后复制
        final file = File(sourcePath);
        if (!await file.exists()) return null;
        bytes = await file.readAsBytes();
        fileName = path.basename(sourcePath);
      } else {
        // 存储相对路径（脚本下载产物）→ 读取后移动
        final normalized = sourcePath.replaceAll('\\', '/').replaceFirst(
          './',
          '',
        );
        bytes = await storage.readBytes(normalized);
        if (bytes == null) return null;
        fileName = path.basename(normalized);
        deleteSource = true;
      }

      // PNG 尝试 APNG→GIF（LINE 动态贴图等），成功则以 GIF 存储（表情面板可播放动画）
      if (path.extension(fileName).toLowerCase() == '.png') {
        try {
          final gif = await compute(apngToGif, bytes!);
          if (gif != null) {
            bytes = gif;
            fileName = '${path.basenameWithoutExtension(fileName)}.gif';
          }
        } catch (e) {
          debugPrint('[StickerService] APNG 转换中断，按原格式保存: $e');
        }
      }

      // 防止同名覆盖：加短随机后缀
      final ext = path.extension(fileName).isEmpty
          ? '.png'
          : path.extension(fileName);
      final base = path.basenameWithoutExtension(fileName);
      final dst = 'stickers/$collectionId/${base}_${const Uuid().v4().substring(0, 8)}$ext';
      await storage.writeBytes(dst, bytes!);
      if (deleteSource) {
        try {
          await storage.deleteFile(
            sourcePath.replaceAll('\\', '/').replaceFirst('./', ''),
          );
        } catch (_) {}
      }
      return dst;
    } catch (e) {
      debugPrint('[StickerService] 导入贴图失败: $sourcePath - $e');
      return null;
    }
  }

  Future<StickerCollection?> _updateCollection(
    String id,
    FutureOr<void> Function(StickerCollection) mutate,
  ) async {
    final collections = await listCollections();
    final index = collections.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    final collection = collections[index];
    await mutate(collection);
    collection.updatedAt = DateTime.now();
    collections[index] = collection;
    await _saveRegistry(collections);
    return collection;
  }

  Future<void> _saveRegistry(List<StickerCollection> collections) async {
    final storage = _requireStorage();
    final json = jsonEncode(collections.map((c) => c.toJson()).toList());
    await storage.writeString(_registryPath, json);
  }
}
