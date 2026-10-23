import 'package:aboutme_data_sdk/io.dart';

import 'ws_hub.dart';

/// 每个服务器实例按认证用户持有 runtime；REST/MCP 共用相同持久化与事件出口。
class UserDataRuntimes {
  UserDataRuntimes({required this.storage, required this.wsHub});

  final LocalFileStorage storage;
  final StorageWsHub wsHub;
  final _users = <String, LocalPluginBackend>{};

  LocalPluginBackend forUser(String authenticatedUserId) => _users.putIfAbsent(
    authenticatedUserId,
    () => LocalPluginBackend(
      storage.getUserDir(authenticatedUserId),
      source: 'server',
      onEvent: (event) => wsHub.broadcastFileUpdate(
        authenticatedUserId,
        event.sourceDeviceId,
        '${event.pluginId}/${event.filePattern}',
        change: event,
      ),
    ),
  );
}
