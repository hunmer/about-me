import 'package:aboutme/core/app_initializer.dart';
import 'package:aboutme/screens/jelly_home/jelly_home_screen.dart';
import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';

/// 果冻小屋（手绘风主页）路由注册表
///
/// 页签编入路由：`/jelly_home`（小屋）与 `/jelly_home/1`~`/jelly_home/4`，
/// 直达或恢复路由时落到对应页签；`/jelly_home` 不带索引，
/// 取持久化的上次停留页签（热重启后仍能恢复）
class JellyHomeRoutes implements RouteRegistry {
  @override
  String get name => 'JellyHomeRoutes';

  @override
  List<RouteDefinition> get routes => [
        for (var index = 0; index < JellyHomeScreen.tabCount; index++)
          RouteDefinition(
            path: index == 0 ? '/jelly_home' : '/jelly_home/$index',
            handler: (settings) => RouteHelpers.createRoute(
              JellyHomeScreen(
                initialIndex: index == 0 ? _savedTabIndex() : index,
              ),
              settings: settings,
              useAnimation: false,
            ),
            description: '果冻小屋主页（手绘风布局还原）',
          ),
      ];

  /// 上次停留页签（页签切换时由主页写入），越界时回落小屋
  static int _savedTabIndex() =>
      globalConfigManager.getAppConfigValue<num?>(
        JellyHomeScreen.tabConfigKey,
        null,
      )?.toInt().clamp(0, JellyHomeScreen.tabCount - 1) ??
      0;
}
