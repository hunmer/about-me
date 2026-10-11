import 'handler_factory.dart';
import 'plugin_data.dart';
import 'route_config.dart';
import 'types.dart';
import 'utils.dart';

/// 统一业务调用器：method + path 匹配路由表后直调 handler。
/// 同一入口供 REST API、MCP 工具与本地 SDK facade 使用。
///
/// handler 通过工厂捕获本次调用传入的 [PluginData] 后端实例，
/// 因此**不做处理器缓存**——每个请求/会话使用自己的数据后端
/// （服务端为用户目录，客户端为本地根目录），闭包捕获即正确隔离。
class PluginInvoker {
  static const _pluginApiPrefix = '/api/v1/plugins/';

  /// 调用插件 API；path 形如 `/api/v1/plugins/todo/tasks`。
  /// 返回 `{success, data?, error?, code?, timestamp}`。
  Future<Map<String, dynamic>> invoke(
    PluginData data,
    String method,
    String apiPath, {
    Map<String, dynamic>? query,
    dynamic body,
  }) async {
    final timestamp = jsIsoDateTime(DateTime.now());
    Map<String, dynamic> fail(String error) =>
        {'success': false, 'error': error, 'timestamp': timestamp};

    if (!apiPath.startsWith(_pluginApiPrefix)) {
      return fail('不支持的路径: $apiPath');
    }

    final rest = apiPath
        .substring(_pluginApiPrefix.length)
        .replaceAll(RegExp(r'/+$'), '');
    final slash = rest.indexOf('/');
    final pluginId = slash == -1 ? rest : rest.substring(0, slash);
    final subPath = slash == -1 ? '/' : rest.substring(slash);

    final config = pluginRouteConfigOf(pluginId);
    if (config == null) return fail('未知插件: $pluginId');

    // 按注册顺序匹配
    PluginRouteDefinition? matched;
    Map<String, String>? pathParams;
    for (final route in config.routes) {
      if (route.method != method) continue;
      final params = matchRoute(route.path, subPath);
      if (params != null) {
        matched = route;
        pathParams = params;
        break;
      }
    }
    if (matched == null || pathParams == null) {
      return fail('未找到路由: ${method.toUpperCase()} $apiPath');
    }

    // 每次调用重建 handlers：闭包捕获当前 backend，保证多用户/多会话隔离
    final handlers = createHandlersForPlugin(data, pluginId);
    final handler = handlers[matched.handler];
    if (handler == null) return fail('处理器不存在: ${matched.handler}');

    // 参数合并顺序: query -> path -> body
    final params = <String, dynamic>{
      ...?query,
      ...pathParams,
      if (body is Map) ...body.cast<String, dynamic>(),
    };

    try {
      final result = await handler(data, params);
      if (result.isSuccess) {
        return {
          'success': true,
          'data': result.data,
          'timestamp': timestamp,
        };
      }
      return {
        'success': false,
        'error': result.message,
        'code': result.code,
        'timestamp': timestamp,
      };
    } catch (e) {
      return fail('服务器错误: $e');
    }
  }
}
