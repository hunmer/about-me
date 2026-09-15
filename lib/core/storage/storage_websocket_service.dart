import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../route/route_refresh_manager.dart';
import 'device_identity.dart';
import 'storage_backend_config.dart';

class StorageWebSocketService {
  StorageWebSocketService._();
  static final instance = StorageWebSocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String get deviceId => DeviceIdentity.id;
  StorageBackendConfig? _config;
  bool _closed = false;

  Future<void> connect(StorageBackendConfig config) async {
    _config = config;
    _closed = false;
    await _connectNow();
  }

  Future<void> _connectNow() async {
    final config = _config;
    if (_closed || config == null || !config.isHttpEnabled) return;
    await disconnect();
    try {
      final base = Uri.parse(config.serverUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/api/v1/storage/ws',
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
      await channel.ready;
      channel.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': config.credential,
          'device_id': deviceId,
        }),
      );
    } catch (error) {
      debugPrint('[StorageWS] connect failed: $error');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['type'] != 'file_updated') return;
      final data = message['data'] as Map<String, dynamic>?;
      final path = data?['file_path'] as String?;
      if (path == null || path.isEmpty) return;
      unawaited(RouteRefreshManager().onFileSynced(path));
    } catch (error) {
      debugPrint('[StorageWS] invalid message: $error');
    }
  }

  void _scheduleReconnect([Object? _]) {
    if (_closed || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectNow);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    _closed = true;
    await disconnect();
  }
}
