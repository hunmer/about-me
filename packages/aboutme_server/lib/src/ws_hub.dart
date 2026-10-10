import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_middleware.dart';
import 'plugins/utils.dart' show jsIsoDateTime;

class _WsClient {
  _WsClient({
    required this.channel,
    required this.userId,
    required this.deviceId,
  });

  final WebSocketChannel channel;
  final String userId;
  final String deviceId;
}

/// 存储实时同步 WebSocket 集线器：
/// 客户端连接 `/api/v1/storage/ws` 后发送 `{type:'auth', token, device_id}`，
/// 验证通过回 `{type:'auth_success', user_id}`；
/// 文件变更时向同用户其它设备广播 `{type:'file_updated', data:{file_path, ...}}`。
/// 消息协议与 nodejs 服务器完全一致。
class StorageWsHub {
  StorageWsHub({required this.verifyToken});

  /// 返回 null 表示认证失败（与 auth 中间件共用 API Key 验证）。
  final Future<AuthContext?> Function(String token) verifyToken;

  final _clients = <_WsClient>[];

  Handler get handler => webSocketHandler((channel, request) {
    unawaited(_handleConnection(channel));
  });

  Future<void> _handleConnection(WebSocketChannel channel) async {
    // WebSocketChannel.stream 是单订阅流：转广播后只监听一次，
    // 认证后保持订阅存活（后续消息无业务语义），连接关闭由 onDone 清理
    final messages = channel.stream.asBroadcastStream();
    final authCompleter =
        Completer<({AuthContext auth, String deviceId})?>();

    final authSub = messages.listen(
      (raw) {
        if (authCompleter.isCompleted) return;
        try {
          final message =
              jsonDecode(raw as String) as Map<String, dynamic>;
          final token = message['token'] as String?;
          final deviceId = message['device_id'] as String? ?? '';
          if (message['type'] == 'auth' &&
              token != null &&
              token.isNotEmpty &&
              deviceId.isNotEmpty) {
            verifyToken(token).then((auth) {
              if (authCompleter.isCompleted) return;
              authCompleter.complete(
                auth == null ? null : (auth: auth, deviceId: deviceId),
              );
            });
          } else {
            authCompleter.complete(null);
          }
        } catch (_) {
          if (!authCompleter.isCompleted) authCompleter.complete(null);
        }
      },
      onDone: () {
        if (!authCompleter.isCompleted) authCompleter.complete(null);
      },
      onError: (_) {
        if (!authCompleter.isCompleted) authCompleter.complete(null);
      },
    );

    final result = await authCompleter.future
        .timeout(const Duration(seconds: 10), onTimeout: () => null);

    if (result == null) {
      await authSub.cancel();
      await channel.sink.close().catchError((_) {});
      return;
    }

    final client = _WsClient(
      channel: channel,
      userId: result.auth.userId,
      deviceId: result.deviceId,
    );
    _clients.add(client);
    _log('connected user=${_short(client.userId)} '
        'device=${_short(client.deviceId)} clients=${_clients.length}');
    channel.sink.add(
      jsonEncode({'type': 'auth_success', 'user_id': client.userId}),
    );

    // 连接断开时移除客户端
    messages.listen(
      (_) {},
      onDone: () => _removeClient(client, 'closed'),
      onError: (_) => _removeClient(client, 'error'),
    );
  }

  void _removeClient(_WsClient client, String reason) {
    if (_clients.remove(client)) {
      _log('disconnected user=${_short(client.userId)} '
          'device=${_short(client.deviceId)} reason=$reason '
          'clients=${_clients.length}');
    }
  }

  /// 广播文件变更给同用户的其它设备（排除来源设备）。
  void broadcastFileUpdate(
    String userId,
    String? sourceDeviceId,
    String filePath,
  ) {
    final message = jsonEncode({
      'type': 'file_updated',
      'data': {
        'file_path': filePath,
        'modified_at': jsIsoDateTime(DateTime.now()),
        'source_device_id': sourceDeviceId ?? '',
      },
    });
    var recipients = 0;
    for (final client in _clients.toList()) {
      if (client.userId == userId && client.deviceId != sourceDeviceId) {
        try {
          client.channel.sink.add(message);
          recipients++;
        } catch (_) {
          _removeClient(client, 'send-failed');
        }
      }
    }
    _log('broadcast user=${_short(userId)} source=${_short(sourceDeviceId)} '
        'path=$filePath recipients=$recipients');
  }

  void _log(String message) => print('[SyncDebug][WS] $message');

  String _short(String? value) =>
      value == null || value.isEmpty
          ? '-'
          : value.length <= 8
          ? value
          : value.substring(0, 8);
}
