import 'dart:convert';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

/// 旧版加密服务（插件数据 / 密钥验证文件），与 nodejs EncryptionService
/// 及 Dart 客户端 EncryptionService 完全兼容：
/// AES-256-GCM、16 字节 IV、格式 `base64(iv).base64(ciphertext+authTag)`。
class LegacyEncryption {
  static const _ivLength = 16;
  static const _authTagLength = 16;

  /// 校验密钥（Base64 编码的 32 字节），返回原始字节。
  static Uint8List validateKey(String base64Key) {
    final keyBytes = base64Decode(base64Key);
    if (keyBytes.length != 32) {
      throw Exception('密钥长度必须为 32 字节 (256-bit)');
    }
    return Uint8List.fromList(keyBytes);
  }

  /// 解密为 JSON（对象或数组）。
  static dynamic decryptData(String base64Key, String encryptedString) {
    return jsonDecode(decryptString(base64Key, encryptedString));
  }

  /// 解密字符串。
  static String decryptString(String base64Key, String encryptedString) {
    final key = validateKey(base64Key);

    final parts = encryptedString.split('.');
    if (parts.length != 2) {
      throw Exception('无效的加密数据格式，期望: iv.ciphertext');
    }

    final iv = base64Decode(parts[0]);
    final encrypted = base64Decode(parts[1]);
    if (encrypted.length < _authTagLength) {
      throw Exception('无效的密文长度');
    }

    // pointycastle GCM 解密：输入为密文+authTag（末 16 字节），
    // AEADParameters 的 mac 传空，由 doFinal 校验
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _authTagLength * 8,
          Uint8List.fromList(iv),
          Uint8List(0),
        ),
      );
    final plaintext = cipher.process(Uint8List.fromList(encrypted));
    return utf8.decode(plaintext);
  }

  /// 解密二进制（密文内为 Base64 编码的原始字节）。
  static Uint8List decryptBinary(String base64Key, String encryptedString) {
    final decryptedBase64 = decryptString(base64Key, encryptedString);
    return Uint8List.fromList(base64Decode(decryptedBase64));
  }

  /// 加密 JSON 数据（对象或数组）。
  static String encryptDynamic(String base64Key, dynamic data) {
    return encryptString(base64Key, jsonEncode(data));
  }

  /// 加密字符串。
  static String encryptString(String base64Key, String data) {
    final key = validateKey(base64Key);

    final random = Random.secure();
    final iv = Uint8List(_ivLength);
    for (var i = 0; i < iv.length; i++) {
      iv[i] = random.nextInt(256);
    }

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _authTagLength * 8,
          iv,
          Uint8List(0),
        ),
      );
    final encryptedWithTag = cipher.process(
      Uint8List.fromList(utf8.encode(data)),
    );
    return '${base64Encode(iv)}.${base64Encode(encryptedWithTag)}';
  }

  /// 计算数据（加密前）规范化 JSON 的 MD5：递归按 key 排序。
  static String computeDynamicMd5(dynamic data) {
    return crypto.md5.convert(utf8.encode(jsonEncode(_normalize(data)))).toString();
  }

  static String computeStringMd5(String data) =>
      crypto.md5.convert(utf8.encode(data)).toString();

  static dynamic _normalize(dynamic value) {
    if (value == null) return value;
    if (value is List) return value.map(_normalize).toList();
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
      return sorted.map((k, v) => MapEntry(k, _normalize(v)));
    }
    return value;
  }

  /// 解密 Storage API 的信封格式（旧版端到端加密，12 字节 IV）：
  /// `{"version":1,"iv":base64(12),"ciphertext":base64}` → 明文字节。
  /// 仅供一次性数据迁移使用。
  static Uint8List decryptEnvelope(String base64Key, Uint8List envelopeBytes) {
    final key = validateKey(base64Key);
    final envelope =
        jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
    if (envelope['version'] != 1) {
      throw Exception('不支持的密文版本');
    }
    final iv = base64Decode(envelope['iv'] as String);
    final encrypted = base64Decode(envelope['ciphertext'] as String);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          16 * 8,
          Uint8List.fromList(iv),
          Uint8List(0),
        ),
      );
    return cipher.process(Uint8List.fromList(encrypted));
  }
}
