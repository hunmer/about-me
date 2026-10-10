import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;

import 'storage_config.dart';
import 'storage_errors.dart';
import 'storage_interface.dart';

/// 全局默认设备 ID；宿主应用启动时应将其设为持久化的设备标识，
/// 用于服务端 WebSocket 广播时区分数据来源设备。留空表示未知来源。
class HttpStorageDefaults {
  HttpStorageDefaults._();

  static String deviceId = '';
}

/// HTTP 远端存储后端：对接 Aboutme 存储服务的 `/api/v1/storage/files` API。
///
/// 数据在上传前做 AES-256-GCM 信封加密（服务端只存密文），下载后解密；
/// 写操作统一走强制覆盖（X-Force-Overwrite），并记录 ETag 供诊断。
class HttpStorage implements StorageInterface {
  HttpStorage({
    required String serverUrl,
    required StorageAuthType authType,
    required String credential,
    required String encryptionKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    String? deviceId,
  }) : _baseUri = Uri.parse(serverUrl.replaceFirst(RegExp(r'/$'), '')),
       _credential = credential,
       _client = client ?? http.Client(),
       _key = _decodeKey(encryptionKey),
       _deviceId = deviceId;

  factory HttpStorage.fromConfig(
    StorageBackendConfig config, {
    http.Client? client,
    String? deviceId,
  }) {
    config.validate();
    return HttpStorage(
      serverUrl: config.serverUrl,
      authType: config.authType,
      credential: config.credential,
      encryptionKey: config.encryptionKey,
      client: client,
      deviceId: deviceId,
    );
  }

  final Uri _baseUri;
  final String _credential;
  final http.Client _client;
  final encrypt.Key _key;
  final String? _deviceId;
  final Duration timeout;
  final Map<String, String> _versions = {};

  static encrypt.Key _decodeKey(String value) {
    try {
      final bytes = base64Decode(value);
      if (bytes.length != 32) throw const FormatException();
      return encrypt.Key(Uint8List.fromList(bytes));
    } catch (_) {
      throw const FormatException('加密密钥必须是 Base64 编码的 32 字节密钥');
    }
  }

  /// HTTP 存储统一通过 X-API-Key 认证。
  Map<String, String> get _headers => {
    'X-API-Key': _credential,
    'X-Device-ID': _deviceId ?? HttpStorageDefaults.deviceId,
  };

  Uri _filesUri([String? path, String? prefix]) {
    final root = '${_baseUri.toString()}/api/v1/storage/files';
    if (path != null) {
      // 本地文件路径在 Windows 上可能包含反斜杠；HTTP API 统一使用正斜杠。
      final normalizedPath = path.replaceAll('\\', '/');
      final encoded = normalizedPath
          .split('/')
          .map(Uri.encodeComponent)
          .join('/');
      return Uri.parse('$root/$encoded');
    }
    final normalizedPrefix = prefix?.replaceAll('\\', '/');
    return Uri.parse(root).replace(
      queryParameters:
          normalizedPrefix == null ? null : {'prefix': normalizedPrefix},
    );
  }

  Uint8List _encrypt(Uint8List bytes) {
    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.gcm),
    );
    final ciphertext = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'iv': iv.base64,
          'ciphertext': ciphertext.base64,
        }),
      ),
    );
  }

  Uint8List _decrypt(Uint8List envelopeBytes) {
    try {
      final envelope =
          jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
      if (envelope['version'] != 1) throw const FormatException('不支持的密文版本');
      final iv = encrypt.IV.fromBase64(envelope['iv'] as String);
      final ciphertext = encrypt.Encrypted.fromBase64(
        envelope['ciphertext'] as String,
      );
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_key, mode: encrypt.AESMode.gcm),
      );
      return Uint8List.fromList(encrypter.decryptBytes(ciphertext, iv: iv));
    } catch (error) {
      throw StorageException(
        StorageErrorKind.invalidData,
        '远端数据无法解密: $error',
      );
    }
  }

  Future<http.Response> _request(
    Future<http.Response> Function() request, {
    bool retry = true,
  }) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const StorageException(StorageErrorKind.offline, '连接存储服务器超时');
    } on http.ClientException catch (error) {
      if (retry) {
        // 连接层失败(服务器冷启动窗口/keep-alive 连接被服务端关闭)时
        // 重建连接重试一次; 写操作有 If-Match 版本保护, 重放安全
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return _request(request, retry: false);
      }
      throw StorageException(StorageErrorKind.offline, '无法连接存储服务器: $error');
    }
  }

  Never _throwFor(http.Response response) {
    final code = response.statusCode;
    if (code == 401 || code == 403) {
      throw StorageException(
        StorageErrorKind.unauthorized,
        '认证失败',
        statusCode: code,
      );
    }
    if (code == 404) {
      throw StorageException(
        StorageErrorKind.notFound,
        '文件不存在',
        statusCode: code,
      );
    }
    if (code == 409 || code == 412) {
      throw StorageException(
        StorageErrorKind.conflict,
        '远端文件已被其他客户端修改',
        statusCode: code,
      );
    }
    if (code >= 500) {
      throw StorageException(
        StorageErrorKind.server,
        '存储服务器错误',
        statusCode: code,
      );
    }
    final detail = response.body.trim();
    throw StorageException(
      StorageErrorKind.invalidRequest,
      detail.isEmpty ? '存储请求失败' : '存储请求失败：$detail',
      statusCode: code,
    );
  }

  Future<String?> _fetchVersion(String path) async {
    final response = await _request(
      () => _client.head(_filesUri(path), headers: _headers),
    );
    if (response.statusCode == 404) {
      _versions.remove(path);
      return null;
    }
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
    return etag;
  }

  Future<void> testConnection() async {
    final uri = Uri.parse('${_baseUri.toString()}/api/v1/storage/health');
    final response = await _request(() => _client.get(uri, headers: _headers));
    if (response.statusCode != 200) _throwFor(response);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final response = await _request(
      () => _client.get(_filesUri(path), headers: _headers),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
    return _decrypt(response.bodyBytes);
  }

  /// 写入文件：优先条件写（已知版本用 If-Match，新文件用 If-None-Match: *），
  /// 冲突时刷新版本重试一次，仍冲突则强制覆盖。
  /// 这样既能在多端并发时让服务端记录真实的版本冲突（审计可见），
  /// 又保持调用方"写必成功"的历史语义。
  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      _writeBytesConditional(path, bytes, retryAllowed: true);

  Future<void> _writeBytesConditional(
    String path,
    Uint8List bytes, {
    required bool retryAllowed,
  }) async {
    final headers = <String, String>{
      ..._headers,
      'Content-Type': 'application/octet-stream',
    };
    final knownEtag = _versions[path];
    if (knownEtag != null) {
      headers['If-Match'] = knownEtag;
    } else {
      headers['If-None-Match'] = '*';
    }
    final response = await _request(
      () =>
          _client.put(_filesUri(path), headers: headers, body: _encrypt(bytes)),
    );

    if (response.statusCode == 412) {
      if (retryAllowed) {
        // 远端版本已变化：刷新本地 ETag 后重试一次
        final latest = await _fetchVersion(path);
        if (latest == null) _versions.remove(path);
        return _writeBytesConditional(path, bytes, retryAllowed: false);
      }
      return _forceWrite(path, bytes);
    }
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
  }

  Future<void> _forceWrite(String path, Uint8List bytes) async {
    final headers = <String, String>{
      ..._headers,
      'Content-Type': 'application/octet-stream',
      'X-Force-Overwrite': 'true',
    };
    final response = await _request(
      () =>
          _client.put(_filesUri(path), headers: headers, body: _encrypt(bytes)),
    );
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
  }

  /// 严格条件写：版本冲突（412）直接抛 StorageException(conflict)，
  /// 不重试不强制覆盖，供需要显式处理冲突的调用方使用。
  Future<void> writeBytesIfCurrent(String path, Uint8List bytes) async {
    final headers = <String, String>{
      ..._headers,
      'Content-Type': 'application/octet-stream',
    };
    final knownEtag = _versions[path];
    if (knownEtag != null) {
      headers['If-Match'] = knownEtag;
    } else {
      headers['If-None-Match'] = '*';
    }
    final response = await _request(
      () =>
          _client.put(_filesUri(path), headers: headers, body: _encrypt(bytes)),
    );
    if (response.statusCode == 412) {
      _throwFor(response);
    }
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
  }

  Future<void> forceWriteBytes(String path, Uint8List bytes) async {
    await writeBytes(path, bytes);
  }

  @override
  Future<void> deleteFile(String path) async {
    final response = await _request(
      () => _client.delete(
        _filesUri(path),
        headers: {..._headers, 'X-Force-Overwrite': 'true'},
      ),
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      _throwFor(response);
    }
    _versions.remove(path);
  }

  @override
  Future<List<String>> getKeysWithPrefix(String prefix) async {
    final response = await _request(
      () => _client.get(_filesUri(null, prefix), headers: _headers),
    );
    if (response.statusCode != 200) _throwFor(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    // 服务器返回 {path,size,updated_at} 对象数组，本地实现返回字符串数组，两者都兼容
    return (body['files'] as List<dynamic>)
        .map(
          (e) =>
              e is String ? e : (e as Map<String, dynamic>)['path'] as String,
        )
        .toList();
  }

  @override
  Future<void> clearWithPrefix(String prefix) async {
    final response = await _request(
      () => _client.delete(_filesUri(null, prefix), headers: _headers),
    );
    if (response.statusCode != 200) _throwFor(response);
    _versions.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<bool> hasData(String key) async => await _fetchVersion(key) != null;

  @override
  Future<String?> loadData(String key) async {
    final bytes = await readBytes(key);
    return bytes == null ? null : utf8.decode(bytes);
  }

  @override
  Future<void> saveData(String key, String value) =>
      writeBytes(key, Uint8List.fromList(utf8.encode(value)));

  @override
  Future<void> removeData(String key) => deleteFile(key);

  @override
  Future<dynamic> loadJson(String key, [dynamic defaultValue]) async {
    final value = await loadData(key);
    return value == null || value.isEmpty
        ? defaultValue ?? {}
        : jsonDecode(value);
  }

  @override
  Future<void> saveJson(String key, dynamic data) =>
      saveData(key, jsonEncode(data));

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<String> readString(String path) async {
    final value = await loadData(path);
    if (value == null) {
      throw StorageException(StorageErrorKind.notFound, '文件不存在: $path');
    }
    return value;
  }

  @override
  Future<void> writeString(String path, String content) =>
      saveData(path, content);
}
