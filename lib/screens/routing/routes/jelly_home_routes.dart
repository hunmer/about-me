import 'package:aboutme/screens/jelly_home/jelly_home_screen.dart';
import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';

/// 果冻小屋（软糖果冻风主页）路由注册表
class JellyHomeRoutes implements RouteRegistry {
  @override
  String get name => 'JellyHomeRoutes';

  @override
  List<RouteDefinition> get routes => [
        RouteDefinition(
          path: '/jelly_home',
          handler: (settings) => RouteHelpers.createRoute(
            const JellyHomeScreen(),
            settings: settings,
          ),
          description: '果冻小屋主页（软糖果冻风布局还原）',
        ),
      ];
}
