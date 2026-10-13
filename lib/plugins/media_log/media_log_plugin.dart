import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:aboutme/core/data/aboutme_data_service.dart';
import 'package:aboutme/core/plugin_base.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/base_plugin.dart';
import 'package:aboutme/core/plugin_manager.dart';
import 'package:aboutme/core/config_manager.dart';

import 'models/media_item.dart';
import 'sample_data.dart';
import 'screens/media_list_screen.dart';

/// 媒体记录插件：阅读记录 + 观影记录（瀑布流封面网格，手绘纸墨风）
class MediaLogPlugin extends BasePlugin {
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
}
