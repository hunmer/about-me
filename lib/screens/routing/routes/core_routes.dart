import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';
import 'package:aboutme/screens/home_screen/home_screen.dart';
import 'package:aboutme/screens/onboarding/onboarding_screen.dart';
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

        // 引导页
        RouteDefinition(
          path: '/onboarding',
          handler: (settings) => RouteHelpers.createRoute(
            const OnboardingScreen(),
            settings: settings,
          ),
          description: '引导页（首次启动展示）',
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
