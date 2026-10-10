import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// PBKDF2-HMAC-SHA256（10000 轮 / 64 字节），与 nodejs 服务器
/// `crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha256')` 输出完全一致，
/// salt 与哈希均以 Base64 存储，保证两套服务端可共用 users.json。
class PasswordHasher {
  static const iterations = 10000;
  static const keyLength = 64;

  /// 生成 16 字节随机 salt（Base64），与 nodejs `randomBytes(16).toString('base64')` 同构。
  static String generateSalt() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  static String hashPassword(String password, String saltBase64) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(
        Pbkdf2Parameters(
          base64Decode(saltBase64),
          iterations,
          keyLength,
        ),
      );
    final key = derivator.process(utf8.encode(password));
    return base64Encode(key);
  }

  static bool verifyPassword(
    String password,
    String saltBase64,
    String expectedHashBase64,
  ) {
    final candidate = hashPassword(password, saltBase64);
    final a = base64Decode(candidate);
    final b = base64Decode(expectedHashBase64);
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
