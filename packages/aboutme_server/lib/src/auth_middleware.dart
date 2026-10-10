import 'dart:convert';

import 'package:aboutme_data_sdk/io.dart';
import 'package:shelf/shelf.dart';

import 'plugins/utils.dart' show jsIsoDateTime;

class AuthContext {
  const AuthContext({
    required this.userId,
    this.keyId,
    this.keyName,
    this.isApiKey = false,
  });

  final String userId;
  final String? keyId;
  final String? keyName;
  final bool isApiKey;
}

// 通过 request header 传递认证上下文（前缀保证不被外部伪造覆盖）
const _ctxUserId = 'x-aboutme-ctx-user-id';
const _ctxIsApiKey = 'x-aboutme-ctx-is-api-key';
const _ctxKeyId = 'x-aboutme-ctx-key-id';

/// 认证中间件：支持 `X-API-Key` 与 `Authorization: Bearer <jwt>`，
/// 语义与 nodejs authMiddleware 一致。
Middleware authMiddleware(AuthStore auth) {
  return (innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return innerHandler(request);
      }

      // 清除外部伪造的上下文头
      final cleaned = request.change(
        headers: {
          _ctxUserId: null,
          _ctxIsApiKey: null,
          _ctxKeyId: null,
        },
      );

      final apiKey = request.headers['x-api-key'];
      if (apiKey != null && apiKey.isNotEmpty) {
        final result = await auth.verifyApiKey(apiKey);
        if (result == null) {
          return _unauthorized('API Key 无效或已过期');
        }
        return innerHandler(
          cleaned.change(headers: {
            _ctxUserId: result.userId,
            _ctxIsApiKey: 'true',
            _ctxKeyId: result.keyId,
          }),
        );
      }

      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _unauthorized('缺少认证信息');
      }
      final token = authHeader.substring(7);
      final userId = auth.getUserIdFromToken(token);
      if (userId == null) {
        return _unauthorized('Token 无效或已过期');
      }
      return innerHandler(
        cleaned.change(headers: {_ctxUserId: userId, _ctxIsApiKey: 'false'}),
      );
    };
  };
}

Response _unauthorized(String message) => Response(
  401,
  body: jsonEncode({
    'success': false,
    'error': message,
    'timestamp': jsIsoDateTime(DateTime.now()),
  }),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 从请求读取认证上下文；未认证返回 null。
AuthContext? authContextOf(Request request) {
  final userId = request.headers[_ctxUserId];
  if (userId == null || userId.isEmpty) return null;
  return AuthContext(
    userId: userId,
    isApiKey: request.headers[_ctxIsApiKey] == 'true',
    keyId: request.headers[_ctxKeyId],
  );
}
