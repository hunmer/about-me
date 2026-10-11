import 'route_config.dart';

/// 业务动作解析：按路由表把 handler 名解析为 (method, path)。
/// 路径中的 `:param` 占位用 params 中同名键填充。
(String, String)? resolveAction(
  String pluginId,
  String action,
  Map<String, dynamic> params,
) {
  final config = pluginRouteConfigOf(pluginId);
  if (config == null) return null;

  for (final route in config.routes) {
    if (route.handler != action) continue;
    final filled = route.path.split('/').map((segment) {
      if (segment.startsWith(':')) {
        final key = segment.substring(1);
        final value = params[key];
        return value == null ? segment : Uri.encodeComponent(value.toString());
      }
      return segment;
    }).join('/');
    return (route.method, filled);
  }
  return null;
}
