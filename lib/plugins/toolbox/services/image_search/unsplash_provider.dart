import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// Unsplash 官方 API（支持翻页；方向 landscape/portrait/squarish，
/// 排序仅 relevant/latest）
class UnsplashProvider extends ImageSearchProvider {
  const UnsplashProvider();

  @override
  String? validate(ImageSearchContext ctx) =>
      ctx.cfg('unsplashAccessKey').isEmpty ? '未配置 unsplash 的 Key' : null;

  @override
  Future<ToolboxToolResult> search(
    ImageSearchContext ctx,
    ImageSearchQuery q,
  ) async {
    final limit = (q.perPage ?? ctx.configNum('perPage', 10)).clamp(1, 30);
    const oriMap = {
      'landscape': 'landscape',
      'portrait': 'portrait',
      'squarish': 'squarish',
      'horizontal': 'landscape',
      'vertical': 'portrait',
    };
    final ori = oriMap[q.orientation] ?? '';
    final orderBy = q.sort == 'latest' ? 'latest' : 'relevant';
    var url =
        'https://api.unsplash.com/search/photos'
        '?query=${Uri.encodeComponent(q.query)}'
        '&per_page=$limit&page=${q.page}&order_by=$orderBy';
    if (ori.isNotEmpty) url += '&orientation=$ori';
    final r = await ctx.getText(
      url,
      headers: {'Authorization': 'Client-ID ${ctx.cfg('unsplashAccessKey')}'},
    );
    final status = r['statusCode'] as int;
    if (status >= 400) {
      final hint = status == 401
          ? '（Access Key 无效）'
          : status == 403
          ? '（演示额度 50 次/小时已用尽）'
          : '';
      return ToolboxToolResult.fail(
        'HTTP $status: ${ctx.errorDetail(r['body'])} $hint',
      );
    }
    final body = r['body'] as Map;
    final results = (body['results'] is List) ? body['results'] as List : [];
    final images = <SearchedImage>[];
    for (final item in results) {
      if (item is! Map || item['urls'] is! Map) continue;
      final urls = item['urls'] as Map;
      final user = item['user'] is Map ? item['user'] as Map : null;
      images.add(
        SearchedImage(
          url: (urls['regular'] ?? urls['full'] ?? '').toString(),
          thumb: (urls['thumb'] ?? '').toString(),
          user: (user?['name'] ?? '未知').toString(),
          profileUrl: (((user?['links'] ?? {}) as Map)['html'] ?? '')
              .toString(),
          pageUrl: ((item['links'] ?? {}) as Map)['html']?.toString() ?? '',
          description: (item['description'] ?? item['alt_description'] ?? '')
              .toString(),
          width: item['width'] is int ? item['width'] as int : null,
          height: item['height'] is int ? item['height'] as int : null,
          source: 'unsplash',
        ),
      );
    }
    return ToolboxToolResult(
      success: true,
      message:
          '搜索 "${q.query}" 命中 ${images.length}/${body['total'] ?? 0} 张（unsplash）',
      data: {
        'mode': 'keyword',
        'provider': 'unsplash',
        'query': q.query,
        'total': body['total'] is int ? body['total'] as int : 0,
        'page': q.page,
        'images': images,
      },
    );
  }
}
