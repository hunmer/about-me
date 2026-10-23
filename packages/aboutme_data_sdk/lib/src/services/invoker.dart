import '../storage_errors.dart';
import 'handler_factory.dart';
import 'persistent_plugin_backend.dart';
import 'plugin_data.dart';
import 'route_config.dart';
import 'types.dart';
import 'utils.dart';
import 'action_resolver.dart';

/// REST、MCP 与本地业务共用路由、校验、事务和错误协议。
class PluginInvoker {
  static const _prefix = '/api/v1/plugins/';

  Future<Map<String, dynamic>> invokeAction(
    PluginData data,
    String pluginId,
    String action,
    Map<String, dynamic> params,
  ) async {
    final resolved = resolveAction(pluginId, action, params);
    if (resolved == null)
      return {
        'success': false,
        'error': '未知业务方法: $pluginId.$action',
        'code': 'UNSUPPORTED',
        'timestamp': jsIsoDateTime(DateTime.now()),
      };
    return invoke(
      data,
      resolved.$1,
      '$_prefix$pluginId${resolved.$2}',
      query: resolved.$1 == 'get' ? params : null,
      body: resolved.$1 == 'get' ? null : params,
    );
  }

  Future<Map<String, dynamic>> invoke(
    PluginData data,
    String method,
    String apiPath, {
    Map<String, dynamic>? query,
    dynamic body,
  }) async {
    final timestamp = jsIsoDateTime(DateTime.now());
    Map<String, dynamic> fail(
      String message, [
      String code = 'INTERNAL_ERROR',
    ]) => {
      'success': false,
      'error': message,
      'code': code,
      'timestamp': timestamp,
    };
    try {
      if (!apiPath.startsWith(_prefix)) return fail('不支持的路径', 'UNSUPPORTED');
      final rest = apiPath
          .substring(_prefix.length)
          .replaceAll(RegExp(r'/+$'), '');
      final slash = rest.indexOf('/');
      final pluginId = slash < 0 ? rest : rest.substring(0, slash);
      final subPath = slash < 0 ? '/' : rest.substring(slash);
      final config = pluginRouteConfigOf(pluginId);
      if (config == null) return fail('未知插件: $pluginId', 'UNSUPPORTED');
      final verb = method.toLowerCase();
      PluginRouteDefinition? matched;
      Map<String, String>? pathParams;
      for (final route in config.routes) {
        if (route.method != verb) continue;
        final match = matchRoute(route.path, subPath);
        if (match != null) {
          matched = route;
          pathParams = match;
          break;
        }
      }
      if (matched == null || pathParams == null)
        return fail('未找到业务路由', 'UNSUPPORTED');
      if (body != null && body is! Map<String, dynamic>)
        return fail('请求体必须是对象', 'INVALID_PARAMS');
      final params = <String, dynamic>{
        ...?query,
        if (body is Map<String, dynamic>) ...body,
      };
      for (final entry in pathParams.entries) {
        if (entry.value.isEmpty || entry.value.startsWith(':'))
          return fail('缺少路径参数: ${entry.key}', 'INVALID_PARAMS');
        if (params.containsKey(entry.key) &&
            params[entry.key]?.toString() != entry.value) {
          return fail('路径参数与请求参数不一致: ${entry.key}', 'INVALID_PARAMS');
        }
        params[entry.key] = entry.value;
      }
      final validation = validateActionParams(params);
      if (validation != null) return fail(validation, 'INVALID_PARAMS');
      final route = matched;
      Future<Map<String, dynamic>> operation(PluginData transaction) async {
        final handler = createHandlersForPlugin(
          transaction,
          pluginId,
        )[route.handler];
        if (handler == null)
          return fail('处理器不存在: ${route.handler}', 'UNSUPPORTED');
        // 命令元数据不能混入持久化业务实体。
        final payload = Map<String, dynamic>.from(params)
          ..remove('expectedVersion')
          ..remove('clientMutationId')
          ..remove('sourceDeviceId');
        final result = await handler(transaction, payload);
        return result.isSuccess
            ? {'success': true, 'data': result.data, 'timestamp': timestamp}
            : fail(result.message ?? '操作失败', result.code ?? 'INTERNAL_ERROR');
      }

      if (data is TransactionalPluginData) {
        return await data.execute(
          pluginId: pluginId,
          action: route.handler,
          resource: route.resourceName ?? pluginId,
          isQuery: verb == 'get',
          params: params,
          operation: operation,
        );
      }
      return await operation(data);
    } on StoragePathException catch (error) {
      return fail(error.message, 'INVALID_PARAMS');
    } on StorageException catch (error) {
      return fail(error.message, switch (error.kind) {
        StorageErrorKind.unauthorized => 'UNAUTHORIZED',
        StorageErrorKind.notFound => 'NOT_FOUND',
        StorageErrorKind.conflict => 'CONFLICT',
        StorageErrorKind.offline => 'OFFLINE',
        StorageErrorKind.invalidData => 'CORRUPT_DATA',
        StorageErrorKind.invalidRequest => 'INVALID_PARAMS',
        StorageErrorKind.unsupported => 'UNSUPPORTED',
        StorageErrorKind.server => 'INTERNAL_ERROR',
      });
    } on FormatException catch (error) {
      return fail(error.message, 'INVALID_PARAMS');
    } catch (error) {
      return fail('业务执行失败: $error');
    }
  }
}

/// 传输层只按已声明参数解码，字符串 ID、日期和任意文本不猜测类型。
const integerActionParams = {'offset', 'count', 'limit', 'expectedVersion'};
const booleanActionParams = {'fuzzy'};
String? validateActionParams(Map<String, dynamic> params) {
  for (final key in integerActionParams) {
    if (!params.containsKey(key)) continue;
    final value = params[key];
    if (value is! int || value < 0 || (key == 'limit' && value == 0))
      return '$key 必须为有效非负整数';
  }
  for (final key in booleanActionParams) {
    if (params.containsKey(key) && params[key] is! bool) return '$key 必须为布尔值';
  }
  for (final key in ['clientMutationId', 'sourceDeviceId']) {
    if (params.containsKey(key) &&
        (params[key] is! String || (params[key] as String).isEmpty))
      return '$key 必须为非空字符串';
  }
  return null;
}
