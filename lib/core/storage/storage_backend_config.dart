import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StorageBackendType { local, http }

enum StorageAuthType { jwt, apiKey }

class StorageBackendConfig {
  const StorageBackendConfig({
    this.type = StorageBackendType.local,
    this.serverUrl = '',
    this.authType = StorageAuthType.jwt,
    this.credential = '',
    this.encryptionKey = '',
    this.userId = '',
  });

  final StorageBackendType type;
  final String serverUrl;
  final StorageAuthType authType;
  final String credential;
  final String encryptionKey;
  final String userId;

  bool get isHttpEnabled => type == StorageBackendType.http;

  void validate() {
    if (!isHttpEnabled) return;
    final uri = Uri.tryParse(serverUrl);
    final isLocal = uri?.host == 'localhost' || uri?.host == '127.0.0.1';
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'https' && !(isLocal && uri.scheme == 'http'))) {
      throw const FormatException('服务器地址必须使用 HTTPS（本机地址允许 HTTP）');
    }
    if (credential.trim().isEmpty) throw const FormatException('认证凭据不能为空');
    if (encryptionKey.trim().isEmpty) throw const FormatException('加密密钥不能为空');
  }
}

abstract class StorageBackendConfigStore {
  Future<StorageBackendConfig> load();
  Future<void> save(StorageBackendConfig config);
}

class LocalStorageBackendConfigStore implements StorageBackendConfigStore {
  LocalStorageBackendConfigStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _typeKey = 'storage_backend_type';
  static const _serverUrlKey = 'storage_backend_server_url';
  static const _authTypeKey = 'storage_backend_auth_type';
  static const _userIdKey = 'storage_backend_user_id';
  static const _credentialKey = 'storage_backend_credential';
  static const _encryptionKey = 'storage_backend_encryption_key';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<StorageBackendConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString(_typeKey);
    final authName = prefs.getString(_authTypeKey);
    return StorageBackendConfig(
      type: typeName == StorageBackendType.http.name
          ? StorageBackendType.http : StorageBackendType.local,
      serverUrl: prefs.getString(_serverUrlKey) ?? '',
      authType: authName == StorageAuthType.apiKey.name
          ? StorageAuthType.apiKey : StorageAuthType.jwt,
      credential: await _secureStorage.read(key: _credentialKey) ?? '',
      encryptionKey: await _secureStorage.read(key: _encryptionKey) ?? '',
      userId: prefs.getString(_userIdKey) ?? '',
    );
  }

  @override
  Future<void> save(StorageBackendConfig config) async {
    config.validate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, config.type.name);
    await prefs.setString(_serverUrlKey, config.serverUrl.trim());
    await prefs.setString(_authTypeKey, config.authType.name);
    await prefs.setString(_userIdKey, config.userId.trim());
    if (config.isHttpEnabled) {
      await _secureStorage.write(key: _credentialKey, value: config.credential.trim());
      await _secureStorage.write(key: _encryptionKey, value: config.encryptionKey.trim());
    } else {
      await _secureStorage.delete(key: _credentialKey);
      await _secureStorage.delete(key: _encryptionKey);
    }
  }
}
