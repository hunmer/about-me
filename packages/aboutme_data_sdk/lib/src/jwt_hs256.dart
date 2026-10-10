import 'dart:convert';

import 'package:crypto/crypto.dart';

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// 最小 HS256 JWT 实现（无第三方依赖），
/// 与 nodejs jsonwebtoken 默认算法兼容（payload: sub/iat/exp）。
class JwtHs256 {
  /// 签发 token；[expiresIn] 为有效期秒数。
  static String sign({
    required Map<String, dynamic> payload,
    required String secret,
    required Duration lifetime,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final body = {
      ...payload,
      'iat': payload['iat'] ?? now,
      'exp': payload['exp'] ?? now + lifetime.inSeconds,
    };
    final encodedHeader = _base64UrlNoPadding(utf8.encode(jsonEncode(header)));
    final encodedBody = _base64UrlNoPadding(utf8.encode(jsonEncode(body)));
    final signingInput = '$encodedHeader.$encodedBody';
    final signature = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(signingInput))
        .bytes;
    return '$signingInput.${_base64UrlNoPadding(signature)}';
  }

  /// 校验签名与 exp；失败返回 null。
  static Map<String, dynamic>? verify(String token, String secret) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final expected = Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode('${parts[0]}.${parts[1]}'))
          .bytes;
      final actual = base64Url.decode(
        parts[2].padRight((parts[2].length + 3) ~/ 4 * 4, '='),
      );
      if (!_fixedTimeEquals(expected, actual)) return null;

      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(
            parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '='),
          ),
        ),
      ) as Map<String, dynamic>;

      final exp = payload['exp'];
      if (exp is num &&
          DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp.toInt()) {
        return null;
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  static bool _fixedTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
