import 'dart:typed_data';

import 'package:aboutme_data_sdk/aboutme_data_sdk.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_compress_plus/image_compress_plus.dart'
    show ImageCompressPlus, CompressFormat;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'aboutme_data_service.dart';

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
  static Future<List<StorageFileInfo>> listMedia(String mediaTypePrefix) async {
    final result = <StorageFileInfo>[];
    for (var offset = 0; offset < 300; offset += 100) {
      final page = await _assets.list(
        mediaTypePrefix: mediaTypePrefix,
        offset: offset,
        limit: 100,
      );
      result.addAll(
        page.data.map(
          (asset) => StorageFileInfo(
            path: asset.reference,
            size: asset.size,
            updatedAt: DateTime.parse(asset.createdAt),
          ),
        ),
      );
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
      try {
        final candidate = await ImageCompressPlus.compressWithList(
          bytes,
          minWidth: 320,
          minHeight: 320,
          format: CompressFormat.jpeg,
          quality: quality,
        );
        if (candidate.length >= 3 &&
            candidate[0] == 0xff &&
            candidate[1] == 0xd8) {
          thumb = candidate;
        }
      } catch (error) {
        debugPrint('[Media] 缩略图编码不可用: $error');
      }
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

  static bool _isWebp(Uint8List bytes) =>
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
}
