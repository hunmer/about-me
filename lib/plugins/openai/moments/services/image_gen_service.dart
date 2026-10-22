import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/toolbox/services/ai_image_service.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 生图服务：封装工具箱插件的 AI 图片生成小工具
///
/// 文生图 / 图生图（参考图），结果拷贝归档到 `openai/moments/images/`
class ImageGenService {
  ImageGenService._();

  static final ImageGenService instance = ImageGenService._();

  /// 生成图片，返回归档后的相对路径列表（'./openai/moments/images/xxx.png'）
  ///
  /// [refImageAbsolutePaths] 参考图（图生图），本地绝对路径
  Future<List<String>> generate({
    required String prompt,
    List<String> refImageAbsolutePaths = const [],
    String? aspectRatio,
    int n = 1,
    String? archiveDir,
  }) async {
    final archive = archiveDir ?? MomentsService.imagesDir;
    final result = await AiImageService.instance
        .generate(
          prompt: prompt,
          refImages: refImageAbsolutePaths,
          aspectRatio: aspectRatio,
          n: n,
          // 后台调用不回传字节（URL 直写磁盘），不弹界面
          returnBytes: false,
        )
        .catchError(
          (e) => throw Exception('生图失败: 工具箱服务未就绪或执行异常 ($e)'),
        );
    if (!result.success) {
      throw Exception('生图失败: ${result.error ?? '未知错误'}');
    }
    final localPaths = (result.data?['images'] as List?)
            ?.map((e) => e.absolutePath.isNotEmpty ? e.absolutePath : e.relativePath)
            .toList() ??
        <String>[];
    if (localPaths.isEmpty) {
      throw Exception('生图失败: 未返回本地图片，请检查工具箱 AI 图片生成配置');
    }
    // 拷贝归档，避免与工具产物目录互相干扰
    final archived = <String>[];
    for (final abs in localPaths) {
      final file = File(abs as String);
      if (!await file.exists()) continue;
      final rel = await ImageUtils.saveBytesToAppDirectory(
        await file.readAsBytes(),
        archive,
        extension: path.extension(file.path).isEmpty ? '.png' : path.extension(file.path),
      );
      archived.add(rel);
    }
    if (archived.isEmpty) throw Exception('生图失败: 图片归档失败');
    return archived;
  }
}
