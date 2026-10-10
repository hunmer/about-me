import 'package:aboutme_data_sdk/io.dart';

import 'handler_factory.dart';
import 'route_config.dart';
import 'types.dart';
import 'utils.dart';

/// 进程内插件调用器（移植自 nodejs invoker.ts）：
/// 复用路由表做 method+path 匹配，直接调用处理器，
/// 语义与 HTTP 插件路由完全一致（含注册顺序）。
class PluginInvoker {
  PluginInvoker(this.store, {this.onMutation});

  final PluginDataStore store;
  final void Function(String userId, String pluginId, String? sourceDeviceId)?
  onMutation;

  final _handlersCache = <String, PluginHandlers>{};

  static const _pluginApiPrefix = '/api/v1/plugins/';

  /// 调用插件 API；path 形如 `/api/v1/plugins/todo/tasks`。
  /// 返回 `{success, data?, error?, code?, timestamp}`。
  Future<Map<String, dynamic>> invoke(
    String userId,
    String encryptionKey,
    String method,
    String apiPath, {
    Map<String, dynamic>? query,
    dynamic body,
    String? sourceDeviceId,
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

    // 按注册顺序匹配，与 Express 路由行为一致
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

    var handlers = _handlersCache[pluginId];
    if (handlers == null) {
      handlers = createHandlersForPlugin(store, pluginId);
      _handlersCache[pluginId] = handlers;
    }
    final handler = handlers[matched.handler];
    if (handler == null) return fail('处理器不存在: ${matched.handler}');

    // 参数合并顺序与 nodejs 一致: query -> path -> body
    final params = <String, dynamic>{
      ...?query,
      ...pathParams,
      if (body is Map) ...body.cast<String, dynamic>(),
    };

    try {
      final result = await handler(userId, encryptionKey, params);
      if (result.isSuccess) {
        if (method == 'post' || method == 'put' || method == 'delete') {
          onMutation?.call(userId, pluginId, sourceDeviceId);
        }
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
