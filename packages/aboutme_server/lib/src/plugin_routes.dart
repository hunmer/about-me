import 'dart:convert';

import 'package:aboutme_data_sdk/io.dart';
import 'package:shelf/shelf.dart';

import 'auth_middleware.dart';
import 'ws_hub.dart';
import 'user_data_runtimes.dart';
import 'business_request_body.dart';

/// 插件 REST 路由：`/api/v1/plugins/{pluginId}/*`（认证即可，数据明文）。
/// 按认证用户复用 SDK runtime，业务逻辑全部来自 SDK；
/// 写操作经后端事件回调广播 WS 同步。
class PluginApi {
  PluginApi({required this.storage, required this.wsHub, UserDataRuntimes? runtimes})
      : runtimes = runtimes ?? UserDataRuntimes(storage: storage, wsHub: wsHub);

  final LocalFileStorage storage;
  final StorageWsHub wsHub;
  final UserDataRuntimes runtimes;
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
    if (request.method == 'GET' && request.url.path == 'capabilities') {
      return _json(200, dataCapabilities());
    }

    final query = <String, dynamic>{};
    try {
      request.url.queryParameters.forEach((key, value) {
        if (request.headers['x-aboutme-query-encoding'] == 'json-v1') {
          query[key] = jsonDecode(value);
        } else if (integerActionParams.contains(key)) {
          query[key] = int.parse(value);
        } else if (booleanActionParams.contains(key)) {
          if (value != 'true' && value != 'false')
            throw const FormatException();
          query[key] = value == 'true';
        } else {
          query[key] = value;
        }
      });
    } on FormatException {
      return _error(400, '查询参数格式错误');
    }

    dynamic body;
    if (request.method != 'GET') {
      try {
        body = await readBusinessRequestBody(request, allowEmpty: true);
      } on BusinessBodyTooLarge {
        return _json(413, {'success': false, 'code': 'INVALID_PARAMS',
          'error': '业务请求体上限 24 MiB'});
      } on FormatException {
        return _error(400, '请求体必须为有效 UTF-8 JSON');
      }
    }

    final backend = runtimes.forUser(auth.userId);

    final result = await backend.withRequestContext(() => invoker.invoke(
      backend,
      request.method.toLowerCase(),
      '/api/v1/plugins/${request.url.path}',
      query: query,
      body: body,
    ), source: 'rest', sourceDeviceId: request.headers['x-device-id']);

    if (result['success'] == true) {
      return _json(request.method == 'POST' ? 201 : 200, result);
    }
    return _json(errorCodeToStatus(result['code'] as String?), {
      'success': false,
      'error': result['error'],
      'code': result['code'],
      if (result.containsKey('version')) 'version': result['version'],
      'timestamp': result['timestamp'],
    });
  };
}
