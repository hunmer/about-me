import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// Magnific（原 Freepik）站点搜索 API，支持翻页（每页固定 50 条，
/// 仅 content_type=photo/vector 两种类型，不支持方向/排序）
///
/// 无需 API Key；站点有安全过滤（Akamai），直连可能被 403 拦截，
/// 可在配置里粘贴浏览器 Cookie 提高通过率。
class MagnificProvider extends ImageSearchProvider {
  const MagnificProvider();

  @override
  String? validate(ImageSearchContext ctx) => null;

  @override
  Future<ToolboxToolResult> search(
    ImageSearchContext ctx,
    ImageSearchQuery q,
  ) async {
    final limit = (q.perPage ?? ctx.configNum('perPage', 10)).clamp(1, 50);
    // API 仅支持 photo/vector，其余类型统一按 vector 检索
    final contentType = q.imageType == 'photo' ? 'photo' : 'vector';
    final slug = Uri.encodeComponent(q.query);
    final path = contentType == 'photo' ? 'photos' : 'vectors';
    final url =
        'https://www.magnific.com/api/regular/search'
        '?filters%5Bcontent_type%5D=$contentType&locale=en'
        '&page=${q.page}&slug=$slug';
    final headers = {
      'accept': '*/*',
      'accept-language': 'en-US,en;q=0.9',
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36',
      'referer': 'https://www.magnific.com/$path/$slug/${q.page}',
    };
    final cookie = ctx.cfg('magnificCookie');
    if (cookie.isNotEmpty) headers['cookie'] = cookie;

    final resp = await ctx.getText(url, headers: headers);
    final status = resp['statusCode'] as int;
    final body = resp['body'];
    if (status == 403) {
      return const ToolboxToolResult.fail(
        'HTTP 403: 被 Magnific 安全过滤拦截，可稍后重试，或在配置里粘贴浏览器 Cookie',
      );
    }
    if (status >= 400 || body is! Map) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${ctx.errorDetail(body)}',
      );
    }
    final items = (body['items'] is List) ? body['items'] as List : [];
    final pagination =
        body['pagination'] is Map ? body['pagination'] as Map : const {};
    final images = <SearchedImage>[];
    for (final it in items.take(limit)) {
      if (it is! Map) continue;
      final preview = it['preview'];
      if (preview is! Map || preview['url'] == null) continue;
      final author = it['author'] is Map ? it['author'] as Map : null;
      final premium = it['premium'] == true;
      images.add(
        SearchedImage(
          url: preview['url'].toString(),
          thumb: preview['url'].toString(),
          user: (author?['name'] ?? '').toString(),
          pageUrl: (it['url'] ?? '').toString(),
          description: (it['name'] ?? '').toString() + (premium ? ' [Premium]' : ''),
          width: preview['width'] is int ? preview['width'] as int : null,
          height: preview['height'] is int ? preview['height'] as int : null,
          source: 'magnific',
        ),
      );
    }
    if (images.isEmpty) return const ToolboxToolResult.fail('无搜索结果');
    final total =
        pagination['total'] is int ? pagination['total'] as int : images.length;
    final page =
        pagination['currentPage'] is int
            ? pagination['currentPage'] as int
            : q.page;
    final lastPage =
        pagination['lastPage'] is int ? pagination['lastPage'] as int : page;
    return ToolboxToolResult(
      success: true,
      message: '搜索 "${q.query}" 命中 ${images.length}/$total 张（magnific）',
      data: {
        'mode': 'keyword',
        'provider': 'magnific',
        'query': q.query,
        'total': total,
        'page': page,
        'lastPage': lastPage,
        'images': images,
      },
    );
  }
}
