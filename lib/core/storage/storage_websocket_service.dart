import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/aboutme_data_service.dart';
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
      debugPrint(
        '[SyncDebug][WS] connecting uri=$uri device=${_shortId(deviceId)}',
      );
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      // 只有当前活跃连接意外结束才重连；主动 disconnect/被替换的旧连接
      // 触发的 onDone 不得再安排重连，否则会形成"断旧连接→onDone→定时
      // 重连→再断新连接"的自维持循环
      channel.stream.listen(
        _onMessage,
        onError: (_) {
          if (_channel == channel) _scheduleReconnect();
        },
        onDone: () {
          if (_channel == channel) _scheduleReconnect();
        },
      );
      await channel.ready;
      channel.sink.add(
        jsonEncode({
          'type': 'auth',
          'token': config.credential,
          'device_id': deviceId,
        }),
      );
      debugPrint('[SyncDebug][WS] auth sent device=${_shortId(deviceId)}');
    } catch (error) {
      debugPrint('[SyncDebug][WS] connect failed error=$error');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      if (type == 'auth_success') {
        AboutmeDataService.instance.revalidate();
        debugPrint(
          '[SyncDebug][WS] authenticated device=${_shortId(deviceId)}',
        );
        return;
      }
      if (type != 'file_updated') {
        debugPrint('[SyncDebug][WS] ignored message type=$type');
        return;
      }
      final data = message['data'] as Map<String, dynamic>?;
      final path = data?['file_path'] as String?;
      if (path == null || path.isEmpty) return;
      debugPrint(
        '[SyncDebug][WS] update received path=$path source=${_shortId(data?['source_device_id'] as String?)}',
      );
      // 转发进统一数据事件流（来源含 REST / MCP / 其它设备）
      final pluginId = path.contains('/') ? path.split('/').first : path;
      AboutmeDataService.instance.publishRemoteEvent(
        pluginId,
        path,
        metadata: data,
      );
      unawaited(RouteRefreshManager().onFileSynced(path));
    } catch (error) {
      debugPrint('[SyncDebug][WS] invalid message error=$error');
    }
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer?.isActive == true) return;
    debugPrint('[SyncDebug][WS] reconnect scheduled in=3s');
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectNow);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) debugPrint('[SyncDebug][WS] disconnecting');
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    _closed = true;
    await disconnect();
  }

  String _shortId(String? value) => value == null || value.isEmpty
      ? '-'
      : value.length <= 8
      ? value
      : value.substring(0, 8);
}
