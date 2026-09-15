import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StorageBackendType { local, http }

/// jwt 保留用于兼容旧配置；HTTP 存储实际统一使用 API Key。
enum StorageAuthType { jwt, apiKey }

class StorageBackendConfig {
  const StorageBackendConfig({
    this.type = StorageBackendType.local,
    this.serverUrl = '',
    this.authType = StorageAuthType.apiKey,
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
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            // macOS 关闭 data protection keychain，避免 ad-hoc 签名下因缺少
            // keychain-access-groups entitlement 报 -34018
            mOptions: MacOsOptions(useDataProtectionKeyChain: false),
          );

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
    return StorageBackendConfig(
      type: typeName == StorageBackendType.http.name
          ? StorageBackendType.http : StorageBackendType.local,
      serverUrl: prefs.getString(_serverUrlKey) ?? '',
      // JWT 认证已移除；旧配置中的值统一按 API Key 处理。
      authType: StorageAuthType.apiKey,
      credential: await _readSecret(_credentialKey),
      encryptionKey: await _readSecret(_encryptionKey),
      userId: prefs.getString(_userIdKey) ?? '',
    );
  }

  /// 当前 keychain 读不到凭据时，尝试从旧的 data protection keychain
  /// （MacOsOptions 默认值）迁移一次，兼容切换 keychain 前保存的凭据
  Future<String> _readSecret(String key) async {
    final value = await _secureStorage.read(key: key);
    if (value != null && value.trim().isNotEmpty) return value;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return '';
    try {
      final legacy = await const FlutterSecureStorage().read(key: key);
      if (legacy == null || legacy.trim().isEmpty) return '';
      await _secureStorage.write(key: key, value: legacy);
      return legacy;
    } catch (_) {
      // 旧 keychain 可能因缺少 entitlement（-34018）不可读，视为无凭据
      return '';
    }
  }

  @override
  Future<void> save(StorageBackendConfig config) async {
    config.validate();
    // 先写凭据再持久化类型标记，避免凭据写入失败时留下
    // "已启用远端但凭据为空"的脏状态导致下次启动失败
    if (config.isHttpEnabled) {
      await _secureStorage.write(key: _credentialKey, value: config.credential.trim());
      await _secureStorage.write(key: _encryptionKey, value: config.encryptionKey.trim());
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, config.type.name);
    await prefs.setString(_serverUrlKey, config.serverUrl.trim());
    await prefs.setString(_authTypeKey, config.authType.name);
    await prefs.setString(_userIdKey, config.userId.trim());
    if (!config.isHttpEnabled) {
      await _secureStorage.delete(key: _credentialKey);
      await _secureStorage.delete(key: _encryptionKey);
    }
  }
}
