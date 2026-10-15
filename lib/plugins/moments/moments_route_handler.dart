import 'package:flutter/material.dart';

import 'package:aboutme/core/routing/plugin_route_handler.dart';

import 'screens/moments_home_screen.dart';
import 'screens/moments_profile_screen.dart';

/// 朋友圈插件路由处理器
///
/// - `/moments` 打开插件宿主页（tabs：动态流/回忆/我的主页）
/// - `/moments/profile?agentId={id}` 打开个人主页（无 agentId 为「我」）
class MomentsRouteHandler extends PluginRouteHandler {
  @override
  String get pluginId => 'moments';

  @override
  Route<dynamic>? handleRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    if (!routeName.startsWith('/moments')) return null;

    final uri = Uri.parse(routeName);
    if (uri.path == '/moments/profile') {
      final agentId = uri.queryParameters['agentId'];
      return createRoute(MomentsProfileScreen(agentId: agentId));
    }
    return createRoute(const MomentsHomeScreen());
  }
}
