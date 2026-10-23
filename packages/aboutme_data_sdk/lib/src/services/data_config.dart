import 'persistent_plugin_backend.dart';

enum DataMode { local, http }

enum DataConnection { unverified, ready, offline, unauthorized, unsupported }

class DataSession {
  const DataSession({
    required this.mode,
    required this.connection,
    this.userId,
    this.capabilities = const {},
  });
  final DataMode mode;
  final DataConnection connection;
  final String? userId;
  final Map<String, dynamic> capabilities;
}

class DataConfig {
  const DataConfig.local({required PluginPersistence storage})
    : persistence = storage,
      serverUrl = null,
      credentialProvider = null;
  const DataConfig.http({
    required this.serverUrl,
    required this.credentialProvider,
  }) : persistence = null;
  final PluginPersistence? persistence;
  final String? serverUrl;
  final Future<String> Function()? credentialProvider;
}
