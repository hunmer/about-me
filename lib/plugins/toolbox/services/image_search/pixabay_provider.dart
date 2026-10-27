import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// Pixabay 官方 API（支持翻页；方向 horizontal/vertical，排序 popular/latest）
class PixabayProvider extends ImageSearchProvider {
  const PixabayProvider();

  @override
  String? validate(ImageSearchContext ctx) =>
      ctx.cfg('pixabayKey').isEmpty ? '未配置 pixabay 的 Key' : null;

  @override
  Future<ToolboxToolResult> search(
    ImageSearchContext ctx,
    ImageSearchQuery q,
  ) async {
    final perPage = (q.perPage ?? ctx.configNum('perPage', 10)).clamp(3, 200);
    const oriMap = {
      'horizontal': 'horizontal',
      'vertical': 'vertical',
      'landscape': 'horizontal',
      'portrait': 'vertical',
    };
    final ori = oriMap[q.orientation] ?? '';
    final order = q.sort == 'latest' ? 'latest' : 'popular';
    var url =
        'https://pixabay.com/api/?key=${Uri.encodeComponent(ctx.cfg('pixabayKey'))}'
        '&q=${Uri.encodeComponent(q.query)}'
        '&per_page=$perPage&page=${q.page}'
        '&image_type=${Uri.encodeComponent(q.imageType)}&order=$order';
    if (ori.isNotEmpty) url += '&orientation=$ori';

    final r = await ctx.getText(url);
    final status = r['statusCode'] as int;
    final body = r['body'];
    // Pixabay 错误是纯文本 [ERROR 400] "..."（JSON 解析失败保持字符串）
    if (status >= 400 || body is String) {
      final detail = ctx.errorDetail(body);
      final hint =
          RegExp('blocked|invalid', caseSensitive: false).hasMatch(detail)
          ? '（API Key 无效或被封禁）'
          : '';
      return ToolboxToolResult.fail('HTTP $status: $detail $hint');
    }
    final map = body as Map;
    final hits = (map['hits'] is List) ? map['hits'] as List : [];
    final totalHits = (map['totalHits'] ?? 0) as int;
    final images = <SearchedImage>[];
    for (final h in hits) {
      if (h is! Map || h['webformatURL'] == null) continue;
      images.add(
        SearchedImage(
          url: h['webformatURL'].toString(),
          thumb: (h['previewURL'] ?? '').toString(),
          user: (h['user'] ?? '未知').toString(),
          pageUrl: (h['pageURL'] ?? '').toString(),
          description: (h['tags'] ?? '').toString(),
          width: h['imageWidth'] is int ? h['imageWidth'] as int : null,
          height: h['imageHeight'] is int ? h['imageHeight'] as int : null,
          large: (h['largeImageURL'] ?? '').toString(),
          source: 'pixabay',
        ),
      );
    }
    if (images.isEmpty) {
      final overLimit = (q.page - 1) * perPage >= 500;
      return ToolboxToolResult.fail(
        overLimit ? '翻页超过 totalHits 上限 500' : '无搜索结果',
      );
    }
    return ToolboxToolResult(
      success: true,
      message: '搜索 "${q.query}" 命中 ${images.length}/$totalHits 张（pixabay）',
      data: {
        'mode': 'keyword',
        'provider': 'pixabay',
        'query': q.query,
        'total': totalHits,
        'page': q.page,
        'images': images,
      },
    );
  }
}
