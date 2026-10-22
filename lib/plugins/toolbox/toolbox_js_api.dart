part of 'toolbox_plugin.dart';

// ==================== JS API 实现 ====================
// 供 scripts_center 脚本与 agent 工具调用，返回结构对齐原内置脚本
// （image_search / ai_image 迁移前的 runScript 结果）。

/// 聚合图片搜索
/// 参数: query?, imageUrl?, provider?, perPage?, page?, imageType?, orientation?, sort?
Future<String> jsSearchImages(Map<String, dynamic> params) async {
  try {
    final result = await ImageSearchService.instance.search(
      query: params['query']?.toString(),
      imageUrl: params['imageUrl']?.toString(),
      provider: params['provider']?.toString() ?? 'unsplash',
      perPage: params['perPage'] is num
          ? (params['perPage'] as num).toInt()
          : null,
      page: params['page'] is num ? (params['page'] as num).toInt() : 1,
      imageType: params['imageType']?.toString() ?? 'photo',
      orientation: params['orientation']?.toString() ?? 'any',
      sort: params['sort']?.toString() ?? 'relevant',
    );
    return jsonEncode(_toolResultToJson(result));
  } catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// AI 图片生成（文生图 / 图生图）
/// 参数: prompt, image?(本地绝对路径或 URL 的数组/单值), model?, aspectRatio?, n?
Future<String> jsGenerateImages(Map<String, dynamic> params) async {
  try {
    final prompt = params['prompt']?.toString() ?? '';
    final rawImage = params['image'];
    final refImages = rawImage is List
        ? rawImage.map((e) => e.toString()).toList()
        : (rawImage == null ? <String>[] : [rawImage.toString()]);
    final result = await AiImageService.instance.generate(
      prompt: prompt,
      refImages: refImages,
      model: params['model']?.toString(),
      aspectRatio: params['aspectRatio']?.toString(),
      n: params['n'] is num ? (params['n'] as num).toInt() : null,
      // 后台调用不返回字节（base64 可达 MB 级，过桥会阻塞主线程）
      returnBytes: false,
    );
    return jsonEncode(_toolResultToJson(result));
  } catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// ToolboxToolResult → JSON map（images 内的模型对象序列化，
/// base64 字节剥离为占位）
Map<String, dynamic> _toolResultToJson(ToolboxToolResult result) {
  final data = result.data;
  if (data == null) return result.toMap();
  final converted = Map<String, dynamic>.from(data);
  final images = converted['images'];
  if (images is List) {
    converted['images'] = [
      for (final img in images)
        if (img is SearchedImage)
          img.toJson()
        else if (img is GeneratedImage)
          {
            'path': img.relativePath,
            if (img.absolutePath.isNotEmpty) 'absolutePath': img.absolutePath,
            // 后台模式剥离 base64（可达 MB 级，过桥回传会阻塞主线程）
            'image': img.bytes != null ? '[base64]' : '',
          },
    ];
  }
  return {...result.toMap(), 'data': converted};
}
