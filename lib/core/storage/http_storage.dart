import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;

import 'storage_backend_config.dart';
import 'storage_interface.dart';

enum StorageErrorKind {
  unauthorized,
  notFound,
  conflict,
  offline,
  server,
  invalidData,
  invalidRequest,
}

class StorageException implements Exception {
  const StorageException(this.kind, this.message, {this.statusCode});
  final StorageErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'StorageException($kind${statusCode == null ? '' : ', HTTP $statusCode'}): $message';
}

class HttpStorage implements StorageInterface {
  HttpStorage({
    required String serverUrl,
    required StorageAuthType authType,
    required String credential,
    required String encryptionKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(serverUrl.replaceFirst(RegExp(r'/$'), '')),
       _credential = credential,
       _client = client ?? http.Client(),
       _key = _decodeKey(encryptionKey);

  factory HttpStorage.fromConfig(StorageBackendConfig config, {http.Client? client}) {
    config.validate();
    return HttpStorage(
      serverUrl: config.serverUrl,
      authType: config.authType,
      credential: config.credential,
      encryptionKey: config.encryptionKey,
      client: client,
    );
  }

  final Uri _baseUri;
  final String _credential;
  final http.Client _client;
  final encrypt.Key _key;
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
  Map<String, String> get _headers => {'X-API-Key': _credential};

  Uri _filesUri([String? path, String? prefix]) {
    final root = '${_baseUri.toString()}/api/v1/storage/files';
    if (path != null) {
      // 本地文件路径在 Windows 上可能包含反斜杠；HTTP API 统一使用正斜杠。
      final normalizedPath = path.replaceAll('\\', '/');
      final encoded = normalizedPath.split('/').map(Uri.encodeComponent).join('/');
      return Uri.parse('$root/$encoded');
    }
    final normalizedPrefix = prefix?.replaceAll('\\', '/');
    return Uri.parse(root).replace(queryParameters: normalizedPrefix == null ? null : {'prefix': normalizedPrefix});
  }

  Uint8List _encrypt(Uint8List bytes) {
    final iv = encrypt.IV.fromSecureRandom(12);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.gcm));
    final ciphertext = encrypter.encryptBytes(bytes, iv: iv);
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'version': 1,
      'iv': iv.base64,
      'ciphertext': ciphertext.base64,
    })));
  }

  Uint8List _decrypt(Uint8List envelopeBytes) {
    try {
      final envelope = jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
      if (envelope['version'] != 1) throw const FormatException('不支持的密文版本');
      final iv = encrypt.IV.fromBase64(envelope['iv'] as String);
      final ciphertext = encrypt.Encrypted.fromBase64(envelope['ciphertext'] as String);
      final encrypter = encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.gcm));
      return Uint8List.fromList(encrypter.decryptBytes(ciphertext, iv: iv));
    } catch (error) {
      throw StorageException(StorageErrorKind.invalidData, '远端数据无法解密: $error');
    }
  }

  Future<http.Response> _request(Future<http.Response> Function() request, {bool retry = true}) async {
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
      throw StorageException(StorageErrorKind.unauthorized, '认证失败', statusCode: code);
    }
    if (code == 404) {
      throw StorageException(StorageErrorKind.notFound, '文件不存在', statusCode: code);
    }
    if (code == 409 || code == 412) {
      throw StorageException(StorageErrorKind.conflict, '远端文件已被其他客户端修改', statusCode: code);
    }
    if (code >= 500) {
      throw StorageException(StorageErrorKind.server, '存储服务器错误', statusCode: code);
    }
    final detail = response.body.trim();
    throw StorageException(
      StorageErrorKind.invalidRequest,
      detail.isEmpty ? '存储请求失败' : '存储请求失败：$detail',
      statusCode: code,
    );
  }

  Future<String?> _fetchVersion(String path) async {
    final response = await _request(() => _client.head(_filesUri(path), headers: _headers));
    if (response.statusCode == 404) return null;
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
    final response = await _request(() => _client.get(_filesUri(path), headers: _headers));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
    return _decrypt(response.bodyBytes);
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final version = _versions[path] ?? await _fetchVersion(path);
    final headers = <String, String>{
      ..._headers,
      'Content-Type': 'application/octet-stream',
      if (version == null) 'If-None-Match': '*' else 'If-Match': version,
    };
    final response = await _request(() => _client.put(_filesUri(path), headers: headers, body: _encrypt(bytes)));
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
  }

  Future<void> forceWriteBytes(String path, Uint8List bytes) async {
    final response = await _request(() => _client.put(
      _filesUri(path),
      headers: {..._headers, 'Content-Type': 'application/octet-stream', 'X-Force-Overwrite': 'true'},
      body: _encrypt(bytes),
    ));
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
  }

  @override
  Future<void> deleteFile(String path) async {
    final version = _versions[path] ?? await _fetchVersion(path);
    if (version == null) return;
    final response = await _request(() => _client.delete(
      _filesUri(path), headers: {..._headers, 'If-Match': version},
    ));
    if (response.statusCode != 204 && response.statusCode != 404) _throwFor(response);
    _versions.remove(path);
  }

  @override
  Future<List<String>> getKeysWithPrefix(String prefix) async {
    final response = await _request(() => _client.get(_filesUri(null, prefix), headers: _headers));
    if (response.statusCode != 200) _throwFor(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['files'] as List<dynamic>).cast<String>();
  }

  @override
  Future<void> clearWithPrefix(String prefix) async {
    final response = await _request(() => _client.delete(_filesUri(null, prefix), headers: _headers));
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
  Future<void> saveData(String key, String value) => writeBytes(key, Uint8List.fromList(utf8.encode(value)));

  @override
  Future<void> removeData(String key) => deleteFile(key);

  @override
  Future<dynamic> loadJson(String key, [dynamic defaultValue]) async {
    final value = await loadData(key);
    return value == null || value.isEmpty ? defaultValue ?? {} : jsonDecode(value);
  }

  @override
  Future<void> saveJson(String key, dynamic data) => saveData(key, jsonEncode(data));

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<String> readString(String path) async {
    final value = await loadData(path);
    if (value == null) throw StorageException(StorageErrorKind.notFound, '文件不存在: $path');
    return value;
  }

  @override
  Future<void> writeString(String path, String content) => saveData(path, content);
}
