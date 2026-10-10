import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../auth_middleware.dart';
import '../plugins/invoker.dart';
import 'tools.dart';

/// MCP (Model Context Protocol) HTTP 端点，Streamable HTTP 无状态模式：
/// - POST   /mcp  - JSON-RPC 请求（initialize / tools/list / tools/call / ping）
/// - GET    /mcp  - 405（无状态模式不支持推送流）
/// - DELETE /mcp  - 405（无状态模式无会话）
///
/// 认证复用主服务器（X-API-Key 或 Bearer），并要求 X-Encryption-Key。
class McpApi {
  McpApi({required this.invoker});

  final PluginInvoker invoker;

  static const _serverInfo = {
    'name': '@hunmer/aboutme-server',
    'version': '1.0.3',
  };

  Response _jsonRpcError(int httpStatus, String message) => Response(
    httpStatus,
    body: jsonEncode({
      'jsonrpc': '2.0',
      'error': {'code': -32600, 'message': message},
      'id': null,
    }),
    headers: {'content-type': 'application/json'},
  );

  Handler get handler => (request) async {
    if (request.method == 'GET') {
      return _jsonRpcError(405, '无状态 MCP 服务器不支持 GET');
    }
    if (request.method == 'DELETE') {
      return _jsonRpcError(405, '无状态 MCP 服务器不支持 DELETE');
    }
    if (request.method != 'POST') {
      return _jsonRpcError(405, '不支持的请求方法');
    }

    final auth = authContextOf(request);
    if (auth == null) return _jsonRpcError(401, '未认证');
    final encryptionKey = request.headers['x-encryption-key'];
    if (encryptionKey == null || encryptionKey.isEmpty) {
      return Response(
        403,
        body: jsonEncode({
          'success': false,
          'error': '请通过 X-Encryption-Key 请求头传递加密密钥',
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    dynamic payload;
    try {
      payload = jsonDecode(await request.readAsString());
    } catch (_) {
      return _jsonRpcError(400, '无效的 JSON 请求体');
    }

    final isBatch = payload is List;
    final messages =
        isBatch ? payload.cast<Map<String, dynamic>>() : [payload];

    final responses = <Map<String, dynamic>>[];
    for (final message in messages) {
      final response = await _handleMessage(
        message,
        userId: auth.userId,
        encryptionKey: encryptionKey,
      );
      if (response != null) responses.add(response);
    }

    if (responses.isEmpty) {
      // 全为通知：接受但不返回内容
      return Response(202);
    }
    final body = jsonEncode(isBatch ? responses : responses.first);
    return Response.ok(
      body,
      headers: {'content-type': 'application/json'},
    );
  };

  Future<Map<String, dynamic>?> _handleMessage(
    Map<String, dynamic> message, {
    required String userId,
    required String encryptionKey,
  }) async {
    final method = message['method'] as String?;
    final id = message['id'];
    final params =
        message['params'] is Map
            ? message['params'] as Map<String, dynamic>
            : <String, dynamic>{};

    if (method == null || method.isEmpty) {
      return _error(id, -32600, '无效请求');
    }

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            // 回显客户端协议版本（兼容旧客户端），缺省用 2025-03-26
            'protocolVersion':
                params['protocolVersion']?.toString().isNotEmpty == true
                ? params['protocolVersion']
                : '2025-03-26',
            'capabilities': {
              'tools': {},
            },
            'serverInfo': _serverInfo,
          },
        };
      case 'ping':
        return {'jsonrpc': '2.0', 'id': id, 'result': {}};
      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {'tools': toolDefinitions},
        };
      case 'tools/call':
        final toolName = params['name'] as String?;
        final arguments = params['arguments'] is Map
            ? params['arguments'] as Map<String, dynamic>
            : <String, dynamic>{};
        if (toolName == null) return _error(id, -32602, '缺少工具名称');

        final (text, isError) = await dispatchTool(
          invoker,
          userId,
          encryptionKey,
          toolName,
          arguments,
        );
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'content': [
              {'type': 'text', 'text': text},
            ],
            if (isError) 'isError': true,
          },
        };
      default:
        // 通知（无 id）不回应；请求类未知方法返回 -32601
        if (id == null) return null;
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  Map<String, dynamic> _error(dynamic id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };
}
