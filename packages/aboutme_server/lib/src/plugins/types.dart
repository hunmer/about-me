/// 插件处理器统一结果类型（对应 nodejs PluginResult）。
class PluginResult {
  const PluginResult.success(this.data)
      : isSuccess = true,
        message = null,
        code = null;

  const PluginResult.failure(this.message, [this.code = 'INTERNAL_ERROR'])
      : isSuccess = false,
        data = null;

  final bool isSuccess;
  final dynamic data;
  final String? message;
  final String? code;
}

/// 插件处理器：入参为用户 ID / 加密密钥 / 合并后的请求参数。
typedef PluginHandler = Future<PluginResult> Function(
  String userId,
  String encryptionKey,
  Map<String, dynamic> params,
);

typedef PluginHandlers = Map<String, PluginHandler>;

/// 插件路由定义（method + path 模式 + handler 名）。
class PluginRouteDefinition {
  const PluginRouteDefinition({
    required this.method,
    required this.path,
    required this.handler,
    this.resourceName,
  });

  final String method; // get | post | put | delete
  final String path; // 如 /channels/:id
  final String handler;
  final String? resourceName;
}

class PluginRouteConfig {
  const PluginRouteConfig({required this.pluginId, required this.routes});

  final String pluginId;
  final List<PluginRouteDefinition> routes;
}
