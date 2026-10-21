import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/js_bridge/js_bridge_plugin.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';

import 'models/media_item.dart';
import 'sample_data.dart';
import 'screens/media_detail_screen.dart';
import 'screens/media_list_screen.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';

part 'media_log_js_api.dart';

/// 媒体记录插件：阅读记录 + 观影记录（瀑布流封面网格，手绘纸墨风）
class MediaLogPlugin extends BasePlugin with JSBridgePlugin {
  static MediaLogPlugin? _instance;
  static MediaLogPlugin get instance {
    if (_instance == null) {
      _instance = PluginManager.instance.getPlugin('media_log') as MediaLogPlugin?;
      if (_instance == null) {
        throw StateError('MediaLogPlugin has not been initialized');
      }
    }
    return _instance!;
  }

  static const _uuid = Uuid();

  final List<MediaItem> _items = [];
  final List<Function()> _listeners = [];

  /// 列表视图模式（grid / list / shelf），默认书柜，持久化到 ui_settings.json
  String _viewMode = 'shelf';

  String get viewMode => _viewMode;

  Future<void> setViewMode(String mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    await AboutmeDataService.instance.writePath(
      'media_log/ui_settings.json',
      {'viewMode': mode},
    );
  }

  List<MediaItem> get items => _items;

  void addListener(Function() listener) => _listeners.add(listener);
  void removeListener(Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  String get id => 'media_log';

  @override
  Color get color => const Color.fromARGB(255, 126, 110, 197);

  @override
  IconData get icon => Icons.local_library;

  @override
  Future<void> initialize() async {
    await _loadItems();
    // 注册 JS API（最后一步）
    await registerJSAPI();
  }

  @override
  Future<bool> refreshData([PluginRefreshDataArgs? args]) async {
    try {
      await _loadItems();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MediaLogPlugin] 刷新数据失败: $e');
      return false;
    }
  }

  Future<void> _loadItems() async {
    try {
      // 视图偏好（独立小文件，读取失败回落默认书柜）
      final ui = await AboutmeDataService.instance.readPath(
        'media_log/ui_settings.json',
      );
      final mode = ui is Map ? ui['viewMode'] : null;
      if (mode == 'grid' || mode == 'list' || mode == 'shelf') {
        _viewMode = mode;
      }

      final data = await AboutmeDataService.instance.readPath(
        'media_log/items.json',
      );
      _items.clear();
      if (data.isNotEmpty && data['items'] != null) {
        for (final item in data['items'] as List) {
          _items.add(MediaItem.fromJson(Map<String, dynamic>.from(item)));
        }
      } else {
        // 首次使用：写入示例数据（来自 ai_picks_demo 的演示内容 + 观影示例）
        _items.addAll(MediaSampleData.build());
        await _persist();
      }
    } catch (e) {
      debugPrint('[MediaLogPlugin] 加载数据失败: $e');
    }
  }

  Future<void> _persist() async {
    await AboutmeDataService.instance.writePath('media_log/items.json', {
      'items': [for (final item in _items) item.toJson()],
    });
  }

  MediaItem? getItem(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 所有条目的标签集合（排序后，供表单快捷 chips / 过滤栏使用）
  List<String> getAllTags() {
    final tags = <String>{};
    for (final item in _items) {
      tags.addAll(item.tags);
    }
    return tags.toList()..sort();
  }

  /// 新增或更新条目（按 id 匹配），返回保存后的条目
  Future<MediaItem> saveItem(MediaItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _items.insert(0, item);
    } else {
      _items[index] = item;
    }
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _persist();
    notifyListeners();
  }

  /// 新增 / 更新点评（可多条）
  Future<void> saveReview(String itemId, MediaReview review) async {
    final item = getItem(itemId);
    if (item == null) return;
    final index = item.reviews.indexWhere((r) => r.id == review.id);
    final reviews = [...item.reviews];
    if (index == -1) {
      reviews.add(review);
    } else {
      reviews[index] = review;
    }
    reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await saveItem(item.copyWith(reviews: reviews));
  }

  Future<void> deleteReview(String itemId, String reviewId) async {
    final item = getItem(itemId);
    if (item == null) return;
    await saveItem(
      item.copyWith(
        reviews: item.reviews.where((r) => r.id != reviewId).toList(),
      ),
    );
  }

  static String newId() => _uuid.v4();

  @override
  Future<void> registerToApp(
    PluginManager pluginManager,
    ConfigManager configManager,
  ) async {}

  @override
  String? getPluginName(context) => 'media_name'.tr;

  @override
  Widget buildMainView(BuildContext context) {
    return DSThemeBridge(child: const MediaListScreen());
  }

  @override
  VoidCallback? buildCreatedDetailOpener(
    BuildContext context,
    String method,
    Map<String, dynamic> created,
  ) {
    if (method != 'createMediaItem' && method != 'createItem') return null;
    final itemId = created['id'] as String?;
    if (itemId == null) return null;
    return () => SmoothBottomSheet.showScreen(
      context: context,
      screen: MediaDetailScreen(itemId: itemId),
    );
  }

  @override
  Map<String, Function> defineJSAPI() {
    return {
      // 条目相关
      'getMediaItems': _jsGetMediaItems,
      'getItems': _jsGetMediaItems, // 别名
      'getMediaItem': _jsGetMediaItem,
      'getItemById': _jsGetMediaItem, // 别名
      'createMediaItem': _jsCreateMediaItem,
      'createItem': _jsCreateMediaItem, // 别名
      'updateMediaItem': _jsUpdateMediaItem,
      'updateItem': _jsUpdateMediaItem, // 别名
      'deleteMediaItem': _jsDeleteMediaItem,
      'deleteItem': _jsDeleteMediaItem, // 别名
      // 点评相关
      'addMediaReview': _jsAddMediaReview,
      'addReview': _jsAddMediaReview, // 别名
      'deleteMediaReview': _jsDeleteMediaReview,
      'deleteReview': _jsDeleteMediaReview, // 别名
    };
  }
}
