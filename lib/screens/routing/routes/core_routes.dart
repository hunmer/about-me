import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';
import 'package:aboutme/screens/home_screen/home_screen.dart';
import 'package:aboutme/screens/settings_screen/settings_screen.dart';

/// 核心屏幕路由注册表
class CoreRoutes implements RouteRegistry {
  @override
  String get name => 'CoreRoutes';

  @override
  List<RouteDefinition> get routes => [
        // 主屏幕
        RouteDefinition(
          path: '/',
          handler: (settings) => RouteHelpers.createRoute(const HomeScreen()),
          description: '主屏幕',
        ),
        RouteDefinition(
          path: 'home',
          handler: (settings) => RouteHelpers.createRoute(const HomeScreen()),
          description: '主屏幕（别名）',
        ),

        // 日程（主屏幕日期数据视图，从果冻小屋底部导航进入）
        RouteDefinition(
          path: '/home_schedule',
          handler:
              (settings) => RouteHelpers.createRoute(
                const HomeScreen(dateView: true, asRoot: false),
                settings: settings,
              ),
          description: '日程（日期数据视图主页）',
        ),

        // 看板（主屏幕固定布局网格，从果冻小屋底部导航进入）
        RouteDefinition(
          path: '/home_board',
          handler:
              (settings) => RouteHelpers.createRoute(
                const HomeScreen(asRoot: false),
                settings: settings,
              ),
          description: '看板（固定布局网格主页）',
        ),

        // 设置页面
        RouteDefinition(
          path: '/settings',
          handler: (settings) => RouteHelpers.createRoute(const SettingsScreen()),
          description: '设置界面',
        ),
        RouteDefinition(
          path: 'settings',
          handler: (settings) => RouteHelpers.createRoute(const SettingsScreen()),
          description: '设置界面（别名）',
        ),
      ];
}
