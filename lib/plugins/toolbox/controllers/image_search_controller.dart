import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/utils/network.dart';
import 'package:aboutme/plugins/toolbox/models/toolbox_models.dart';
import 'package:aboutme/plugins/toolbox/services/image_search_service.dart';

/// 图片搜索小工具控制器（ChangeNotifier，独立界面持有）
class ImageSearchController extends ChangeNotifier {
  final ImageSearchService _service = ImageSearchService.instance;

  // ── 表单状态 ──
  /// 搜索模式：keyword=关键词搜图 / lens=以图搜图
  String mode = 'keyword';
  String query = '';
  String imageUrl = '';
  String provider = 'unsplash';
  String imageType = 'photo'; // pixabay/magnific
  String orientation = 'any';
  String sort = 'relevant';
  int perPage = 10;
  int page = 1;

  // ── 结果状态 ──
  bool searching = false;
  bool searched = false;
  String? error;
  List<SearchedImage> images = [];
  int total = 0;
  int resultPage = 1;
  String lastMessage = '';

  /// 最近搜索历史（新→旧，未搜索状态的初始页展示）
  List<Map<String, dynamic>> history = [];

  /// 历史图源过滤（null=全部；值为 provider 或 'google_lens'）
  String? historyFilter;

  /// 历史中实际出现过的图源集合（过滤 chips 用）
  Set<String> get historyProviders =>
      {for (final e in history) e['provider']?.toString() ?? ''}..remove('');

  /// 过滤后的历史列表
  List<Map<String, dynamic>> get filteredHistory => historyFilter == null
      ? history
      : history
            .where((e) => e['provider']?.toString() == historyFilter)
            .toList();

  void setHistoryFilter(String? value) {
    historyFilter = value;
    notifyListeners();
  }

  /// 当前图源是否支持翻页（unsplash/pixabay/magnific）
  bool get canPaging =>
      mode == 'keyword' &&
      (provider == 'unsplash' ||
          provider == 'pixabay' ||
          provider == 'magnific');

  /// 缩略图字节缓存（key=图片 URL），走系统代理下载，
  /// google/bing 等被墙图源的缓存缩略图才能显示（Image.network 不走代理）
  final Map<String, Uint8List> thumbBytes = {};
  final Set<String> _thumbLoading = {};
  http.Client? _thumbClient;

  void setMode(String value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }

  void setProvider(String value) {
    provider = value;
    notifyListeners();
  }

  void setImageType(String value) {
    imageType = value;
    notifyListeners();
  }

  void setOrientation(String value) {
    orientation = value;
    notifyListeners();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  void setPerPage(int value) {
    perPage = value;
    notifyListeners();
  }

  /// 执行搜索（自动按 mode 选择输入）
  Future<void> search({bool resetPage = true}) async {
    if (searching) return;
    if (resetPage) page = 1;

    if (mode == 'keyword' && query.trim().isEmpty) {
      Toast.warning('请输入搜索关键词');
      return;
    }
    if (mode == 'lens' && imageUrl.trim().isEmpty) {
      Toast.warning('请输入图片 URL');
      return;
    }

    searching = true;
    error = null;
    notifyListeners();
    try {
      final result = await _service.search(
        query: mode == 'keyword' ? query : '',
        imageUrl: mode == 'lens' ? imageUrl : '',
        provider: provider,
        perPage: perPage,
        page: page,
        imageType: imageType,
        orientation: orientation,
        sort: sort,
      );
      if (!result.success) {
        error = result.error ?? '搜索失败';
        images = [];
        total = 0;
        Toast.error(error!);
      } else {
        final data = result.data ?? {};
        images = List<SearchedImage>.from(data['images'] ?? []);
        total = (data['total'] as num?)?.toInt() ?? images.length;
        resultPage = (data['page'] as num?)?.toInt() ?? 1;
        lastMessage = result.message ?? '';
        thumbBytes.clear();
        Toast.success(lastMessage);
        // 成功才记历史（失败的关键词不进记录）
        await _service.addHistory(
          mode: mode,
          query: query.trim(),
          imageUrl: imageUrl.trim(),
          provider: mode == 'lens' ? 'google_lens' : provider,
        );
        history = await _service.getHistory();
      }
      searched = true;
    } catch (e) {
      error = e.toString();
      images = [];
      searched = true;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  /// 加载最近搜索历史（界面 initState 调用）
  Future<void> loadHistory() async {
    history = await _service.getHistory();
    notifyListeners();
  }

  /// 点击历史条目：回填表单并重新搜索
  Future<void> searchFromHistory(Map<String, dynamic> entry) async {
    mode = (entry['mode'] as String?) ?? 'keyword';
    query = (entry['query'] as String?) ?? '';
    imageUrl = (entry['imageUrl'] as String?) ?? '';
    final p = entry['provider'] as String?;
    if (p != null &&
        p != 'google_lens' &&
        ImageSearchService.providers.contains(p)) {
      provider = p;
    }
    await search();
  }

  /// 删除单条历史（时间戳定位）
  Future<void> removeHistory(Map<String, dynamic> entry) async {
    final ts = entry['ts'];
    await _service.removeHistory(ts is int ? ts : int.tryParse('$ts') ?? 0);
    history = await _service.getHistory();
    notifyListeners();
  }

  /// 清空搜索历史
  Future<void> clearHistory() async {
    await _service.clearHistory();
    history = [];
    notifyListeners();
  }

  /// 下一页（仅支持翻页的图源）
  Future<void> nextPage() {
    page = page + 1;
    return search(resetPage: false);
  }

  /// 上一页
  Future<void> prevPage() {
    if (page <= 1) return Future.value();
    page = page - 1;
    return search(resetPage: false);
  }

  /// 下载缩略图字节（带系统代理，成功后 notify 刷新对应格子）
  void loadThumb(String url) {
    if (url.isEmpty ||
        thumbBytes.containsKey(url) ||
        _thumbLoading.contains(url)) {
      return;
    }
    _thumbLoading.add(url);
    () async {
      try {
        _thumbClient ??= await createClientWithSystemProxy();
        final resp = await _thumbClient!
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          thumbBytes[url] = resp.bodyBytes;
          notifyListeners();
        }
      } catch (_) {
        /* 下载失败保持占位图标 */
      } finally {
        _thumbLoading.remove(url);
      }
    }();
  }

  /// 展示图字节缓存 key 列表预热（列表滚动时逐个触发）
  void preloadThumbs() {
    for (final img in images) {
      loadThumb(img.thumb.isNotEmpty ? img.thumb : img.url);
    }
  }

  @override
  void dispose() {
    _thumbClient?.close();
    super.dispose();
  }
}
