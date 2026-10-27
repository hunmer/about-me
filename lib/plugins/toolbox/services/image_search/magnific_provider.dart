import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// Magnific（原 Freepik）站点搜索 API，支持翻页（每页固定 50 条，
/// 仅 content_type=photo/vector 两种类型，不支持方向/排序）
///
/// 逆向结论（参考 E:/programming/nodejs/magnific/magnific_search.mjs）：
/// 无需登录/签名，过 WAF 的关键是带 user-agent 且带 referer/sec-fetch-* 头；
/// 403/429 多为 WAF 误判或限频，指数退避重试即可；
/// 跨请求复用服务端下发的风控 cookie（_fc/_fcid/ak_bmsc）可降低 403 概率。
class MagnificProvider extends ImageSearchProvider {
  const MagnificProvider();

  /// 服务端下发的风控 cookie，跨请求复用（静态：provider 实例为 const）
  static final Map<String, String> _cookieStore = {};

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
    final url =
        'https://www.magnific.com/api/regular/search'
        '?filters%5Bcontent_type%5D=$contentType&locale=en'
        '${q.page > 1 ? '&page=${q.page}' : ''}&slug=$slug';

    final resp = await _getWithRetry(ctx, url);
    final status = resp['statusCode'] as int;
    final body = resp['body'];
    if (status >= 400 || body is! Map) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${ctx.errorDetail(body)}'
        '${status == 403 ? '（WAF 拦截，稍后重试）' : ''}',
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

  /// 请求 + 指数退避重试（403/429/5xx 视为 WAF 误判/限频，最多 3 次）
  Future<Map<String, dynamic>> _getWithRetry(
    ImageSearchContext ctx,
    String url,
  ) async {
    final headers = {
      'accept': '*/*',
      'accept-language': 'en-US,en;q=0.9',
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36',
      'referer': 'https://www.magnific.com/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
    };
    final cookie = _cookieHeader();
    if (cookie.isNotEmpty) headers['cookie'] = cookie;

    Map<String, dynamic> resp = {};
    for (var attempt = 0; attempt <= 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: 1200 * (1 << (attempt - 1))),
        );
      }
      resp = await ctx.getText(url, headers: Map.of(headers));
      _absorbCookies(resp['headers']);
      final status = resp['statusCode'] as int;
      if (status != 403 && status != 429 && status < 500) break;
    }
    return resp;
  }

  static String _cookieHeader() =>
      _cookieStore.entries.map((e) => '${e.key}=${e.value}').join('; ');

  /// 从合并后的 set-cookie 头中提取已知风控 cookie
  /// （http 包会把多个 set-cookie 合并成一个字符串， expires 含逗号，仅按名提取）
  static void _absorbCookies(dynamic headers) {
    if (headers is! Map) return;
    final setCookie = headers['set-cookie'];
    if (setCookie is! String || setCookie.isEmpty) return;
    for (final name in const ['_fc', '_fcid', 'ak_bmsc']) {
      final m = RegExp('(?:^|[;,]\\s*)$name=([^;,]+)').firstMatch(setCookie);
      if (m != null) _cookieStore[name] = m.group(1)!.trim();
    }
  }
}
