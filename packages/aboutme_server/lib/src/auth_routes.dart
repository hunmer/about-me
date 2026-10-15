import 'dart:convert';

import 'package:aboutme_data_sdk/io.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'fcm_service.dart';

/// 认证路由：`/api/v1/auth/*`，响应结构与 nodejs authRoutes 对齐。
class AuthApi {
  AuthApi({
    required this.auth,
    required this.storage,
    required this.allowRegister,
    this.fcm,
  });

  final AuthStore auth;
  final LocalFileStorage storage;
  final bool allowRegister;
  final FcmService? fcm;

  Router get router {
    final router = Router(notFoundHandler: _notFound);
    router.get('/register-status', _registerStatus);
    router.post('/register', _register);
    router.post('/login', _login);
    router.post('/refresh', _refresh);
    router.post('/api-keys', _createApiKey);
    router.get('/api-keys', _listApiKeys);
    router.delete('/api-keys/<keyId>', _revokeApiKey);
    router.get('/user-info', _userInfo);
    router.get('/devices', _listDevices);
    router.post('/devices', _registerDevice);
    router.delete('/devices/<deviceId>', _deleteDevice);
    router.post('/devices/push', _pushUnsupported);
    router.get('/api-access', _getApiAccess);
    router.put('/api-access', _setApiAccess);
    return router;
  }

  Response _notFound(Request request) => Response(
    404,
    body: jsonEncode({'error': 'not_found'}),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _error(int status, String message) => Response(
    status,
    body: jsonEncode({
      'success': false,
      'error': message,
      'timestamp': jsIsoDateTime(DateTime.now()),
    }),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _ok(Map<String, dynamic> body) => Response.ok(
    jsonEncode({
      'success': true,
      ...body,
      'timestamp': jsIsoDateTime(DateTime.now()),
    }),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  String? _userIdFromBearer(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return auth.getUserIdFromToken(header.substring(7));
  }

  Future<Map<String, dynamic>> _readJsonBody(Request request) async {
    try {
      return jsonDecode(await request.readAsString())
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<Response> _registerStatus(Request request) async => _ok({
    'allow_register': allowRegister,
  });

  Future<Response> _register(Request request) async {
    if (!allowRegister) return _error(403, '注册功能已关闭');
    final data = await _readJsonBody(request);
    final username = data['username'] as String?;
    final password = data['password'] as String?;
    final deviceId = data['device_id'] as String?;
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _error(400, '用户名和密码不能为空');
    }
    if (username.length < 3) return _error(400, '用户名至少需要 3 个字符');
    if (password.length < 6) return _error(400, '密码至少需要 6 个字符');
    if (deviceId == null || deviceId.isEmpty) return _error(400, '设备 ID 不能为空');

    try {
      final result = await auth.register(
        username: username,
        password: password,
        deviceId: deviceId,
        deviceName: data['device_name'] as String?,
      );
      if (!result.success) return _error(400, result.error ?? '注册失败');
      return _ok({
        'user_id': result.userId,
        'token': result.token,
        'expires_at': jsIsoDateTime(result.expiresAt!),
        'user_salt': result.userSalt,
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _login(Request request) async {
    final data = await _readJsonBody(request);
    final username = data['username'] as String?;
    final password = data['password'] as String?;
    final deviceId = data['device_id'] as String?;
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return _error(400, '用户名和密码不能为空');
    }
    if (deviceId == null || deviceId.isEmpty) return _error(400, '设备 ID 不能为空');

    try {
      final result = await auth.login(
        username: username,
        password: password,
        deviceId: deviceId,
        deviceName: data['device_name'] as String?,
      );
      if (!result.success) return _error(401, result.error ?? '登录失败');
      return _ok({
        'user_id': result.userId,
        'token': result.token,
        'expires_at': jsIsoDateTime(result.expiresAt!),
        'user_salt': result.userSalt,
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _refresh(Request request) async {
    final data = await _readJsonBody(request);
    final token = data['token'] as String?;
    final deviceId = data['device_id'] as String?;
    if (token == null ||
        token.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      return _error(400, 'Token 和设备 ID 不能为空');
    }
    final result = await auth.refreshToken(token);
    if (!result.success) return _error(401, result.error ?? '刷新失败');
    return _ok({
      'user_id': result.userId,
      'token': result.token,
      'expires_at': jsIsoDateTime(result.expiresAt!),
      'user_salt': result.userSalt,
    });
  }

  Future<Response> _createApiKey(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final data = await _readJsonBody(request);
    final name = data['name'] as String?;
    if (name == null || name.isEmpty) return _error(400, 'API Key 名称不能为空');

    try {
      final apiKey = await auth.generateApiKey(
        userId: userId,
        name: name,
        expiry: parseApiKeyExpiry(data['expiry'] as String? ?? 'never'),
      );
      return _ok({
        'api_key': {
          'id': apiKey.id,
          'name': apiKey.name,
          'key': apiKey.key,
          'createdAt': jsIsoDateTime(apiKey.createdAt),
          'expiresAt': apiKey.expiresAt == null
              ? null
              : jsIsoDateTime(apiKey.expiresAt!),
        },
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _listApiKeys(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final keys = await auth.listApiKeys(userId);
    return _ok({
      'api_keys': keys
          .map(
            (k) => {
              'id': k.id,
              'name': k.name,
              'createdAt': jsIsoDateTime(k.createdAt),
              'lastUsedAt': k.lastUsedAt == null
                  ? null
                  : jsIsoDateTime(k.lastUsedAt!),
              'expiresAt': k.expiresAt == null
                  ? null
                  : jsIsoDateTime(k.expiresAt!),
              'isRevoked': k.isRevoked,
              'isExpired': k.expiresAt != null &&
                  DateTime.now().isAfter(k.expiresAt!),
            },
          )
          .toList(),
      'count': keys.length,
    });
  }

  Future<Response> _revokeApiKey(Request request, String keyId) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    try {
      await auth.revokeApiKey(userId, keyId);
      return _ok({'message': 'API Key 已撤销', 'key_id': keyId});
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _userInfo(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    try {
      final user = await auth.findUserById(userId);
      if (user == null) return _error(404, '用户不存在');
      final stats = await storage.userStorageStats(userId);
      return _ok({
        'user_info': {
          'username': user.username,
          'created_at': jsIsoDateTime(user.createdAt),
          'sync_folder_count': stats.folderCount,
          'sync_file_count': stats.fileCount,
          'sync_total_size': stats.totalSize,
          'sync_total_size_mb':
              (stats.totalSize / 1024 / 1024).toStringAsFixed(2),
        },
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _listDevices(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    try {
      final devices = await auth.getDevices(userId);
      return _ok({
        'devices': devices
            .map(
              (d) => {
                'device_id': d.deviceId,
                'device_name': d.deviceName,
                'created_at': jsIsoDateTime(d.createdAt),
                'last_sync_at': d.lastSyncAt == null
                    ? null
                    : jsIsoDateTime(d.lastSyncAt!),
                'fcm_token': d.fcmToken == null
                    ? null
                    // 只返回前缀，与 nodejs 一致
                    : d.fcmToken!.substring(
                        0,
                        d.fcmToken!.length < 10
                            ? d.fcmToken!.length
                            : 10,
                      ) +
                          '...',
                'platform': d.platform,
              },
            )
            .toList(),
        'count': devices.length,
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _registerDevice(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final data = await _readJsonBody(request);
    final deviceId = data['device_id'] as String?;
    if (deviceId == null || deviceId.isEmpty) {
      return _error(400, '设备 ID 不能为空');
    }
    if (data['platform'] == 'admin_panel' || deviceId == 'admin_panel') {
      return _ok({
        'message': '设备注册已忽略 (admin_panel)',
        'device': {
          'device_id': deviceId,
          'device_name': data['device_name'] ?? 'Admin Panel',
        },
      });
    }
    try {
      final device = await auth.registerDevice(
        userId: userId,
        deviceId: deviceId,
        deviceName: data['device_name'] as String?,
        fcmToken: data['fcm_token'] as String?,
        platform: data['platform'] as String?,
      );
      return _ok({
        'message': '设备注册成功',
        'device': {'device_id': device.deviceId, 'device_name': device.deviceName},
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _deleteDevice(Request request, String deviceId) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    try {
      await auth.deleteDevice(userId, deviceId);
      return _ok({'message': '设备已删除', 'device_id': deviceId});
    } catch (e) {
      final message = e.toString();
      if (message.contains('不存在')) return _error(404, message);
      return _error(500, '服务器错误: $e');
    }
  }

  /// FCM 推送：向用户设备发送通知（与 nodejs devices/push 一致）。
  Future<Response> _pushUnsupported(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final data = await _readJsonBody(request);
    final deviceId = data['device_id'] as String?;
    final title = data['title'] as String?;
    final body = data['body'] as String?;
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return _error(400, '标题和内容不能为空');
    }
    if (fcm == null) {
      return _error(501, 'Dart 服务器暂不支持 FCM 推送');
    }

    try {
      final user = await auth.findUserById(userId);
      if (user == null) return _error(404, '用户不存在');
      final tokens = auth.getDeviceFcmTokens(user, deviceId);
      if (tokens.isEmpty) {
        return _error(400, '没有可用的设备或设备未注册 FCM Token');
      }
      final data_ = data['data'] is Map
          ? (data['data'] as Map)
                .map((k, v) => MapEntry(k.toString(), v.toString()))
          : null;
      final result = await fcm!.sendMulticast(tokens, title, body, data_);
      return _ok({
        'message': '成功发送 ${result.success} 条，失败 ${result.failure} 条',
        'sent_count': result.success,
        'failure_count': result.failure,
        'target_devices': tokens.length,
        'results': result.results,
      });
    } catch (e) {
      return _error(500, '服务器错误: $e');
    }
  }

  Future<Response> _getApiAccess(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final enabled = await auth.getApiAccessStatus(userId);
    return _ok({'enabled': enabled});
  }

  Future<Response> _setApiAccess(Request request) async {
    final userId = _userIdFromBearer(request);
    if (userId == null) return _error(401, '未认证或 Token 无效');
    final data = await _readJsonBody(request);
    if (data['enabled'] is! bool) {
      return _error(400, 'enabled 参数必须是布尔值');
    }
    final enabled = data['enabled'] as bool;
    await auth.setApiAccessStatus(userId, enabled);
    return _ok({
      'enabled': enabled,
      'message': enabled ? 'API 访问已开启' : 'API 访问已关闭',
    });
  }
}
