import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';
import 'package:aboutme/screens/json_dynamic_test/json_dynamic_test_screen.dart';
import 'package:aboutme/screens/floating_widget_screen/floating_widget_screen.dart';
import 'package:aboutme/screens/settings_screen/screens/live_activities_test_screen.dart';
import 'package:aboutme/screens/log_screen/log_screen.dart';

/// 测试页面路由注册表
class TestRoutes implements RouteRegistry {
  @override
  String get name => 'TestRoutes';

  @override
  List<RouteDefinition> get routes => [
        // JSON 动态测试
        RouteDefinition(
          path: '/json_dynamic_test',
          handler: (settings) => RouteHelpers.createRoute(const JsonDynamicTestScreen()),
          description: 'JSON 动态测试',
        ),
        RouteDefinition(
          path: 'json_dynamic_test',
          handler: (settings) => RouteHelpers.createRoute(const JsonDynamicTestScreen()),
          description: 'JSON 动态测试（别名）',
        ),

        // 悬浮小组件测试
        RouteDefinition(
          path: '/floating_ball',
          handler: (settings) => RouteHelpers.createRoute(const FloatingBallScreen()),
          description: '悬浮小组件设置',
        ),
        RouteDefinition(
          path: 'floating_ball',
          handler: (settings) => RouteHelpers.createRoute(const FloatingBallScreen()),
          description: '悬浮小组件设置（别名）',
        ),

        // Live Activities 测试
        RouteDefinition(
          path: '/live_activities_test',
          handler: (settings) => RouteHelpers.createRoute(const LiveActivitiesTestScreen()),
          description: 'Live Activities 测试',
        ),
        RouteDefinition(
          path: 'live_activities_test',
          handler: (settings) => RouteHelpers.createRoute(const LiveActivitiesTestScreen()),
          description: 'Live Activities 测试（别名）',
        ),

        // 日志屏幕
        RouteDefinition(
          path: '/log',
          handler: (settings) => RouteHelpers.createRoute(const LogScreen()),
          description: '日志屏幕',
        ),
        RouteDefinition(
          path: 'log',
          handler: (settings) => RouteHelpers.createRoute(const LogScreen()),
          description: '日志屏幕（别名）',
        ),
      ];
}
