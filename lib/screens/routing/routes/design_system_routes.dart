import 'package:aboutme/screens/design_system_gallery/design_system_gallery_screen.dart';
import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';

/// 设计系统（软糖果冻风组件库）展示路由注册表
class DesignSystemRoutes implements RouteRegistry {
  @override
  String get name => 'DesignSystemRoutes';

  @override
  List<RouteDefinition> get routes => [
        RouteDefinition(
          path: '/design_system',
          handler: (settings) => RouteHelpers.createRoute(
            const DesignSystemGalleryScreen(),
            settings: settings,
          ),
          description: '软糖果冻风设计系统组件展示',
        ),
      ];
}
