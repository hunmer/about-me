enum StorageBackendType { local, http }

/// jwt 保留用于兼容旧配置；HTTP 存储实际统一使用 API Key。
enum StorageAuthType { jwt, apiKey }

class StorageBackendConfig {
  const StorageBackendConfig({
    this.type = StorageBackendType.local,
    this.serverUrl = '',
    this.authType = StorageAuthType.apiKey,
    this.credential = '',
    this.userId = '',
  });

  final StorageBackendType type;
  final String serverUrl;
  final StorageAuthType authType;
  final String credential;
  final String userId;

  bool get isHttpEnabled => type == StorageBackendType.http;

  void validate() {
    if (!isHttpEnabled) return;
    final uri = Uri.tryParse(serverUrl);
    final isLocal = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && !(isLocal && uri.scheme == 'http'))) {
      throw const FormatException('服务器地址必须使用 HTTPS（本机地址允许 HTTP）');
    }
    if (credential.trim().isEmpty) throw const FormatException('认证凭据不能为空');
  }
}

/// 后端配置存取抽象；宿主应用用 secure storage / preferences 实现。
abstract class StorageBackendConfigStore {
  Future<StorageBackendConfig> load();
  Future<void> save(StorageBackendConfig config);
}
