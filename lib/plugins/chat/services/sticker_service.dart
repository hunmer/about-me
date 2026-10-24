
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:aboutme_data_sdk/aboutme_data_sdk.dart' show QueryFailure, QueryStatus, assetMediaType;

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/chat/models/sticker_collection.dart';

/// 贴图合集管理服务
///
/// - 注册表由 SDK 业务命令管理，客户端不执行整表读改写。
/// - 新贴图保存 SDK 稳定资源 ID；旧目录图片仅通过 SDK 兼容读取。
/// - 同时作为脚本桥接后端（Aboutme.plugins.chat.importStickerCollection）
class StickerService {
  StickerService._();

  static final StickerService instance = StickerService._();

  /// 列出全部合集（按更新时间倒序）
  Future<List<StickerCollection>> listCollections() async {
    final list = await _call('getStickerCollections') as List;
    return list.map((entry) => StickerCollection.fromJson(
      Map<String, dynamic>.from(entry as Map))).toList();
  }

  Stream<List<StickerCollection>> watchCollections() =>
    AboutmeDataService.instance.data.watch('chat', 'getStickerCollections')
      .where((snapshot) => snapshot.status == QueryStatus.data || snapshot.status == QueryStatus.error)
      .map((snapshot) {
        if (snapshot.error != null) throw snapshot.error!;
        final list = snapshot.result!['data'] as List;
        return list.map((entry) => StickerCollection.fromJson(
          Map<String, dynamic>.from(entry as Map))).toList();
      });

  /// 创建合集（可同时导入源文件）
  ///
  /// [sourcePaths] 支持两类路径：
  /// - 存储相对路径（如脚本下载产物 `stickers/downloads/x.png`）→ 导入为 SDK 资源
  /// - 本地绝对路径（如图库选择的照片）→ 复制
  Future<StickerCollection> createCollection(
    String name, {
    List<String> sourcePaths = const [],
  }) async {
    final id = const Uuid().v4();
    final stored = <String>[];
    for (final src in sourcePaths) {
      final storedPath = await _copyIn(src);
      if (storedPath != null) stored.add(storedPath);
    }
    return _collection(await _call('createStickerCollection', {
      'id': id, 'name': name, 'stickerPaths': stored,
    }));
  }

  /// 重命名合集
  Future<StickerCollection?> renameCollection(
    String id,
    String newName,
  ) async {
    return _mutate('renameStickerCollection', {'id': id, 'name': newName});
  }

  /// 向合集添加贴图（sourcePaths 语义同 createCollection）
  Future<StickerCollection?> addStickers(
    String id,
    List<String> sourcePaths,
  ) async {
    final stored = <String>[];
    for (final src in sourcePaths) {
      final reference = await _copyIn(src);
      if (reference != null) stored.add(reference);
    }
    return _mutate('addStickers', {'id': id, 'stickerPaths': stored});
  }

  /// 从合集移除单张贴图引用。
  Future<StickerCollection?> removeSticker(String id, String stickerPath) async {
    // 只移除引用。旧资源可能被消息或其它合集共用，不能直接物理删除。
    return _mutate('removeSticker', {'id': id, 'stickerPath': stickerPath});
  }

  /// 删除合集并释放其资源引用。
  Future<bool> deleteCollection(String id) async {
    return await _mutate('deleteStickerCollection', {'id': id}) != null;
  }

  /// 读取贴图字节（供聊天发送附件使用）
  Future<Uint8List?> readStickerBytes(String stickerPath) async {
    try {
      if (stickerPath.startsWith('asset://')) {
        return await AboutmeDataService.instance.data.assets.read(stickerPath.substring(8));
      }
      return await AboutmeDataService.instance.data.assets.readLegacySticker(stickerPath);
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

  /// 读取宿主选中的输入或受控旧贴图，返回稳定资源引用。
  Future<String?> _copyIn(
    String sourcePath,
  ) async {
    try {
      Uint8List? bytes;
      var fileName = '';

      if (path.isAbsolute(sourcePath)) {
        // 本地绝对路径（图库/文件选择器产物）→ 读取后复制
        bytes = await AboutmeDataService.instance.data.assets.readSelectedFile(sourcePath);
        fileName = path.basename(sourcePath);
      } else {
        // 存储相对路径（脚本下载产物）→ 由 SDK 受控读取，保留原输入
        final normalized = sourcePath.replaceAll('\\', '/').replaceFirst(
          './',
          '',
        );
        if (normalized.startsWith('asset://')) return normalized;
        bytes = await AboutmeDataService.instance.data.assets.readLegacySticker(normalized);
        if (bytes == null) throw StateError('源贴图不存在: $sourcePath');
        fileName = path.basename(normalized);
      }

      // PNG 尝试 APNG→GIF（LINE 动态贴图等），成功则以 GIF 存储（表情面板可播放动画）
      if (path.extension(fileName).toLowerCase() == '.png') {
        try {
          final gif = await compute(apngToGif, bytes);
          if (gif != null) {
            bytes = gif;
            fileName = '${path.basenameWithoutExtension(fileName)}.gif';
          }
        } catch (e) {
          debugPrint('[StickerService] APNG 转换中断，按原格式保存: $e');
        }
      }

      final asset = await AboutmeDataService.instance.data.assets.upload(bytes!,
        fileName: fileName, mediaType: assetMediaType(fileName), clientMutationId: const Uuid().v4());
      return asset.reference;
    } catch (e) {
      debugPrint('[StickerService] 导入贴图失败: $sourcePath - $e');
      rethrow;
    }
  }

  StickerCollection _collection(dynamic value) => StickerCollection.fromJson(
    Map<String, dynamic>.from(value as Map));

  Future<dynamic> _call(String action, [Map<String, dynamic> params = const {}]) async {
    final result = await AboutmeDataService.instance.data.call('chat', action, params);
    if (result['success'] != true) throw QueryFailure(result);
    return result['data'];
  }

  Future<StickerCollection?> _mutate(String action, Map<String, dynamic> params) async {
    try {
      return _collection(await _call(action, params));
    } on QueryFailure catch (error) {
      if (error.result['code'] == 'NOT_FOUND') return null;
      rethrow;
    }
  }
}
