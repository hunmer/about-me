import 'package:aboutme/screens/design_system_gallery/design_system_gallery_screen.dart';
import 'package:aboutme/screens/routing/route_definition.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';

/// 设计系统（手绘风组件库）展示路由注册表
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
      description: '手绘风设计系统组件展示',
        ),
      ];
}
