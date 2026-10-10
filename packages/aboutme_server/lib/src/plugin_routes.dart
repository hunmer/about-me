import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'auth_middleware.dart';
import 'plugins/invoker.dart';
import 'plugins/utils.dart';

/// 插件 REST 路由：`/api/v1/plugins/{pluginId}/*`
/// 认证 + X-Encryption-Key；写操作后的同步广播由 invoker.onMutation 统一处理。
class PluginApi {
  PluginApi({required this.invoker});

  final PluginInvoker invoker;

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

  Handler get handler {
    return (request) async {
      final auth = authContextOf(request);
      if (auth == null) return _error(401, '未认证');

      final encryptionKey = request.headers['x-encryption-key'];
      if (encryptionKey == null || encryptionKey.isEmpty) {
        return _error(403, '请通过 X-Encryption-Key 请求头传递加密密钥');
      }

      // query 参数宽松类型转换（数字/布尔），与 nodejs factory 一致
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

      final result = await invoker.invoke(
        auth.userId,
        encryptionKey,
        request.method.toLowerCase(),
        '/api/v1/plugins/${request.url.path}',
        query: query,
        body: body,
        sourceDeviceId: request.headers['x-device-id'],
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
}
