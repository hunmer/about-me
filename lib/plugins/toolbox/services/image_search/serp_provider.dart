import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// SerpAPI 搜索引擎图源（google/bing/yahoo/yandex，不支持翻页/方向/排序），
/// 另提供以图搜图（Google Lens）
class SerpProvider extends ImageSearchProvider {
  const SerpProvider();

  /// 引擎参数表（qParam 为各引擎的关键词参数名）
  static const Map<String, Map<String, String>> engines = {
    'google': {'engine': 'google_images', 'qParam': 'q'},
    'bing': {'engine': 'bing_images', 'qParam': 'q'},
    'yahoo': {'engine': 'yahoo_images', 'qParam': 'p'},
    'yandex': {'engine': 'yandex_images', 'qParam': 'text'},
  };

  @override
  String? validate(ImageSearchContext ctx) =>
      ctx.cfg('serpApiKey').isEmpty ? '未配置 SerpAPI Key' : null;

  @override
  Future<ToolboxToolResult> search(
    ImageSearchContext ctx,
    ImageSearchQuery q,
  ) async {
    final provider = engines.containsKey(q.provider) ? q.provider : 'google';
    final eng = engines[provider]!;
    final limit = (q.perPage ?? ctx.configNum('perPage', 10)).clamp(1, 100);
    final serpKey = ctx.cfg('serpApiKey');
    var url =
        'https://serpapi.com/search?engine=${eng['engine']}'
        '&${eng['qParam']}=${Uri.encodeComponent(q.query)}'
        '&api_key=${Uri.encodeComponent(serpKey)}';
    if (provider == 'google') {
      final hl = ctx.cfg('googleHl').isEmpty ? 'en' : ctx.cfg('googleHl');
      final gl = ctx.cfg('googleGl').isEmpty ? 'us' : ctx.cfg('googleGl');
      url +=
          '&google_domain=google.com&hl=${Uri.encodeComponent(hl)}'
          '&gl=${Uri.encodeComponent(gl)}';
    }

    final resp = await ctx.getText(url);
    final status = resp['statusCode'] as int;
    if (status >= 400) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${ctx.errorDetail(resp['body'])} ${_hint(status)}',
      );
    }
    final body = resp['body'];
    final hits = (body is Map && body['images_results'] is List)
        ? body['images_results'] as List
        : [];
    final images = <SearchedImage>[];
    for (final r in hits.take(limit)) {
      if (r is! Map || r['thumbnail'] == null) continue;
      images.add(
        SearchedImage(
          url: (r['original'] ?? r['thumbnail']).toString(),
          thumb: r['thumbnail'].toString(),
          user: (provider == 'bing' && r['domain'] != null)
              ? r['domain'].toString()
              : _hostnameOf(r['source']?.toString()) ?? '',
          pageUrl: (r['link'] ?? '').toString(),
          description: (r['title'] ?? '').toString(),
          width: r['original_width'] is int ? r['original_width'] as int : null,
          height: r['original_height'] is int
              ? r['original_height'] as int
              : null,
          source: provider,
        ),
      );
    }
    if (images.isEmpty) return const ToolboxToolResult.fail('无搜索结果');
    return ToolboxToolResult(
      success: true,
      message: '搜索 "${q.query}" 命中 ${images.length}/${hits.length} 张（$provider）',
      data: {
        'mode': 'keyword',
        'provider': provider,
        'query': q.query,
        'total': hits.length,
        'page': 1,
        'images': images,
      },
    );
  }

  /// 以图搜图：SerpAPI Google Lens（不支持翻页）
  static Future<ToolboxToolResult> searchLens(
    ImageSearchContext ctx,
    String imageUrl,
    int? perPage,
  ) async {
    final limit = ((perPage ?? ctx.configNum('perPage', 20))).clamp(1, 100);
    final url =
        'https://serpapi.com/search?engine=google_lens'
        '&url=${Uri.encodeComponent(imageUrl)}'
        '&api_key=${Uri.encodeComponent(ctx.cfg('serpApiKey'))}';

    final resp = await ctx.getText(url);
    final status = resp['statusCode'] as int;
    if (status >= 400) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${ctx.errorDetail(resp['body'])} ${_hint(status)}',
      );
    }
    final body = resp['body'];
    final hits = (body is Map && body['visual_matches'] is List)
        ? body['visual_matches'] as List
        : [];
    final images = <SearchedImage>[];
    for (final v in hits.take(limit)) {
      if (v is! Map || v['link'] == null) continue;
      images.add(
        SearchedImage(
          url: (v['thumbnail'] ?? v['link']).toString(),
          thumb: (v['thumbnail'] ?? '').toString(),
          user: (v['source'] ?? '').toString(),
          pageUrl: v['link'].toString(),
          description: (v['title'] ?? '').toString(),
          width: v['thumbnail_width'] is int
              ? v['thumbnail_width'] as int
              : null,
          height: v['thumbnail_height'] is int
              ? v['thumbnail_height'] as int
              : null,
          source: 'google_lens',
        ),
      );
    }
    if (images.isEmpty) {
      return const ToolboxToolResult.fail('无视觉匹配结果（图片不可访问或无相似图）');
    }
    return ToolboxToolResult(
      success: true,
      message: '以图搜图命中 ${images.length} 条视觉匹配',
      data: {
        'mode': 'lens',
        'provider': 'google_lens',
        'imageUrl': imageUrl,
        'total': hits.length,
        'page': 1,
        'images': images,
      },
    );
  }

  static String _hint(int status) {
    if (status == 401) return '（SerpAPI Key 无效）';
    if (status == 429) return '（免费额度 250 次/月已用尽）';
    return '';
  }

  /// 提取 URL 中的域名（yandex 是站点名，bing/yahoo 是 URL）
  static String? _hostnameOf(String? u) {
    if (u == null || !RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
      return u;
    }
    return RegExp(
      r'^https?://([^/]+)',
      caseSensitive: false,
    ).firstMatch(u)?.group(1);
  }
}
