import 'package:flutter/material.dart';
import 'package:aboutme/core/routing/plugin_route_handler.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/plugins/media_log/screens/media_detail_screen.dart';
import 'package:aboutme/plugins/media_log/screens/media_list_screen.dart';

/// 媒体记录插件路由处理器
///
/// 支持：
/// - `/media_log` 打开插件主视图
/// - `/media_log/detail?itemId={itemId}` 打开条目详情
class MediaLogRouteHandler extends PluginRouteHandler {
  @override
  String get pluginId => 'media_log';

  @override
  Route<dynamic>? handleRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    if (!routeName.startsWith('/media_log')) return null;

    final uri = Uri.parse(routeName);
    final itemId = uri.queryParameters['itemId'];

    if (uri.path == '/media_log/detail') {
      if (itemId == null || itemId.isEmpty) return null;
      return createRoute(MediaDetailScreen(itemId: itemId));
    }

    // 主视图：列表页需在主题树内渲染
    return createRoute(
      const DSThemeBridge(child: Material(child: MediaListScreen())),
    );
  }
}
