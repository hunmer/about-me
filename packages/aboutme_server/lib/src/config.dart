import 'dart:io';

/// 服务器配置：环境变量与 nodejs server 保持同名同默认值，可无缝迁移。
class ServerConfig {
  ServerConfig({
    required this.port,
    required this.dataDir,
    required this.jwtSecret,
    required this.tokenExpiryDays,
    required this.enableCors,
    required this.corsOrigins,
    required this.maxStorageFileSizeBytes,
    required this.storageRateLimitPerMinute,
    required this.enableLogging,
    required this.adminUsername,
    required this.adminPassword,
    required this.allowRegister,
    this.adminDirOverride,
    this.fcmServiceAccount,
  });

  static const _devSecret = 'aboutme-dev-fixed-secret-key-do-not-use-in-production';

  factory ServerConfig.fromEnvironment() {
    final jwtSecret = Platform.environment['JWT_SECRET'] ?? '';
    if (jwtSecret.isEmpty) {
      stderr.writeln(
        '警告: 未设置 JWT_SECRET 环境变量，使用固定默认密钥（仅限开发环境）',
      );
    }
    return ServerConfig(
      port: int.tryParse(Platform.environment['PORT'] ?? '') ?? 8874,
      dataDir: Platform.environment['DATA_DIR'] ??
          Directory.current.path + '/data',
      jwtSecret: jwtSecret.isEmpty ? _devSecret : jwtSecret,
      tokenExpiryDays:
          int.tryParse(Platform.environment['TOKEN_EXPIRY_DAYS'] ?? '') ??
          36500,
      enableCors:
          (Platform.environment['ENABLE_CORS'] ?? '').toLowerCase() !=
          'false',
      corsOrigins: (Platform.environment['CORS_ORIGINS'] ?? '*').split(','),
      maxStorageFileSizeBytes:
          int.tryParse(
            Platform.environment['MAX_STORAGE_FILE_SIZE_BYTES'] ?? '',
          ) ??
          10 * 1024 * 1024,
      storageRateLimitPerMinute:
          int.tryParse(
            Platform.environment['STORAGE_RATE_LIMIT_PER_MINUTE'] ?? '',
          ) ??
          1200,
      enableLogging:
          (Platform.environment['ENABLE_LOGGING'] ?? '').toLowerCase() !=
          'false',
      adminUsername: Platform.environment['ADMIN_USERNAME'] ?? 'admin',
      adminPassword: Platform.environment['ADMIN_PASSWORD'] ?? 'admin123',
      allowRegister:
          (Platform.environment['ALLOW_REGISTER'] ?? '').toLowerCase() !=
          'false',
      adminDirOverride: Platform.environment['ADMIN_DIR'],
      fcmServiceAccount: Platform.environment['FCM_SERVICE_ACCOUNT'],
    );
  }

  final int port;
  final String dataDir;
  final String jwtSecret;
  final int tokenExpiryDays;
  final bool enableCors;
  final List<String> corsOrigins;
  final int maxStorageFileSizeBytes;
  final int storageRateLimitPerMinute;
  final bool enableLogging;
  final String adminUsername;
  final String adminPassword;
  final bool allowRegister;

  /// 管理界面静态资源目录（缺省自动探测）
  final String? adminDirOverride;

  /// FCM service-account.json 路径（缺省 DATA_DIR/当前目录）
  final String? fcmServiceAccount;

  bool get corsAllowAll => corsOrigins.length == 1 && corsOrigins.first == '*';
}
