import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aboutme_data_sdk/io.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth_middleware.dart';
import 'ws_hub.dart';

/// Storage API 路由：`/api/v1/storage/*`，
/// 响应头/状态码/错误文案与 nodejs storageRoutes 完全对齐。
class StorageApi {
  StorageApi({
    required this.storage,
    required this.wsHub,
    required this.maxFileSizeBytes,
    required this.rateLimitPerMinute,
  });

  final LocalFileStorage storage;
  final StorageWsHub wsHub;
  final int maxFileSizeBytes;
  final int rateLimitPerMinute;

  final _rateWindows = <String, ({int startedAtMs, int count})>{};

  Router get router {
    final router = Router(notFoundHandler: _notFound);
    router.get('/health', _health);
    router.get('/files', _listFiles);
    router.delete('/files', _clearFiles);
    router.get('/files/<path|.*>', _readFile);
    router.add('HEAD', '/files/<path|.*>', _readFileHead);
    router.put('/files/<path|.*>', _writeFile);
    router.delete('/files/<path|.*>', _deleteFile);
    return router;
  }

  /// 每用户固定窗口限流（60 秒），与 nodejs 实现一致。
  Middleware get rateLimiter {
    return (innerHandler) {
      return (request) async {
        final auth = authContextOf(request);
        if (auth == null) {
          return Response(
            401,
            body: jsonEncode({'error': '未认证'}),
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final window = _rateWindows[auth.userId];
        if (window == null || now - window.startedAtMs >= 60000) {
          _rateWindows[auth.userId] = (startedAtMs: now, count: 1);
        } else {
          final count = window.count + 1;
          _rateWindows[auth.userId] = (
            startedAtMs: window.startedAtMs,
            count: count,
          );
          if (count > rateLimitPerMinute) {
            return Response(
              429,
              body: jsonEncode({'error': '请求过于频繁'}),
              headers: {
                'content-type': 'application/json; charset=utf-8',
                'retry-after': '60',
              },
            );
          }
        }
        return innerHandler(request);
      };
    };
  }

  Response _notFound(Request request) => Response(
    404,
    body: jsonEncode({'error': 'not_found'}),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _jsonError(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, String> _metadataHeaders(
    RawFileMetadata metadata, {
    bool includeRepresentationHeaders = true,
  }) {
    final headers = <String, String>{
      'etag': metadata.etag,
      'last-modified': HttpDate.format(metadata.modifiedAt.toUtc()),
    };
    if (includeRepresentationHeaders) {
      headers['content-length'] = '${metadata.size}';
      headers['content-type'] = 'application/octet-stream';
    }
    return headers;
  }

  Future<Response> _health(Request request) async {
    final auth = authContextOf(request)!;
    return Response.ok(
      jsonEncode({'status': 'healthy', 'user_id': auth.userId}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<Response> _listFiles(Request request) async {
    final auth = authContextOf(request)!;
    try {
      final prefix = request.url.queryParameters['prefix'] ?? '';
      final files = await storage.listRawFiles(auth.userId, prefix: prefix);
      return Response.ok(
        jsonEncode({
          'files': files
              .map(
                (f) => {
                  'path': f.path,
                  'size': f.size,
                  'updated_at': jsIsoDateTime(f.updatedAt),
                },
              )
              .toList(),
        }),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } on StoragePathException {
      return _jsonError(400, '无法列出文件');
    } catch (_) {
      return _jsonError(500, '无法列出文件');
    }
  }

  Future<Response> _clearFiles(Request request) async {
    final auth = authContextOf(request)!;
    try {
      final prefix = request.url.queryParameters['prefix'] ?? '';
      final deleted = await storage.clearRawFiles(auth.userId, prefix);
      await storage.logStorageAudit(
        userId: auth.userId,
        action: 'clear-prefix',
        filePath: prefix,
        details: 'deleted=$deleted',
      );
      wsHub.broadcastFileUpdate(
        auth.userId,
        request.headers['x-device-id'],
        prefix,
      );
      return Response.ok(
        jsonEncode({'deleted': deleted}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } on StoragePathException {
      return _jsonError(400, '无法清除文件');
    } catch (_) {
      return _jsonError(500, '无法清除文件');
    }
  }

  Future<Response> _readFile(Request request, String filePath) async {
    final auth = authContextOf(request)!;
    try {
      final result = await storage.readRawFile(auth.userId, filePath);
      if (result == null) return _jsonError(404, '文件不存在');
      return Response.ok(
        result.data,
        headers: _metadataHeaders(result.metadata),
      );
    } on StoragePathException {
      return _jsonError(400, '无法读取文件');
    } catch (_) {
      return _jsonError(500, '无法读取文件');
    }
  }

  Future<Response> _readFileHead(Request request, String filePath) async {
    final auth = authContextOf(request)!;
    try {
      final metadata = await storage.getRawFileMetadata(auth.userId, filePath);
      if (metadata == null) return Response(404);
      return Response(
        200,
        headers: _metadataHeaders(metadata),
        body: Uint8List(0),
      );
    } on StoragePathException {
      return Response(400);
    } catch (_) {
      return Response(500);
    }
  }

  Future<Response> _writeFile(Request request, String filePath) async {
    final auth = authContextOf(request)!;
    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.startsWith('application/octet-stream')) {
      return _jsonError(415, '仅支持 application/octet-stream');
    }
    final declaredLength =
        int.tryParse(request.headers['content-length'] ?? '');
    if (declaredLength != null && declaredLength > maxFileSizeBytes) {
      return _jsonError(413, '文件超出大小限制');
    }

    final Uint8List data;
    try {
      final bytes = <int>[];
      await for (final chunk in request.read()) {
        bytes.addAll(chunk);
        if (bytes.length > maxFileSizeBytes) {
          return _jsonError(413, '文件超出大小限制');
        }
      }
      data = Uint8List.fromList(bytes);
    } catch (_) {
      return _jsonError(500, '无法写入文件');
    }

    try {
      final force =
          (request.headers['x-force-overwrite'] ?? '').toLowerCase() == 'true';
      final result = await storage.writeRawFile(
        auth.userId,
        filePath,
        data,
        ifMatch: request.headers['if-match'],
        ifNoneMatch: request.headers['if-none-match'],
        force: force,
      );
      if (result.status == RawFileWriteStatus.preconditionFailed) {
        final headers = result.metadata == null
            ? null
            : _metadataHeaders(result.metadata!, includeRepresentationHeaders: false);
        return Response(
          412,
          body: jsonEncode({'error': '文件版本冲突'}),
          headers: {
            ...?headers,
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      if (force) {
        await storage.logStorageAudit(
          userId: auth.userId,
          action: 'force-overwrite',
          filePath: filePath,
          details: auth.isApiKey ? 'api-key:${auth.keyId}' : 'jwt',
        );
      }
      wsHub.broadcastFileUpdate(
        auth.userId,
        request.headers['x-device-id'],
        filePath,
      );
      return Response(
        200,
        headers: _metadataHeaders(result.metadata!, includeRepresentationHeaders: false),
      );
    } on StoragePathException {
      return _jsonError(400, '无法写入文件');
    } catch (_) {
      return _jsonError(500, '无法写入文件');
    }
  }

  Future<Response> _deleteFile(Request request, String filePath) async {
    final auth = authContextOf(request)!;
    try {
      final force =
          (request.headers['x-force-overwrite'] ?? '').toLowerCase() == 'true';
      final result = await storage.deleteRawFile(
        auth.userId,
        filePath,
        ifMatch: request.headers['if-match'],
        force: force,
      );
      switch (result) {
        case RawFileDeleteStatus.notFound:
          return Response(404);
        case RawFileDeleteStatus.preconditionFailed:
          return _jsonError(412, '文件版本冲突');
        case RawFileDeleteStatus.deleted:
          if (force) {
            await storage.logStorageAudit(
              userId: auth.userId,
              action: 'force-delete',
              filePath: filePath,
            );
          }
          wsHub.broadcastFileUpdate(
            auth.userId,
            request.headers['x-device-id'],
            filePath,
          );
          return Response(204);
      }
    } on StoragePathException {
      return _jsonError(400, '无法删除文件');
    } catch (_) {
      return _jsonError(500, '无法删除文件');
    }
  }
}
