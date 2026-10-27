import 'package:flutter/foundation.dart';

import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/magnific_provider.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/pixabay_provider.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/serp_provider.dart';
import 'package:aboutme/plugins/toolbox/services/image_search/unsplash_provider.dart';

export 'package:aboutme/plugins/toolbox/services/image_search/image_search_context.dart';
export 'package:aboutme/plugins/toolbox/services/image_search/image_search_provider.dart';

/// 图片搜索小工具服务（原 assets/scripts/image_search 的 Dart 移植版）
///
/// 两种模式（由输入自动切换）：
///   1. 填 imageUrl → 以图搜图：SerpAPI Google Lens 引擎
///   2. 填 query → 关键词搜图，按 provider 选图源：
///      unsplash / pixabay / magnific / google / bing / yahoo / yandex
///
/// 各图源实现在 services/image_search/ 下（每图源一个文件），
/// 本类只负责配置、历史与分发。
///
/// API Key 存于 configs/toolbox/image_search_config.json
/// （首次使用自动从旧脚本配置 configs/scripts_center/ 迁移）。
class ImageSearchService {
  ImageSearchService._();

  static final ImageSearchService instance = ImageSearchService._();

  /// 图源选项（google/bing/yahoo/yandex 共用 SerpAPI Key，
  /// 不支持翻页/方向/排序/类型）
  static const List<String> providers = [
    'unsplash',
    'pixabay',
    'magnific',
    'google',
    'bing',
    'yahoo',
    'yandex',
  ];

  /// 图源实现注册表（serp 系四个引擎共用 SerpProvider）
  static const Map<String, ImageSearchProvider> _providerImpls = {
    'unsplash': UnsplashProvider(),
    'pixabay': PixabayProvider(),
    'magnific': MagnificProvider(),
    'google': SerpProvider(),
    'bing': SerpProvider(),
    'yahoo': SerpProvider(),
    'yandex': SerpProvider(),
  };

  /// 是否为 SerpAPI 搜索引擎图源（google/bing/yahoo/yandex，
  /// 结果为紧凑横排布局，不支持翻页/方向/排序）
  static bool isSerpProvider(String provider) =>
      SerpProvider.engines.containsKey(provider);

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
      hintText:
          'serpapi.com 的 API Key，以图搜图（Google Lens）与 google/bing/yahoo/yandex 图源共用，用到时必填',
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

  /// 读取配置（经 SDK 命令，首次自动迁移旧脚本中心配置）
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final res = await AboutmeDataService.instance.call(
        'toolbox',
        'getImageSearchConfig',
      );
      final data = res['success'] == true ? res['data'] : null;
      if (data is Map<String, dynamic>) {
        _config = data;
      }
    } catch (e) {
      debugPrint('[toolbox] 读取 image_search 配置失败: $e');
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    _config = config;
    await AboutmeDataService.instance.call('toolbox', 'saveImageSearchConfig', {
      'config': config,
    });
  }

  // ── 搜索历史 ─────────────────────────────────────────

  /// 读取最近搜索历史（新→旧）
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final res = await AboutmeDataService.instance.call(
        'toolbox',
        'getImageSearchHistory',
      );
      final data = res['success'] == true ? res['data'] : null;
      return data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  /// 追加一条搜索历史（相同关键词+模式+图源的去重置顶、截断在命令内）
  Future<void> addHistory({
    required String mode,
    required String query,
    required String imageUrl,
    required String provider,
  }) async {
    try {
      await AboutmeDataService.instance.call(
        'toolbox',
        'addImageSearchHistory',
        {
          'mode': mode,
          'query': query,
          'imageUrl': imageUrl,
          'provider': provider,
        },
      );
    } catch (e) {
      debugPrint('[toolbox] 写入搜索历史失败: $e');
    }
  }

  /// 删除指定时间戳的历史条目
  Future<void> removeHistory(int ts) async {
    await AboutmeDataService.instance.call(
      'toolbox',
      'removeImageSearchHistory',
      {'ts': ts},
    );
  }

  /// 清空搜索历史
  Future<void> clearHistory() async {
    await AboutmeDataService.instance.call(
      'toolbox',
      'clearImageSearchHistory',
    );
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

    if (img.isEmpty && q.isEmpty) {
      return const ToolboxToolResult.fail('缺少 query / imageUrl');
    }

    final ctx = ImageSearchContext(_config);
    try {
      if (mode == 'lens') {
        final err = const SerpProvider().validate(ctx);
        if (err != null) return ToolboxToolResult.fail(err);
        return await SerpProvider.searchLens(ctx, img, perPage);
      }
      final impl = _providerImpls[provider];
      if (impl == null) {
        return ToolboxToolResult.fail('未知图源 $provider');
      }
      final err = impl.validate(ctx);
      if (err != null) return ToolboxToolResult.fail(err);
      return await impl.search(
        ctx,
        ImageSearchQuery(
          query: q,
          provider: provider,
          perPage: perPage,
          page: page,
          imageType: imageType,
          orientation: orientation,
          sort: sort,
        ),
      );
    } catch (e) {
      return ToolboxToolResult.fail('请求失败: $e');
    }
  }
}
