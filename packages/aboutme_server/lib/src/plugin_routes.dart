import 'dart:convert';

import 'package:aboutme_data_sdk/io.dart';
import 'package:shelf/shelf.dart';

import 'auth_middleware.dart';
import 'ws_hub.dart';

/// 插件 REST 路由：`/api/v1/plugins/{pluginId}/*`（认证即可，数据明文）。
/// 每个请求构建绑定该用户目录的数据后端，业务逻辑全部来自 SDK；
/// 写操作经后端事件回调广播 WS 同步。
class PluginApi {
  PluginApi({required this.storage, required this.wsHub});

  final LocalFileStorage storage;
  final StorageWsHub wsHub;
  final PluginInvoker invoker = PluginInvoker();

  Response _json(int status, Map<String, dynamic> body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _error(int status, String message) => _json(status, {
    'success': false,
    'error': message,
    'timestamp': jsIsoDateTime(DateTime.now()),
  });

  Handler get handler => (request) async {
    final auth = authContextOf(request);
    if (auth == null) return _error(401, '未认证');

    // query 参数宽松类型转换（数字/布尔）
    final query = <String, dynamic>{};
    request.url.queryParameters.forEach((key, value) {
      final numValue = num.tryParse(value);
      if (numValue != null && value.isNotEmpty) {
        query[key] = numValue;
      } else if (value == 'true') {
        query[key] = true;
      } else if (value == 'false') {
        query[key] = false;
      } else {
        query[key] = value;
      }
    });

    dynamic body;
    if (request.method != 'GET' && request.method != 'DELETE') {
      final content = await request.readAsString();
      if (content.isNotEmpty) {
        try {
          body = jsonDecode(content);
        } catch (_) {
          body = <String, dynamic>{};
        }
      }
    }

    final backend = LocalPluginBackend(
      storage.getUserDir(auth.userId),
      source: 'rest',
      onEvent: (event) {
        wsHub.broadcastFileUpdate(
          auth.userId,
          request.headers['x-device-id'],
          '${event.pluginId}/${event.filePattern}',
        );
      },
    );

    final result = await invoker.invoke(
      backend,
      request.method.toLowerCase(),
      '/api/v1/plugins/${request.url.path}',
      query: query,
      body: body,
    );

    if (result['success'] == true) {
      return _json(
        request.method == 'POST' ? 201 : 200,
        {
          'success': true,
          'data': result['data'],
          'timestamp': result['timestamp'],
        },
      );
    }
    return _json(errorCodeToStatus(result['code'] as String?), {
      'success': false,
      'error': result['error'],
      'code': result['code'],
      'timestamp': result['timestamp'],
    });
  };
}
