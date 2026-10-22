import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';

/// 图片搜索小工具服务（原 assets/scripts/image_search 的 Dart 移植版）
///
/// 两种模式（由输入自动切换）：
///   1. 填 imageUrl → 以图搜图：SerpAPI Google Lens 引擎
///   2. 填 query → 关键词搜图，按 provider 选图源：
///      unsplash / pixabay / google / bing / yahoo / yandex
///
/// API Key 存于 configs/toolbox/image_search_config.json
/// （首次使用自动从旧脚本配置 configs/scripts_center/ 迁移）。
class ImageSearchService {
  ImageSearchService._();

  static final ImageSearchService instance = ImageSearchService._();

  static const _configPath = 'configs/toolbox/image_search_config.json';
  static const _legacyConfigPath =
      'configs/scripts_center/image_search_config.json';

  /// 图源选项（google/bing/yahoo/yandex 共用 SerpAPI Key，
  /// 不支持翻页/方向/排序/类型）
  static const List<String> providers = [
    'unsplash',
    'pixabay',
    'google',
    'bing',
    'yahoo',
    'yandex',
  ];

  static const _serpEngines = {
    'google': {'engine': 'google_images', 'qParam': 'q'},
    'bing': {'engine': 'bing_images', 'qParam': 'q'},
    'yahoo': {'engine': 'yahoo_images', 'qParam': 'p'},
    'yandex': {'engine': 'yandex_images', 'qParam': 'text'},
  };

  /// 是否为 SerpAPI 搜索引擎图源（google/bing/yahoo/yandex，
  /// 结果为紧凑横排布局，不支持翻页/方向/排序）
  static bool isSerpProvider(String provider) => _serpEngines.containsKey(provider);

  Map<String, dynamic> _config = {};
  bool _loaded = false;

  Map<String, dynamic> get config => _config;

  /// 配置表单字段（与原脚本 configFormFields 一致）
  List<ToolboxConfigField> get configFields => const [
    ToolboxConfigField(
      name: 'unsplashAccessKey',
      type: 'password',
      labelText: 'Unsplash Access Key',
      hintText: 'unsplash.com 应用的 Access Key（注意不是 Secret Key），用 Unsplash 图源时必填',
    ),
    ToolboxConfigField(
      name: 'pixabayKey',
      type: 'password',
      labelText: 'Pixabay API Key',
      hintText: 'pixabay.com 个人中心生成的 Key，用 Pixabay 图源时必填',
    ),
    ToolboxConfigField(
      name: 'serpApiKey',
      type: 'password',
      labelText: 'SerpAPI Key',
      hintText: 'serpapi.com 的 API Key，以图搜图（Google Lens）与 google/bing/yahoo/yandex 图源共用，用到时必填',
    ),
    ToolboxConfigField(
      name: 'googleHl',
      type: 'text',
      labelText: 'Google 界面语言',
      hintText: 'Google 图源的 hl 参数，如 en / zh-CN（默认 en）',
      initialValue: 'en',
    ),
    ToolboxConfigField(
      name: 'googleGl',
      type: 'text',
      labelText: 'Google 地区',
      hintText: 'Google 图源的 gl 参数，如 us / cn（默认 us）',
      initialValue: 'us',
    ),
    ToolboxConfigField(
      name: 'perPage',
      type: 'number',
      labelText: '默认数量',
      hintText: '每次搜索返回几张（各图源范围内自动截断）',
      initialValue: 10,
    ),
    ToolboxConfigField(
      name: 'proxy',
      type: 'text',
      labelText: '网络代理（可选）',
      hintText: '如 http://127.0.0.1:7890，留空自动使用系统代理',
    ),
  ];

  /// 读取配置（首次自动迁移旧脚本中心配置）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final data = await AboutmeDataService.instance.readPath(_configPath);
      if (data is Map<String, dynamic>) {
        _config = data;
        return;
      }
      // 迁移旧脚本配置（原内置脚本 image_search 的 API Key 等）
      final legacy = await AboutmeDataService.instance.readPath(
        _legacyConfigPath,
      );
      if (legacy is Map<String, dynamic>) {
        _config = Map<String, dynamic>.from(legacy);
        await AboutmeDataService.instance.writePath(_configPath, _config);
        debugPrint('[toolbox] 已迁移 image_search 旧脚本配置');
      }
    } catch (e) {
      debugPrint('[toolbox] 读取 image_search 配置失败: $e');
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    _config = config;
    await AboutmeDataService.instance.writePath(_configPath, config);
  }

  String _cfg(String key) => (_config[key] ?? '').toString().trim();

  /// 发送 GET 请求（走系统代理或显式代理），body 自动 JSON 解析
  Future<Map<String, dynamic>> _getText(
    String url, {
    Map<String, String>? headers,
  }) async {
    final proxy = _cfg('proxy');
    final client = await createClientWithSystemProxy(
      proxyUrl: proxy.isEmpty ? null : proxy,
    );
    try {
      final resp = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));
      dynamic body;
      try {
        body = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
      } catch (_) {
        body = utf8.decode(resp.bodyBytes, allowMalformed: true);
      }
      return {'statusCode': resp.statusCode, 'body': body};
    } finally {
      client.close();
    }
  }

  /// 提取错误详情（兼容 JSON 与纯文本错误体），截断到 200 字符
  String _errorDetail(dynamic body) {
    String raw;
    if (body is Map) {
      final errors = body['errors'];
      raw = (errors is List && errors.isNotEmpty)
          ? errors.first.toString()
          : (body['error'] ?? jsonEncode(body)).toString();
    } else {
      raw = body?.toString() ?? '';
    }
    return raw.length > 200 ? raw.substring(0, 200) : raw;
  }

  /// 聚合搜索：填 [imageUrl] 走以图搜图（Google Lens），否则按 [query] 关键词搜图
  Future<ToolboxToolResult> search({
    String? query,
    String? imageUrl,
    String provider = 'unsplash',
    int? perPage,
    int page = 1,
    String imageType = 'photo',
    String orientation = 'any',
    String sort = 'relevant',
  }) async {
    await ensureLoaded();
    final q = (query ?? '').trim();
    final img = (imageUrl ?? '').trim();
    final mode = img.isNotEmpty ? 'lens' : 'keyword';
    final isSerp = _serpEngines.containsKey(provider);

    if (img.isEmpty && q.isEmpty) {
      return const ToolboxToolResult.fail('缺少 query / imageUrl');
    }

    // 按实际用到的图源校验对应 Key
    final serpKey = _cfg('serpApiKey');
    if (mode == 'lens' || (mode == 'keyword' && isSerp)) {
      if (serpKey.isEmpty) {
        return const ToolboxToolResult.fail('未配置 SerpAPI Key');
      }
    }
    if (mode == 'keyword' && !isSerp) {
      final key = provider == 'unsplash' ? _cfg('unsplashAccessKey') : _cfg('pixabayKey');
      if (key.isEmpty) {
        return ToolboxToolResult.fail('未配置 $provider 的 Key');
      }
    }

    try {
      if (mode == 'lens') return await _searchLens(img, serpKey, perPage);
      if (isSerp) {
        return await _searchSerpImages(q, provider, serpKey, perPage);
      }
      return await _searchKeywordApi(
        q,
        provider,
        perPage,
        page,
        imageType,
        orientation,
        sort,
      );
    } catch (e) {
      return ToolboxToolResult.fail('请求失败: $e');
    }
  }

  /// 以图搜图：SerpAPI Google Lens（不支持翻页）
  Future<ToolboxToolResult> _searchLens(
    String imageUrl,
    String serpKey,
    int? perPage,
  ) async {
    final limit = ((perPage ?? _configNum('perPage', 20))).clamp(1, 100);
    final url =
        'https://serpapi.com/search?engine=google_lens'
        '&url=${Uri.encodeComponent(imageUrl)}'
        '&api_key=${Uri.encodeComponent(serpKey)}';

    final resp = await _getText(url);
    final status = resp['statusCode'] as int;
    if (status >= 400) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${_errorDetail(resp['body'])} ${_serpHint(status)}',
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
          width: v['thumbnail_width'] is int ? v['thumbnail_width'] as int : null,
          height: v['thumbnail_height'] is int ? v['thumbnail_height'] as int : null,
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

  /// SerpAPI 搜索引擎图源（google/bing/yahoo/yandex，不支持翻页）
  Future<ToolboxToolResult> _searchSerpImages(
    String query,
    String provider,
    String serpKey,
    int? perPage,
  ) async {
    final eng = _serpEngines[provider]!;
    final limit = ((perPage ?? _configNum('perPage', 10))).clamp(1, 100);
    var url =
        'https://serpapi.com/search?engine=${eng['engine']}'
        '&${eng['qParam']}=${Uri.encodeComponent(query)}'
        '&api_key=${Uri.encodeComponent(serpKey)}';
    if (provider == 'google') {
      final hl = _cfg('googleHl').isEmpty ? 'en' : _cfg('googleHl');
      final gl = _cfg('googleGl').isEmpty ? 'us' : _cfg('googleGl');
      url +=
          '&google_domain=google.com&hl=${Uri.encodeComponent(hl)}'
          '&gl=${Uri.encodeComponent(gl)}';
    }

    final resp = await _getText(url);
    final status = resp['statusCode'] as int;
    if (status >= 400) {
      return ToolboxToolResult.fail(
        'HTTP $status: ${_errorDetail(resp['body'])} ${_serpHint(status)}',
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
          height: r['original_height'] is int ? r['original_height'] as int : null,
          source: provider,
        ),
      );
    }
    if (images.isEmpty) return const ToolboxToolResult.fail('无搜索结果');
    return ToolboxToolResult(
      success: true,
      message: '搜索 "$query" 命中 ${images.length}/${hits.length} 张（$provider）',
      data: {
        'mode': 'keyword',
        'provider': provider,
        'query': query,
        'total': hits.length,
        'page': 1,
        'images': images,
      },
    );
  }

  /// 关键词搜图：Unsplash / Pixabay 官方 API（支持翻页）
  Future<ToolboxToolResult> _searchKeywordApi(
    String query,
    String provider,
    int? perPage,
    int page,
    String imageType,
    String orientation,
    String sort,
  ) async {
    final raw = perPage ?? _configNum('perPage', 10);
    final isUnsplash = provider == 'unsplash';
    final effectivePerPage = isUnsplash ? raw.clamp(1, 30) : raw.clamp(3, 200);

    if (isUnsplash) {
      // 方向：landscape/portrait/squarish 有效；排序仅 relevant/latest
      const oriMap = {
        'landscape': 'landscape',
        'portrait': 'portrait',
        'squarish': 'squarish',
        'horizontal': 'landscape',
        'vertical': 'portrait',
      };
      final ori = oriMap[orientation] ?? '';
      final orderBy = sort == 'latest' ? 'latest' : 'relevant';
      var url =
          'https://api.unsplash.com/search/photos'
          '?query=${Uri.encodeComponent(query)}'
          '&per_page=$effectivePerPage&page=$page&order_by=$orderBy';
      if (ori.isNotEmpty) url += '&orientation=$ori';
      final r = await _getText(
        url,
        headers: {'Authorization': 'Client-ID ${_cfg('unsplashAccessKey')}'},
      );
      final status = r['statusCode'] as int;
      if (status >= 400) {
        final hint = status == 401
            ? '（Access Key 无效）'
            : status == 403
            ? '（演示额度 50 次/小时已用尽）'
            : '';
        return ToolboxToolResult.fail(
          'HTTP $status: ${_errorDetail(r['body'])} $hint',
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
            profileUrl: (((user?['links'] ?? {}) as Map)['html'] ?? '').toString(),
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
        message: '搜索 "$query" 命中 ${images.length}/${body['total'] ?? 0} 张（unsplash）',
        data: {
          'mode': 'keyword',
          'provider': 'unsplash',
          'query': query,
          'total': body['total'] is int ? body['total'] as int : 0,
          'page': page,
          'images': images,
        },
      );
    }

    // Pixabay：方向 horizontal/vertical 有效；排序 popular/latest
    const oriMap = {
      'horizontal': 'horizontal',
      'vertical': 'vertical',
      'landscape': 'horizontal',
      'portrait': 'vertical',
    };
    final ori = oriMap[orientation] ?? '';
    final order = sort == 'latest' ? 'latest' : 'popular';
    var url =
        'https://pixabay.com/api/?key=${Uri.encodeComponent(_cfg('pixabayKey'))}'
        '&q=${Uri.encodeComponent(query)}'
        '&per_page=$effectivePerPage&page=$page'
        '&image_type=${Uri.encodeComponent(imageType)}&order=$order';
    if (ori.isNotEmpty) url += '&orientation=$ori';

    final r = await _getText(url);
    final status = r['statusCode'] as int;
    final body = r['body'];
    // Pixabay 错误是纯文本 [ERROR 400] "..."（JSON 解析失败保持字符串）
    if (status >= 400 || body is String) {
      final detail = _errorDetail(body);
      final hint = RegExp('blocked|invalid', caseSensitive: false).hasMatch(detail)
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
      final overLimit = (page - 1) * effectivePerPage >= 500;
      return ToolboxToolResult.fail(overLimit ? '翻页超过 totalHits 上限 500' : '无搜索结果');
    }
    return ToolboxToolResult(
      success: true,
      message: '搜索 "$query" 命中 ${images.length}/$totalHits 张（pixabay）',
      data: {
        'mode': 'keyword',
        'provider': 'pixabay',
        'query': query,
        'total': totalHits,
        'page': page,
        'images': images,
      },
    );
  }

  int _configNum(String key, int fallback) {
    final v = _config[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  String _serpHint(int status) {
    if (status == 401) return '（SerpAPI Key 无效）';
    if (status == 429) return '（免费额度 250 次/月已用尽）';
    return '';
  }

  /// 提取 URL 中的域名（yandex 是站点名，bing/yahoo 是 URL）
  static String? _hostnameOf(String? u) {
    if (u == null || !RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) {
      return u;
    }
    return RegExp(r'^https?://([^/]+)', caseSensitive: false).firstMatch(u)?.group(1);
  }
}
