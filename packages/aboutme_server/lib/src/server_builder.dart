import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/io.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth_middleware.dart';
import 'auth_routes.dart';
import 'config.dart';
import 'fcm_service.dart';
import 'mcp/mcp_endpoint.dart';
import 'plugin_routes.dart';
import 'storage_routes.dart';
import 'system_routes.dart';
import 'ws_hub.dart';
import 'user_data_runtimes.dart';

/// 组装完整服务器 Handler：
/// /health、/version、/api/v1/auth、/api/v1/storage（含 WS）、
/// /api/v1/plugins/*、/api/v1/system/*、/mcp、/admin 静态资源。
Future<Handler> buildServer(ServerConfig config) async {
  final storage = LocalFileStorage(config.dataDir);
  await storage.initialize();

  final auth = AuthStore(
    dataDir: config.dataDir,
    jwtSecret: config.jwtSecret,
    tokenExpiryDays: config.tokenExpiryDays,
    adminUsername: config.adminUsername,
    adminPassword: config.adminPassword,
  );
  await auth.initialize();

  final wsHub = StorageWsHub(
    verifyToken: (token) async {
      final result = await auth.verifyApiKey(token);
      if (result == null) return null;
      return AuthContext(
        userId: result.userId,
        keyId: result.keyId,
        keyName: result.keyName,
        isApiKey: true,
      );
    },
  );

  final fcm = FcmService(
    dataDir: config.dataDir,
    serviceAccountPath: config.fcmServiceAccount,
  );

  final storageApi = StorageApi(
    storage: storage,
    wsHub: wsHub,
    maxFileSizeBytes: config.maxStorageFileSizeBytes,
    rateLimitPerMinute: config.storageRateLimitPerMinute,
  );

  final authApi = AuthApi(
    auth: auth,
    storage: storage,
    allowRegister: config.allowRegister,
    fcm: fcm,
  );

  final runtimes = UserDataRuntimes(storage: storage, wsHub: wsHub);
  final pluginApi = PluginApi(storage: storage, wsHub: wsHub, runtimes: runtimes);
  final mcpApi = McpApi(storage: storage, wsHub: wsHub, runtimes: runtimes);
  final systemApi = SystemApi(auth: auth, dataDir: config.dataDir);
  await systemApi.ensureMigrated();
  final adminStatic = AdminStatic(_resolveAdminDir(config));

  final router = Router(notFoundHandler: _notFound);
  router.get('/', (Request request) {
    if (_resolveAdminDir(config) != null) {
      return Response.movedPermanently('/admin/');
    }
    return Response.ok(
      jsonEncode({
        'name': 'Aboutme HTTP Storage Server (Dart)',
        'version': '1.0.0',
        'status': 'running',
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  router.get(
    '/health',
    (Request request) => Response.ok(
      jsonEncode({'status': 'healthy', 'timestamp': jsIsoDateTimeNow()}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
  router.get(
    '/version',
    (Request request) => Response.ok(
      jsonEncode({
        'version': '1.0.0',
        'name': 'Aboutme HTTP Storage Server (Dart)',
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );

  // WebSocket（文件实时同步）
  router.get('/api/v1/storage/ws', wsHub.handler);

  // 认证路由（无需中间件，各端点自行校验 Bearer Token）
  router.mount('/api/v1/auth/', authApi.router.call);

  // 存储路由（日志 + 认证 + 限流）
  router.mount(
    '/api/v1/storage/',
    Pipeline()
        .addMiddleware(_requestLogger(config.enableLogging))
        .addMiddleware(authMiddleware(auth))
        .addMiddleware(storageApi.rateLimiter)
        .addHandler(storageApi.router.call),
  );

  // 插件 REST 路由（认证）
  router.mount(
    '/api/v1/plugins/',
    Pipeline()
        .addMiddleware(authMiddleware(auth))
        .addHandler(pluginApi.handler),
  );

  // 插件系统管理（管理员，注册表/商店配置只读 + 501 说明）
  router.mount('/api/v1/system/', systemApi.handler);

  // MCP 端点（认证）
  router.mount(
    '/mcp',
    Pipeline().addMiddleware(authMiddleware(auth)).addHandler(mcpApi.handler),
  );

  // 管理界面静态资源（SPA）
  router.mount('/admin/', adminStatic.handler);

  return Pipeline().addMiddleware(_cors(config)).addHandler(router.call);
}

/// 管理界面目录解析：ADMIN_DIR 环境变量 → DATA_DIR/admin →
/// 当前目录/admin（admin-vue 构建产物，npm run build 于 admin-vue/）。
String? _resolveAdminDir(ServerConfig config) {
  final candidates = [
    config.adminDirOverride,
    p.join(config.dataDir, 'admin'),
    p.join(Directory.current.path, 'admin'),
  ];
  for (final candidate in candidates) {
    if (candidate != null &&
        Directory(candidate).existsSync() &&
        File(p.join(candidate, 'index.html')).existsSync()) {
      return p.canonicalize(candidate);
    }
  }
  return null;
}

String jsIsoDateTimeNow() => jsIsoDateTime(DateTime.now());

Response _notFound(Request request) => Response(
  404,
  body: jsonEncode({'error': 'not_found'}),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 请求日志（与 nodejs `method path` 一致）。
Middleware _requestLogger(bool enabled) {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      if (enabled) {
        print(
          '${DateTime.now().toIso8601String()} '
          '${request.method} ${request.url.path}',
        );
      }
      return response;
    };
  };
}

/// CORS 中间件：允许的请求/响应头与 nodejs 服务器一致。
Middleware _cors(ServerConfig config) {
  const allowedHeaders = [
    'Origin',
    'Content-Type',
    'Authorization',
    'X-API-Key',
    'X-Device-ID',
    'If-Match',
    'If-None-Match',
    'X-Force-Overwrite',
    'Mcp-Session-Id',
    'Mcp-Protocol-Version',
    'Last-Event-ID',
    'X-Aboutme-Query-Encoding',
  ];
  const exposedHeaders = ['ETag', 'Content-Length', 'Last-Modified'];

  return (innerHandler) {
    return (request) async {
      final origin = request.headers['origin'];
      Map<String, String> corsHeaders = {};
      if (config.enableCors && origin != null && origin.isNotEmpty) {
        final allow =
            config.corsAllowAll || config.corsOrigins.contains(origin);
        if (allow) {
          corsHeaders = {
            'access-control-allow-origin': config.corsAllowAll ? '*' : origin,
            'access-control-allow-methods':
                'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS',
            'access-control-allow-headers': allowedHeaders.join(', '),
            'access-control-expose-headers': exposedHeaders.join(', '),
          };
        }
      }

      if (request.method == 'OPTIONS') {
        return Response(204, headers: corsHeaders);
      }

      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}
