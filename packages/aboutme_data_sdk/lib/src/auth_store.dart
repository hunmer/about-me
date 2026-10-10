import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'jwt_hs256.dart';
import 'pbkdf2.dart';

class DeviceInfo {
  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.createdAt,
    this.lastSyncAt,
    this.fcmToken,
    this.platform,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    deviceId: json['deviceId'] as String,
    deviceName: json['deviceName'] as String? ?? 'Unknown Device',
    createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    lastSyncAt: _parseDate(json['lastSyncAt']),
    fcmToken: json['fcmToken'] as String?,
    platform: json['platform'] as String?,
  );

  final String deviceId;
  String deviceName;
  final DateTime createdAt;
  DateTime? lastSyncAt;
  String? fcmToken;
  String? platform;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'createdAt': createdAt.toIso8601String(),
    if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
    if (fcmToken != null) 'fcmToken': fcmToken,
    if (platform != null) 'platform': platform,
  };
}

class UserInfo {
  UserInfo({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    this.isAdmin = false,
    List<DeviceInfo>? devices,
    this.lastLoginAt,
  }) : devices = devices ?? [];

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['id'] as String,
    username: json['username'] as String,
    passwordHash: json['passwordHash'] as String,
    salt: json['salt'] as String,
    createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    isAdmin: json['isAdmin'] as bool? ?? false,
    devices: (json['devices'] as List<dynamic>? ?? [])
        .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
    lastLoginAt: _parseDate(json['lastLoginAt']),
  );

  final String id;
  final String username;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;
  final bool isAdmin;
  final List<DeviceInfo> devices;
  DateTime? lastLoginAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'salt': salt,
    'createdAt': createdAt.toIso8601String(),
    'isAdmin': isAdmin,
    'devices': devices.map((d) => d.toJson()).toList(),
    if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
  };
}

class ApiKey {
  ApiKey({
    required this.id,
    required this.userId,
    required this.name,
    required this.key,
    required this.keyHash,
    required this.createdAt,
    this.expiresAt,
    this.isRevoked = false,
    this.lastUsedAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) => ApiKey(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    key: json['key'] as String,
    keyHash: json['keyHash'] as String,
    createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    expiresAt: _parseDate(json['expiresAt']),
    isRevoked: json['isRevoked'] as bool? ?? false,
    lastUsedAt: _parseDate(json['lastUsedAt']),
  );

  final String id;
  final String userId;
  final String name;
  final String key;
  final String keyHash;
  final DateTime createdAt;
  final DateTime? expiresAt;
  bool isRevoked;
  DateTime? lastUsedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'key': key,
    'keyHash': keyHash,
    'createdAt': createdAt.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    'isRevoked': isRevoked,
    if (lastUsedAt != null) 'lastUsedAt': lastUsedAt!.toIso8601String(),
  };
}

class AuthResult {
  const AuthResult({
    required this.success,
    this.userId,
    this.token,
    this.expiresAt,
    this.userSalt,
    this.error,
  });

  final bool success;
  final String? userId;
  final String? token;
  final DateTime? expiresAt;
  final String? userSalt;
  final String? error;
}

class ApiKeyValidation {
  const ApiKeyValidation({
    required this.userId,
    required this.keyId,
    required this.keyName,
  });

  final String userId;
  final String keyId;
  final String keyName;
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// 认证数据存储：users.json / api_keys/{userId}.json / api_access.json，
/// 文件格式与 nodejs 服务器完全兼容（同一 dataDir 可互换使用）。
class AuthStore {
  AuthStore({
    required this.dataDir,
    required this.jwtSecret,
    this.tokenExpiryDays = 36500,
    this.adminUsername,
    this.adminPassword,
  }) : _apiKeyDir = p.join(dataDir, 'auth', 'api_keys');

  final String dataDir;
  final String jwtSecret;
  final int tokenExpiryDays;
  final String? adminUsername;
  final String? adminPassword;
  final String _apiKeyDir;

  File get _usersFile => File(p.join(dataDir, 'auth', 'users.json'));

  File get _apiAccessFile => File(p.join(dataDir, 'auth', 'api_access.json'));

  Future<void> initialize() async {
    await Directory(_apiKeyDir).create(recursive: true);
    if (!await _usersFile.exists()) {
      await _usersFile.writeAsString('{"users":[]}');
    }
    await initializeAdmin();
  }

  /// 初始化管理员账号（已存在则跳过）
  Future<void> initializeAdmin() async {
    if (adminUsername == null || adminPassword == null) return;
    if (await findUserByUsername(adminUsername!) != null) return;

    final salt = PasswordHasher.generateSalt();
    await addUser(
      UserInfo(
        id: const Uuid().v4(),
        username: adminUsername!,
        passwordHash: PasswordHasher.hashPassword(adminPassword!, salt),
        salt: salt,
        createdAt: DateTime.now(),
        isAdmin: true,
      ),
    );
  }

  // ==================== 用户 ====================

  Future<List<UserInfo>> readAllUsers() async {
    if (!await _usersFile.exists()) return [];
    try {
      final data =
          jsonDecode(await _usersFile.readAsString()) as Map<String, dynamic>;
      return (data['users'] as List<dynamic>? ?? [])
          .map((e) => UserInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllUsers(List<UserInfo> users) async {
    await _usersFile.parent.create(recursive: true);
    await _usersFile.writeAsString(
      jsonEncode({
        'users': users.map((u) => u.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<UserInfo?> findUserByUsername(String username) async {
    final users = await readAllUsers();
    return users.where((u) => u.username == username).firstOrNull;
  }

  Future<UserInfo?> findUserById(String userId) async {
    final users = await readAllUsers();
    return users.where((u) => u.id == userId).firstOrNull;
  }

  Future<void> addUser(UserInfo user) async {
    final users = await readAllUsers();
    users.add(user);
    await saveAllUsers(users);
  }

  Future<void> updateUser(UserInfo updated) async {
    final users = await readAllUsers();
    final index = users.indexWhere((u) => u.id == updated.id);
    if (index >= 0) {
      users[index] = updated;
      await saveAllUsers(users);
    }
  }

  // ==================== 注册 / 登录 / Token ====================

  Future<AuthResult> register({
    required String username,
    required String password,
    required String deviceId,
    String? deviceName,
  }) async {
    if (await findUserByUsername(username) != null) {
      return const AuthResult(success: false, error: '用户名已存在');
    }
    final salt = PasswordHasher.generateSalt();
    final user = UserInfo(
      id: const Uuid().v4(),
      username: username,
      passwordHash: PasswordHasher.hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
      devices: [
        DeviceInfo(
          deviceId: deviceId,
          deviceName: deviceName ?? 'Unknown Device',
          createdAt: DateTime.now(),
        ),
      ],
    );
    await addUser(user);
    return _authSuccess(user);
  }

  Future<AuthResult> login({
    required String username,
    required String password,
    required String deviceId,
    String? deviceName,
  }) async {
    final user = await findUserByUsername(username);
    if (user == null ||
        !PasswordHasher.verifyPassword(password, user.salt, user.passwordHash)) {
      return const AuthResult(success: false, error: '用户名或密码错误');
    }

    if (deviceId != 'admin_panel') {
      final index = user.devices.indexWhere((d) => d.deviceId == deviceId);
      if (index >= 0) {
        final existing = user.devices[index];
        existing.deviceName =
            deviceName?.isNotEmpty == true ? deviceName! : existing.deviceName;
        existing.lastSyncAt = DateTime.now();
      } else {
        user.devices.add(
          DeviceInfo(
            deviceId: deviceId,
            deviceName: deviceName ?? 'Unknown Device',
            createdAt: DateTime.now(),
            lastSyncAt: DateTime.now(),
          ),
        );
      }
    }
    user.lastLoginAt = DateTime.now();
    await updateUser(user);
    return _authSuccess(user);
  }

  Future<AuthResult> refreshToken(String token) async {
    final payload = JwtHs256.verify(token, jwtSecret);
    final userId = payload?['sub'] as String?;
    if (payload == null || userId == null) {
      return const AuthResult(success: false, error: 'Token 无效或已过期');
    }
    final user = await findUserById(userId);
    if (user == null) {
      return const AuthResult(success: false, error: '用户不存在');
    }
    return _authSuccess(user);
  }

  AuthResult _authSuccess(UserInfo user) {
    final token = JwtHs256.sign(
      payload: {'sub': user.id},
      secret: jwtSecret,
      lifetime: Duration(days: tokenExpiryDays),
    );
    return AuthResult(
      success: true,
      userId: user.id,
      token: token,
      expiresAt: DateTime.now().add(Duration(days: tokenExpiryDays)),
      userSalt: user.salt,
    );
  }

  String? getUserIdFromToken(String token) {
    final payload = JwtHs256.verify(token, jwtSecret);
    return payload?['sub'] as String?;
  }

  // ==================== API Key ====================

  File _apiKeyFile(String userId) => File(p.join(_apiKeyDir, '$userId.json'));

  Future<List<ApiKey>> _readApiKeys(String userId) async {
    final file = _apiKeyFile(userId);
    if (!await file.exists()) return [];
    try {
      return (jsonDecode(await file.readAsString()) as List<dynamic>)
          .map((e) => ApiKey.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveApiKeys(String userId, List<ApiKey> keys) async {
    final file = _apiKeyFile(userId);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(keys.map((k) => k.toJson()).toList()),
    );
  }

  Future<ApiKey> generateApiKey({
    required String userId,
    required String name,
    required ApiKeyExpiry expiry,
  }) async {
    final user = await findUserById(userId);
    if (user == null) throw Exception('用户不存在');

    final random = Random.secure();
    final keyBytes = Uint8List(32);
    for (var i = 0; i < keyBytes.length; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    final key = 'mk_${_base64UrlNoPadding(keyBytes)}';
    final keyHash = sha256.convert(utf8.encode(key)).toString();

    final apiKey = ApiKey(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      key: key,
      keyHash: keyHash,
      createdAt: DateTime.now(),
      expiresAt: switch (expiry) {
        ApiKeyExpiry.days7 => DateTime.now().add(const Duration(days: 7)),
        ApiKeyExpiry.days30 => DateTime.now().add(const Duration(days: 30)),
        ApiKeyExpiry.days90 => DateTime.now().add(const Duration(days: 90)),
        ApiKeyExpiry.year1 => DateTime.now().add(const Duration(days: 365)),
        ApiKeyExpiry.never => null,
      },
    );
    final keys = await _readApiKeys(userId);
    keys.add(apiKey);
    await _saveApiKeys(userId, keys);
    return apiKey;
  }

  /// 验证 API Key（时序安全比较哈希），成功返回归属用户。
  Future<ApiKeyValidation?> verifyApiKey(String keyValue) async {
    if (!await Directory(_apiKeyDir).exists()) return null;

    final keyHash = sha256.convert(utf8.encode(keyValue)).toString();
    for (final entity in Directory(_apiKeyDir).listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final userId = p.basenameWithoutExtension(entity.path);
      final keys = await _readApiKeys(userId);
      for (final apiKey in keys) {
        // 比较哈希而非原文，天然等长时序安全
        if (_fixedTimeEqualsHex(apiKey.keyHash, keyHash)) {
          if (apiKey.isRevoked) return null;
          if (apiKey.expiresAt != null &&
              DateTime.now().isAfter(apiKey.expiresAt!)) {
            return null;
          }
          apiKey.lastUsedAt = DateTime.now();
          await _saveApiKeys(userId, keys);
          return ApiKeyValidation(
            userId: apiKey.userId,
            keyId: apiKey.id,
            keyName: apiKey.name,
          );
        }
      }
    }
    return null;
  }

  Future<List<ApiKey>> listApiKeys(String userId) => _readApiKeys(userId);

  Future<void> revokeApiKey(String userId, String keyId) async {
    final keys = await _readApiKeys(userId);
    final key = keys.where((k) => k.id == keyId).firstOrNull;
    if (key == null) throw Exception('API Key 不存在');
    if (key.userId != userId) throw Exception('无权操作此 API Key');
    key.isRevoked = true;
    await _saveApiKeys(userId, keys);
  }

  // ==================== 设备管理 ====================

  Future<List<DeviceInfo>> getDevices(String userId) async {
    final user = await findUserById(userId);
    if (user == null) throw Exception('用户不存在');
    return user.devices;
  }

  Future<DeviceInfo> registerDevice({
    required String userId,
    required String deviceId,
    String? deviceName,
    String? fcmToken,
    String? platform,
  }) async {
    final user = await findUserById(userId);
    if (user == null) throw Exception('用户不存在');

    final now = DateTime.now();
    final index = user.devices.indexWhere((d) => d.deviceId == deviceId);
    DeviceInfo device;
    if (index >= 0) {
      device = user.devices[index];
      if (deviceName?.isNotEmpty == true) device.deviceName = deviceName!;
      device.lastSyncAt = now;
      if (fcmToken != null) device.fcmToken = fcmToken;
      if (platform != null) device.platform = platform;
    } else {
      device = DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName ?? 'Unknown Device',
        createdAt: now,
        lastSyncAt: now,
        fcmToken: fcmToken,
        platform: platform,
      );
      user.devices.add(device);
    }
    await updateUser(user);
    return device;
  }

  Future<void> deleteDevice(String userId, String deviceId) async {
    final user = await findUserById(userId);
    if (user == null) throw Exception('用户不存在');
    final initialLength = user.devices.length;
    user.devices.removeWhere((d) => d.deviceId == deviceId);
    if (user.devices.length == initialLength) throw Exception('设备不存在');
    await updateUser(user);
  }

  List<String> getDeviceFcmTokens(UserInfo user, String? deviceId) => (deviceId ==
          null
      ? user.devices
      : user.devices.where((d) => d.deviceId == deviceId))
      .where((d) => d.fcmToken != null && d.fcmToken!.isNotEmpty)
      .map((d) => d.fcmToken!)
      .toList();

  // ==================== API 访问控制 ====================

  Future<bool> getApiAccessStatus(String userId) async {
    if (!await _apiAccessFile.exists()) return false;
    try {
      final status =
          jsonDecode(await _apiAccessFile.readAsString())
              as Map<String, dynamic>;
      return status[userId] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setApiAccessStatus(String userId, bool enabled) async {
    Map<String, dynamic> status = {};
    if (await _apiAccessFile.exists()) {
      try {
        status =
            jsonDecode(await _apiAccessFile.readAsString())
                as Map<String, dynamic>;
      } catch (_) {}
    }
    status[userId] = enabled;
    await _apiAccessFile.parent.create(recursive: true);
    await _apiAccessFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(status),
    );
  }
}

enum ApiKeyExpiry { days7, days30, days90, year1, never }

ApiKeyExpiry parseApiKeyExpiry(String value) => switch (value) {
  '7days' => ApiKeyExpiry.days7,
  '30days' => ApiKeyExpiry.days30,
  '90days' => ApiKeyExpiry.days90,
  '1year' => ApiKeyExpiry.year1,
  _ => ApiKeyExpiry.never,
};

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

bool _fixedTimeEqualsHex(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
