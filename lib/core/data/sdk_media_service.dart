import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_compress_plus/image_compress_plus.dart'
    show ImageCompressPlus, CompressFormat;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'package:aboutme/core/app_initializer.dart' show globalStorage;
import 'package:aboutme/utils/image_utils.dart';
import 'aboutme_data_service.dart';

import 'package:shared_models/shared_models.dart';
/// 宿主只处理所选媒体的字节，所有持久化由 SDK 资源服务执行。
/// 转换与裁剪均在上传前完成，不修改已物化的不可变资源。
class SdkMediaService {
  static AssetsFacade get _assets => AboutmeDataService.instance.data.assets;
  static const maxBytes = 16 * 1024 * 1024;

  static Future<Uint8List> readPicked(XFile file) async {
    if (!kIsWeb) return _assets.readSelectedFile(file.path);
    if (await file.length() > maxBytes) throw ArgumentError('单个资源上限 16 MiB');
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw ArgumentError('单个资源上限 16 MiB');
    return bytes;
  }

  /// 单次上传 ≤16 MiB，超出自动走分块（上限 256 MiB）
  static Future<AssetDto> uploadBytes(Uint8List bytes, String fileName) {
    final name = path.basename(fileName);
    final mediaType = assetMediaType(fileName);
    if (bytes.length > maxBytes) {
      return _assets.uploadChunked(bytes, fileName: name, mediaType: mediaType);
    }
    return _assets.upload(
      bytes,
      fileName: name,
      mediaType: mediaType,
      clientMutationId: const Uuid().v4(),
    );
  }

  static Future<AssetDto> importPicked(XFile file) async =>
      uploadBytes(await readPicked(file), file.name);

  /// 兼容现有网格展示模型；不把资源 ID 当成文件路径查询。
  /// 同一内容多次上传会产生多个资产，按 sha256 去重（列表按时间倒序，保留最新）。
  static Future<List<StorageFileInfo>> listMedia(String mediaTypePrefix) async {
    final result = <StorageFileInfo>[];
    final seenHashes = <String>{};
    for (var offset = 0; offset < 300; offset += 100) {
      final page = await _assets.list(
        mediaTypePrefix: mediaTypePrefix,
        offset: offset,
        limit: 100,
      );
      for (final asset in page.data) {
        if (!seenHashes.add(asset.sha256)) continue;
        result.add(
          StorageFileInfo(
            path: asset.reference,
            size: asset.size,
            updatedAt: parseIsoDateTime(asset.createdAt),
          ),
        );
      }
      if (!page.hasMore) break;
    }
    return result;
  }

  static Future<Map<String, dynamic>> saveImage(
    Uint8List original, {
    required String fileName,
    bool enableCompression = false,
    int quality = 85,
  }) async {
    if (original.length > maxBytes) throw ArgumentError('单个资源上限 16 MiB');
    var bytes = original;
    var name = path.basename(fileName);
    final ext = path.extension(name).toLowerCase();
    // 动画资源保留原字节；不支持编码的平台保留原格式和原扩展名。
    if (ext != '.gif' && ext != '.apng' && ext != '.webp' && ext != '.svg') {
      try {
        final converted = await ImageCompressPlus.compressWithList(
          original,
          format: CompressFormat.webp,
          quality: quality,
        );
        if (_isWebp(converted)) {
          bytes = converted;
          name = '${path.basenameWithoutExtension(name)}.webp';
        }
      } catch (error) {
        debugPrint('[Media] WebP 编码不可用，保留原图: $error');
      }
    }
    Uint8List? thumb;
    if (enableCompression && ext != '.svg') {
      thumb = await _compressThumb(bytes, quality);
    }
    final image = await uploadBytes(bytes, name);
    final thumbnail = thumb == null
        ? null
        : await uploadBytes(
            thumb,
            '${path.basenameWithoutExtension(name)}.thumb.jpg',
          );
    return {
      'url': image.reference,
      'thumbUrl': thumbnail?.reference,
      'bytes': bytes,
    };
  }

  /// 编辑后原地更新图片：SDK 资产内容替换，id/引用不变，
  /// 持有该引用的业务数据（消息/日历条目等）无需变更。
  /// 非 SDK 资产 url（本地路径）不在此处理，由调用方自行写文件。
  static Future<void> replaceAsset(String url, Uint8List bytes) async {
    final id = ImageUtils.sdkAssetId(url);
    if (id == null) return;
    await _assets.replace(id, bytes);
  }

  /// 用编辑后的原图字节刷新伴生缩略图（引用不变）：
  /// - SDK 缩略图资产（asset://）原地替换
  /// - 旧路径缩略图（命名约定 `<name>.thumb<ext>`）直接覆盖写入
  /// thumbUrl 为空或编码失败时跳过，不影响原图
  static Future<void> updateThumb(
    Uint8List originalBytes,
    String? thumbUrl, {
    int quality = 85,
  }) async {
    if (thumbUrl == null || thumbUrl.isEmpty) return;
    final thumb = await _compressThumb(originalBytes, quality);
    if (thumb == null) return;
    final thumbId = ImageUtils.sdkAssetId(thumbUrl);
    if (thumbId != null) {
      await _assets.replace(thumbId, thumb);
      return;
    }
    final rel = thumbUrl.startsWith('./') ? thumbUrl.substring(2) : thumbUrl;
    if (path.basename(rel).contains('.thumb')) {
      await globalStorage.writeBytes(rel.replaceAll(r'\', '/'), thumb);
    }
  }

  /// 压缩生成缩略图（320 短边 JPEG）；编码不可用或产物非法时返回 null
  static Future<Uint8List?> _compressThumb(Uint8List bytes, int quality) async {
    try {
      final candidate = await ImageCompressPlus.compressWithList(
        bytes,
        minWidth: 320,
        minHeight: 320,
        format: CompressFormat.jpeg,
        quality: quality,
      );
      if (candidate.length >= 3 && candidate[0] == 0xff && candidate[1] == 0xd8) {
        return candidate;
      }
    } catch (error) {
      debugPrint('[Media] 缩略图编码不可用: $error');
    }
    return null;
  }

  static bool _isWebp(Uint8List bytes) =>
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
}
