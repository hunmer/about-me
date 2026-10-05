import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:aboutme/plugins/openai/moments/services/moments_service.dart';
import 'package:aboutme/plugins/scripts_center/scripts_center_plugin.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 生图服务：封装 scripts_center 的 ai_image 内置脚本
///
/// 文生图 / 图生图（参考图），结果拷贝归档到 `openai/moments/images/`
class ImageGenService {
  ImageGenService._();

  static final ImageGenService instance = ImageGenService._();

  static const _scriptId = 'ai_image';

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
    final dynamic plugin;
    try {
      plugin = ScriptsCenterPlugin.instance;
    } catch (e) {
      throw Exception('生图失败: 脚本中心插件未启用 ($e)');
    }
    final args = <String, dynamic>{
      'prompt': prompt,
      'showUi': false, // 后台调用不弹结果页（v1.3.3+ 支持）
      'n': n,
      if (refImageAbsolutePaths.isNotEmpty) 'image': refImageAbsolutePaths,
      if (aspectRatio != null && aspectRatio.isNotEmpty)
        'aspectRatio': aspectRatio,
    };
    final result = await plugin.scriptExecutor.execute(_scriptId, args: args)
        .catchError((e) => throw Exception('生图失败: 脚本中心未就绪或执行异常 ($e)'));
    if (!result.success) {
      throw Exception('生图失败: ${result.error ?? '未知错误'}');
    }
    final data = (result.result is Map) ? result.result['data'] : null;
    final localPaths =
        (data is Map ? data['localPaths'] : null) as List<dynamic>? ?? [];
    if (localPaths.isEmpty) {
      throw Exception('生图失败: 脚本未返回本地图片，请检查脚本中心 ai_image 配置');
    }
    // 拷贝归档，避免与脚本产物目录互相干扰
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
