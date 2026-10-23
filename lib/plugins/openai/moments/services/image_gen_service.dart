import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_compress_plus/image_compress_plus.dart';
import 'package:path/path.dart' as path;

import 'package:aboutme/core/data/sdk_media_service.dart';
import 'package:aboutme/core/services/image_compression_service.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 生图服务：封装工具箱插件的 AI 图片生成小工具
///
/// 文生图 / 图生图（参考图）；工具箱产物已上传为 SDK 资源，
/// 这里为朋友圈单独上传一份副本资源归档（避免工具箱删除生成
/// 历史时把仍在引用的资源一并移除），返回 'asset://...' 引用列表
class ImageGenService {
  ImageGenService._();

  static final ImageGenService instance = ImageGenService._();

  /// 生成图片，返回归档后的 SDK 资源引用列表（'asset://...'）
  ///
  /// [refImageAbsolutePaths] 参考图（图生图），本地绝对路径
  Future<List<String>> generate({
    required String prompt,
    List<String> refImageAbsolutePaths = const [],
    String? aspectRatio,
    int n = 1,
  }) async {
    final (refImages, tempRefFiles) = await _convertRefImagesToWebp(refImageAbsolutePaths);
    try {
      final result = await AiImageService.instance
          .generate(
            prompt: prompt,
            refImages: refImages,
            aspectRatio: aspectRatio,
            n: n,
            // 后台调用不回传字节（工具箱侧直传 SDK 资源），不弹界面
            returnBytes: false,
          )
          .catchError(
            (e) => throw Exception('生图失败: 工具箱服务未就绪或执行异常 ($e)'),
          );
      if (!result.success) {
        throw Exception('生图失败: ${result.error ?? '未知错误'}');
      }
      final refs = (result.data?['images'] as List?)
              ?.map(
                (e) => e is GeneratedImage ? e.relativePath : e.toString(),
              )
              .where((e) => e.isNotEmpty)
              .toList() ??
          <String>[];
      if (refs.isEmpty) {
        throw Exception('生图失败: 未返回图片，请检查工具箱 AI 图片生成配置');
      }
      // 副本归档为朋友圈独立资源（读取源字节后重新上传，
      // 与工具箱生成历史各自持有资源，互不影响删除）
      final archived = <String>[];
      for (var i = 0; i < refs.length; i++) {
        try {
          final bytes = await ImageUtils.readStorageBytes(refs[i]);
          if (bytes == null || bytes.isEmpty) continue;
          final asset = await SdkMediaService.uploadBytes(
            bytes,
            'moment_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.png',
          );
          archived.add(asset.reference);
        } catch (e) {
          debugPrint('[Moments] 生图归档失败 (${refs[i]}): $e');
        }
      }
      if (archived.isEmpty) throw Exception('生图失败: 图片归档失败');
      return archived;
    } finally {
      // 生图结束（无论成败）清理本次转换产生的临时 webp
      for (final tmp in tempRefFiles) {
        try {
          final file = File(tmp);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  /// 参考图统一转成 webp 后再送入生图接口
  ///
  /// 返回 (转换后的路径列表, 本次产生的临时文件列表)；
  /// 已是 webp 或文件不存在时原样透传；转换失败时回退原图，不阻断生图
  Future<(List<String>, List<String>)> _convertRefImagesToWebp(List<String> paths) async {
    if (paths.isEmpty) return (paths, const <String>[]);
    final converted = <String>[];
    final tempFiles = <String>[];
    for (final abs in paths) {
      if (path.extension(abs).toLowerCase() == '.webp' || !await File(abs).exists()) {
        converted.add(abs);
        continue;
      }
      try {
        // 参考图偏重保质量，质量取 90
        final target = path.join(
          Directory.systemTemp.path,
          '${path.basenameWithoutExtension(abs)}_${DateTime.now().millisecondsSinceEpoch}.webp',
        );
        final compressed = await ImageCompressionService().compressImage(
          sourcePath: abs,
          targetPath: target,
          quality: 90,
          format: CompressFormat.webp,
        );
        converted.add(compressed);
        tempFiles.add(compressed);
      } catch (e) {
        debugPrint('参考图转 webp 失败，回退原图: $abs ($e)');
        converted.add(abs);
      }
    }
    return (converted, tempFiles);
  }
}
