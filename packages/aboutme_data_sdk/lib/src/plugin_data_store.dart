import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'legacy_encryption.dart';

const _keyVerificationFileName = '.key_verification.json';
const _keyVerificationContent = 'ABOUTME_KEY_VERIFICATION_v1';

/// 旧版加密文件结构（users/{userId}/{pluginId}/{file}.json）
class LegacyEncryptedFile {
  LegacyEncryptedFile({
    required this.encryptedData,
    required this.md5,
    required this.updatedAt,
    this.isBinary = false,
  });

  factory LegacyEncryptedFile.fromJson(Map<String, dynamic> json) =>
      LegacyEncryptedFile(
        encryptedData: json['encrypted_data'] as String,
        md5: json['md5'] as String,
        updatedAt: json['updated_at'] as String,
        isBinary: json['is_binary'] as bool? ?? false,
      );

  final String encryptedData;
  final String md5;
  final String updatedAt;
  final bool isBinary;

  Map<String, dynamic> toJson() => {
    'encrypted_data': encryptedData,
    'md5': md5,
    'updated_at': updatedAt,
    'is_binary': isBinary,
  };
}

/// 插件数据访问服务：读取/解密/加密/写入各插件的旧版加密数据文件。
///
/// 安全说明：服务端不保存用户密钥，每次操作传入加密密钥。
/// 数据布局与 nodejs PluginDataService 完全一致：
/// `{dataDir}/users/{userId}/{pluginId}/{fileName}.json`
class PluginDataStore {
  PluginDataStore(this.dataDir);

  final String dataDir;

  String getUserDataDir(String userId) => p.join(dataDir, 'users', userId);

  String _pluginFilePath(String userId, String pluginId, String fileName) =>
      p.join(getUserDataDir(userId), pluginId, fileName);

  // ==================== 底层加密文件 IO ====================

  Future<LegacyEncryptedFile?> readEncryptedFile(
    String userId,
    String relativePath,
  ) async {
    final fullPath = p.join(getUserDataDir(userId), relativePath);
    final file = File(fullPath);
    if (!await file.exists()) return null;
    try {
      return LegacyEncryptedFile.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeEncryptedFile(
    String userId,
    String relativePath,
    String encryptedData,
    String md5Hash, {
    bool isBinary = false,
  }) async {
    final fullPath = p.join(getUserDataDir(userId), relativePath);
    await File(fullPath).parent.create(recursive: true);
    await File(fullPath).writeAsString(
      jsonEncode(
        LegacyEncryptedFile(
          encryptedData: encryptedData,
          md5: md5Hash,
          updatedAt: DateTime.now().toIso8601String(),
          isBinary: isBinary,
        ).toJson(),
      ),
    );
  }

  Future<bool> deleteFile(String userId, String relativePath) async {
    final fullPath = p.join(getUserDataDir(userId), relativePath);
    if (await File(fullPath).exists()) {
      await File(fullPath).delete();
      return true;
    }
    return false;
  }

  // ==================== 插件数据 ====================

  /// 读取并解密插件数据文件；不存在或解密失败返回 null。
  Future<dynamic> readPluginData(
    String userId,
    String pluginId,
    String fileName,
    String encryptionKey,
  ) async {
    final fileData = await readEncryptedFile(
      userId,
      p.posix.join(pluginId, fileName),
    );
    if (fileData == null) return null;
    try {
      return LegacyEncryption.decryptData(
        encryptionKey,
        fileData.encryptedData,
      );
    } catch (_) {
      return null;
    }
  }

  /// 读取插件数据并断言为 Map（多数 handler 的读法）。
  Future<Map<String, dynamic>> readPluginDataMap(
    String userId,
    String pluginId,
    String fileName,
    String encryptionKey,
  ) async {
    final data = await readPluginData(userId, pluginId, fileName, encryptionKey);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// 加密并写入插件数据（对象或数组）。
  Future<void> writePluginData(
    String userId,
    String pluginId,
    String fileName,
    dynamic data,
    String encryptionKey,
  ) async {
    final encryptedData = LegacyEncryption.encryptDynamic(encryptionKey, data);
    final md5Hash = LegacyEncryption.computeDynamicMd5(data);
    await writeEncryptedFile(
      userId,
      p.posix.join(pluginId, fileName),
      encryptedData,
      md5Hash,
    );
  }

  Future<bool> deletePluginFile(
    String userId,
    String pluginId,
    String fileName,
  ) {
    return deleteFile(userId, p.posix.join(pluginId, fileName));
  }

  /// 列出插件目录下的 JSON 文件名（单层，支持 `*` 通配）。
  Future<List<String>> listPluginFiles(
    String userId,
    String pluginId, [
    String? pattern,
  ]) async {
    final pluginDir = Directory(_pluginFilePath(userId, pluginId, '.'));
    if (!await pluginDir.exists()) return [];

    final files = <String>[];
    await for (final entity in pluginDir.list()) {
      final name = p.basename(entity.path);
      if (entity is File && name.endsWith('.json')) {
        if (pattern == null || matchPattern(name, pattern)) {
          files.add(name);
        }
      }
    }
    return files;
  }

  static bool matchPattern(String fileName, String pattern) {
    final regex = RegExp('^' + pattern.replaceAll('*', '.*') + r'$');
    return regex.hasMatch(fileName);
  }

  // ==================== 密钥验证文件 ====================

  Future<bool> hasKeyVerificationFile(String userId) async {
    return File(
      p.join(getUserDataDir(userId), _keyVerificationFileName),
    ).exists();
  }

  Future<void> createKeyVerificationFile(
    String userId,
    String encryptionKey,
  ) async {
    final verificationData = {
      'content': _keyVerificationContent,
      'created_at': DateTime.now().toIso8601String(),
    };
    await writeEncryptedFile(
      userId,
      _keyVerificationFileName,
      LegacyEncryption.encryptDynamic(encryptionKey, verificationData),
      LegacyEncryption.computeDynamicMd5(verificationData),
    );
  }

  /// 验证密钥是否正确；验证文件不存在视为首次设置（通过）。
  /// 返回 [是否通过, 失败原因]。
  Future<(bool, String?)> verifyEncryptionKey(
    String userId,
    String encryptionKey,
  ) async {
    if (!await hasKeyVerificationFile(userId)) return (true, null);

    final file = await readEncryptedFile(userId, _keyVerificationFileName);
    if (file == null) return (true, null);
    if (file.encryptedData.isEmpty) return (false, '验证文件格式错误');

    try {
      final decrypted = LegacyEncryption.decryptData(
        encryptionKey,
        file.encryptedData,
      ) as Map<String, dynamic>;
      if (decrypted['content'] != _keyVerificationContent) {
        return (false, '密钥验证失败：内容不匹配');
      }
      return (true, null);
    } catch (_) {
      return (false, '密钥验证失败：无法解密验证文件，密钥可能不正确');
    }
  }

  Future<void> updateKeyVerificationFile(
    String userId,
    String encryptionKey,
  ) async {
    final file = File(
      p.join(getUserDataDir(userId), _keyVerificationFileName),
    );
    if (await file.exists()) await file.delete();
    await createKeyVerificationFile(userId, encryptionKey);
  }

  // ==================== 重新加密（密钥更改） ====================

  Future<({int fileCount, List<String> errors})> reEncryptAllFiles(
    String userId,
    String oldKey,
    String newKey,
  ) async {
    var fileCount = 0;
    final errors = <String>[];
    final userDir = Directory(getUserDataDir(userId));
    if (!await userDir.exists()) return (fileCount: 0, errors: errors);

    await for (final entity
        in userDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final file = entity;
      final relative = p.relative(file.path, from: userDir.path);
      try {
        final fileData = await readEncryptedFile(userId, relative);
        if (fileData == null) continue;

        final decrypted = LegacyEncryption.decryptData(
          oldKey,
          fileData.encryptedData,
        );
        final json = jsonEncode(decrypted);
        await writeEncryptedFile(
          userId,
          relative,
          LegacyEncryption.encryptString(newKey, json),
          LegacyEncryption.computeStringMd5(json),
        );
        fileCount++;
      } catch (e) {
        errors.add('$relative: $e');
      }
    }
    return (fileCount: fileCount, errors: errors);
  }
}
