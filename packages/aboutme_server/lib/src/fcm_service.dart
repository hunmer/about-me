import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

/// FCM 推送服务（移植自 nodejs fcmService.ts）：
/// - service-account.json 定位：FCM_SERVICE_ACCOUNT 环境变量 → DATA_DIR → 当前目录
/// - OAuth2 access token：JWT RS256 断言换取（提前 5 分钟刷新）
/// - FCM HTTP v1 `messages:send` 逐 token 发送
/// - 代理：遵循 HTTPS_PROXY/https_proxy 环境变量（dart findProxyFromEnvironment）
class FcmService {
  FcmService({String? serviceAccountPath, required this.dataDir})
      : _serviceAccountPathOverride = serviceAccountPath;

  final String? _serviceAccountPathOverride;
  final String dataDir;

  Map<String, dynamic>? _serviceAccount;
  String? _cachedToken;
  int _tokenExpiryMs = 0;
  HttpClient? _client;

  HttpClient get _httpClient =>
      _client ??= HttpClient()
        ..findProxy = HttpClient.findProxyFromEnvironment
        ..autoUncompress = false;

  /// 定位并加载 service-account.json。
  Future<Map<String, dynamic>> _loadServiceAccount() async {
    final cached = _serviceAccount;
    if (cached != null) return cached;
    final override = _serviceAccountPathOverride;
    final candidates = <String>[
      if (override != null) override,
      p.join(dataDir, 'service-account.json'),
      p.join(Directory.current.path, 'service-account.json'),
    ];
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        final account =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _serviceAccount = account;
        return account;
      }
    }
    throw Exception(
      'service-account.json 不存在（查找过: ${candidates.join(', ')}）',
    );
  }

  String _base64UrlNoPadding(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// RS256 签名（RSA-SHA256 PKCS1v1.5）。
  Uint8List _signRs256(String privateKeyPem, String input) {
    final key = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(key));
    return signer
        .generateSignature(Uint8List.fromList(utf8.encode(input)))
        .bytes;
  }

  /// 获取（或复用缓存的）OAuth2 access token。
  Future<String> getAccessToken() async {
    if (_cachedToken != null &&
        DateTime.now().millisecondsSinceEpoch < _tokenExpiryMs - 5 * 60 * 1000) {
      return _cachedToken!;
    }

    final account = await _loadServiceAccount();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = _base64UrlNoPadding(
      utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'})),
    );
    final payload = _base64UrlNoPadding(
      utf8.encode(jsonEncode({
        'iss': account['client_email'],
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': now,
        'exp': now + 3600,
      })),
    );
    final signature = _base64UrlNoPadding(
      _signRs256(
        account['private_key'] as String,
        '$header.$payload',
      ),
    );
    final assertion = '$header.$payload.$signature';

    final request = await _httpClient.postUrl(
      Uri.parse('https://oauth2.googleapis.com/token'),
    );
    final body = utf8.encode(
      'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$assertion',
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    request.headers.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw Exception('Token request failed: ${response.statusCode} $responseBody');
    }
    final tokenResponse = jsonDecode(responseBody) as Map<String, dynamic>;
    _cachedToken = tokenResponse['access_token'] as String;
    _tokenExpiryMs =
        DateTime.now().millisecondsSinceEpoch +
        ((tokenResponse['expires_in'] as num?) ?? 3600).toInt() * 1000;
    return _cachedToken!;
  }

  Future<String> _projectId() async =>
      ((await _loadServiceAccount())['project_id'] ?? '') as String;

  /// FCM HTTP v1 发送单条消息。
  Future<({bool success, String? messageId, String? error})> _sendViaV1Api(
    Map<String, dynamic> message,
  ) async {
    try {
      final token = await getAccessToken();
      final projectId = await _projectId();
      final request = await _httpClient.postUrl(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
        ),
      );
      final body = utf8.encode(jsonEncode(message));
      request.headers.contentType = ContentType.json;
      request.headers.contentLength = body.length;
      request.headers.set('Authorization', 'Bearer $token');
      request.add(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return (
          success: true,
          messageId: (jsonDecode(responseBody)
                  as Map<String, dynamic>)['name'] as String?,
          error: null,
        );
      }
      return (
        success: false,
        messageId: null,
        error: 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      return (success: false, messageId: null, error: error.toString());
    }
  }

  /// 批量发送到多个设备 token（逐条发送，统计成功/失败）。
  Future<
      ({
        int success,
        int failure,
        List<Map<String, dynamic>> results,
      })> sendMulticast(
    List<String> tokens,
    String title,
    String body, [
    Map<String, String>? data,
  ]) async {
    await _loadServiceAccount();
    var successCount = 0;
    var failureCount = 0;
    final results = <Map<String, dynamic>>[];

    for (final token in tokens) {
      final message = {
        'message': {
          'token': token,
          'notification': {'title': title, 'body': body},
          'data': data ?? <String, String>{},
        },
      };
      final result = await _sendViaV1Api(message);
      if (result.success) {
        successCount++;
        results.add({'success': true, 'messageId': result.messageId});
      } else {
        failureCount++;
        results.add({'success': false, 'error': result.error});
      }
    }
    return (
      success: successCount,
      failure: failureCount,
      results: results,
    );
  }

  /// service-account 是否可用（管理界面诊断用）。
  Future<bool> isConfigured() async {
    try {
      await _loadServiceAccount();
      return true;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _client?.close();
    _client = null;
  }
}
