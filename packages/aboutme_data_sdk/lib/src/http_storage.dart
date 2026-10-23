import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
/// 数据明文传输（服务端存储已取消加密）；写操作走条件写
/// （If-Match / If-None-Match），冲突交由调用方处理。
class HttpStorage implements StorageInterface {
  HttpStorage({
    required String serverUrl,
    required StorageAuthType authType,
    required String credential,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    String? deviceId,
  }) : _baseUri = Uri.parse(serverUrl.replaceFirst(RegExp(r'/$'), '')),
       _credential = credential,
       _client = client ?? http.Client(),
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
      client: client,
      deviceId: deviceId,
    );
  }

  final Uri _baseUri;
  final String _credential;
  final http.Client _client;
  final String? _deviceId;
  final Duration timeout;
  final Map<String, String> _versions = {};

  String get serverUrl => _baseUri.toString();
  String get credential => _credential;
  String? get deviceId => _deviceId;
  void close() => _client.close();

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
      queryParameters: normalizedPrefix == null
          ? null
          : {'prefix': normalizedPrefix},
    );
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
    String? message;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is String)
        message = decoded['error'] as String;
    } on FormatException {
      // 非 JSON 错误页也按 HTTP 状态映射。
    }
    if (code == 401 || code == 403) {
      throw StorageException(
        StorageErrorKind.unauthorized,
        message ?? '认证失败',
        statusCode: code,
      );
    }
    if (code == 404) {
      throw StorageException(
        StorageErrorKind.notFound,
        message ?? '资源不存在',
        statusCode: code,
      );
    }
    if (code == 409 || code == 412) {
      throw StorageException(
        StorageErrorKind.conflict,
        message ?? '远端版本已被其他客户端修改',
        statusCode: code,
      );
    }
    if (code == 422 || code == 426 || code == 501) {
      throw StorageException(
        code == 422
            ? StorageErrorKind.invalidData
            : StorageErrorKind.unsupported,
        message ?? '服务端不支持该能力或数据损坏',
        statusCode: code,
      );
    }
    if (code >= 500) {
      throw StorageException(
        StorageErrorKind.server,
        message ?? '存储服务器错误',
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

  Future<void> testConnection() async {
    final uri = Uri.parse('${_baseUri.toString()}/api/v1/storage/health');
    final response = await _request(() => _client.get(uri, headers: _headers));
    if (response.statusCode != 200) _throwFor(response);
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

  /// 业务请求保留 HTTP 方法。写入不自动重试，避免超时后的重复效果。
  /// GET 的复合参数使用 JSON 编码；DELETE 参数放请求体。
  Future<Map<String, dynamic>> requestJson(
    String method,
    String path,
    Map<String, dynamic> params,
  ) async {
    final verb = method.toUpperCase();
    if (!const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(verb)) {
      throw const StorageException(
        StorageErrorKind.invalidRequest,
        '不支持的 HTTP 方法',
      );
    }
    var uri = Uri.parse('${_baseUri.toString()}$path');
    if (verb == 'GET' && params.isNotEmpty) {
      uri = uri.replace(
        queryParameters: params.map(
          (key, value) => MapEntry(
            key,
            jsonEncode(
              value,
              toEncodable: (value) => value is DateTime
                  ? value.toUtc().toIso8601String()
                  : throw ArgumentError('不支持的参数类型: ${value.runtimeType}'),
            ),
          ),
        ),
      );
    }
    final response = await _request(() async {
      final request = http.Request(verb, uri);
      request.headers.addAll({
        ..._headers,
        'Content-Type': 'application/json',
        'X-Aboutme-Query-Encoding': 'json-v1',
      });
      if (verb != 'GET') {
        request.body = jsonEncode(
          params,
          toEncodable: (value) => value is DateTime
              ? value.toUtc().toIso8601String()
              : throw ArgumentError('不支持的参数类型: ${value.runtimeType}'),
        );
      }
      return http.Response.fromStream(await _client.send(request));
    }, retry: verb == 'GET');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 已认证业务协议的失败保留 code/version，尤其是不存在实体的读取版本。
      // 不能把非成功 HTTP 中的 success=true 当成成功结果。
      try {
        final failure = jsonDecode(response.body);
        if (failure is Map<String, dynamic> && failure['success'] == false &&
            failure['error'] is String && failure['code'] is String) {
          return failure;
        }
      } on FormatException { /* 非业务错误仍按 HTTP 状态映射。 */ }
      _throwFor(response);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const StorageException(
        StorageErrorKind.invalidData,
        '业务响应不是有效 JSON',
      );
    }
    if (decoded is Map<String, dynamic>) return decoded;
    throw const StorageException(
      StorageErrorKind.invalidData,
      '业务响应必须是 JSON 对象',
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) => requestJson('POST', path, body);

  Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, dynamic> query,
  ) => requestJson('GET', path, query);

  @override
  Future<Uint8List?> readBytes(String path) async {
    final response = await _request(
      () => _client.get(_filesUri(path), headers: _headers),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwFor(response);
    final etag = response.headers['etag'];
    if (etag != null) _versions[path] = etag;
    return Uint8List.fromList(response.bodyBytes);
  }

  /// 版本冲突直接返回，禁止用陈旧内容刷新版本后覆盖最新数据。
  @override
  Future<void> writeBytes(String path, Uint8List bytes) =>
      writeBytesIfCurrent(path, bytes);

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
      () => _client.put(_filesUri(path), headers: headers, body: bytes),
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
  Future<List<StorageFileInfo>> listFileInfos(String prefix) async {
    final response = await _request(
      () => _client.get(_filesUri(null, prefix), headers: _headers),
    );
    if (response.statusCode != 200) _throwFor(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['files'] as List<dynamic>).map((e) {
      if (e is String) return StorageFileInfo(path: e);
      final info = e as Map<String, dynamic>;
      return StorageFileInfo(
        path: info['path'] as String,
        size: (info['size'] as num?)?.toInt(),
        updatedAt: DateTime.tryParse(info['updated_at'] as String? ?? ''),
      );
    }).toList();
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
