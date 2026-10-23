import 'dart:convert';
import 'dart:io';

import 'package:aboutme_data_sdk/io.dart'
    show AuthStore, jsIsoDateTime, LocalPluginBackend, PluginInvoker;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

/// 插件系统管理路由 `/api/v1/system/*`（需管理员）。
///
/// 说明：nodejs 服务器的插件系统依赖动态 require JS 插件，
/// Dart 服务器不支持执行此类插件，因此保留注册表/配置的读写能力，
/// 安装/卸载等操作返回 501。
class SystemApi {
  SystemApi({required this.auth, required this.dataDir})
      : _backend = LocalPluginBackend(dataDir, source: 'server'),
        _invoker = PluginInvoker();

  final AuthStore auth;
  final String dataDir;
  final LocalPluginBackend _backend;
  final PluginInvoker _invoker;

  /// 把 dataDir 顶层旧配置文件一次性搬入 system/ 分区（SDK 只认分区路径）。
  /// 分区文件已存在时保留分区版本；顶层无旧文件则跳过。
  Future<void> ensureMigrated() async {
    for (final name in ['plugin_registry.json', 'store_config.json']) {
      final legacy = File(p.join(dataDir, name));
      final target = File(p.join(dataDir, 'system', name));
      if (await target.exists() || !await legacy.exists()) continue;
      await target.parent.create(recursive: true);
      await legacy.rename(target.path);
    }
  }

  static const _mimeType = <String, String>{
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
  };

  Response _json(int status, Map<String, dynamic> body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _error(int status, String message) => _json(status, {
    'success': false,
    'error': message,
    'timestamp': jsIsoDateTime(DateTime.now()),
  });

  Future<String?> _requireAdmin(Request request) async {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    final userId = auth.getUserIdFromToken(header.substring(7));
    if (userId == null) return null;
    final user = await auth.findUserById(userId);
    return (user != null && user.isAdmin) ? userId : null;
  }

  Map<String, dynamic> get _emptyRegistry =>
      {'plugins': <String, dynamic>{}, 'updatedAt': ''};

  Future<Map<String, dynamic>> _readRegistry() async {
    final result = await _invoker.invokeAction(
      _backend,
      'system',
      'getPluginRegistry',
      const {},
    );
    if (result['success'] != true) return _emptyRegistry;
    final data = result['data'];
    return data is Map<String, dynamic> ? data : _emptyRegistry;
  }

  Handler get handler => (request) async {
    final admin = await _requireAdmin(request);
    if (admin == null) return _error(403, '需要管理员权限');

    final path = request.url.path; // 相对 /api/v1/system/
    final method = request.method;

    // GET /plugins - 已安装插件列表（读注册表）
    if (path == 'plugins' && method == 'GET') {
      final registry = await _readRegistry();
      final plugins =
          (registry['plugins'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .values
              .toList();
      return _json(200, {
        'success': true,
        'plugins': plugins,
        'total': plugins.length,
        'timestamp': jsIsoDateTime(DateTime.now()),
      });
    }

    // GET /plugins/config - 商店配置
    if (path == 'plugins/config' && method == 'GET') {
      final config = await _readStoreConfig();
      return _json(200, {
        'success': true,
        'config': config,
        'timestamp': jsIsoDateTime(DateTime.now()),
      });
    }

    // PUT /plugins/config - 更新商店配置（SDK 合并命令）
    if (path == 'plugins/config' && method == 'PUT') {
      final body = jsonDecode(await request.readAsString());
      if (body is! Map<String, dynamic>) {
        return _error(400, '请求体必须为 JSON 对象');
      }
      final result = await _invoker.invokeAction(
        _backend,
        'system',
        'updateStoreConfig',
        body,
      );
      if (result['success'] != true) {
        return _error(500, result['error']?.toString() ?? '配置更新失败');
      }
      return _json(200, {
        'success': true,
        'config': result['data'],
        'message': '配置已更新',
        'timestamp': jsIsoDateTime(DateTime.now()),
      });
    }

    // GET /plugins/store - 插件商店列表（代理拉取外部商店）
    if (path == 'plugins/store' && method == 'GET') {
      final config = await _readStoreConfig();
      final storeUrl = config['storeURL'] as String? ?? '';
      if (storeUrl.isEmpty) {
        return _json(200, {
          'success': true,
          'plugins': <dynamic>[],
          'sourceURL': '',
          'total': 0,
          'timestamp': jsIsoDateTime(DateTime.now()),
        });
      }
      try {
        final client = HttpClient()
          ..findProxy = HttpClient.findProxyFromEnvironment;
        final response = await client
            .getUrl(Uri.parse(storeUrl))
            .then((r) => r.close())
            .timeout(const Duration(seconds: 10));
        final body = jsonDecode(await response.transform(utf8.decoder).join());
        client.close();
        final plugins = body is List ? body : <dynamic>[];
        return _json(200, {
          'success': true,
          'plugins': plugins,
          'sourceURL': storeUrl,
          'total': plugins.length,
          'timestamp': jsIsoDateTime(DateTime.now()),
        });
      } catch (e) {
        return _error(500, e.toString());
      }
    }

    // 安装/卸载/启用/禁用等操作：Dart 服务器不支持执行 nodejs 插件
    return _error(501, 'Dart 服务器不支持 nodejs 插件系统（插件钩子无法执行）');
  };

  Map<String, dynamic> get _emptyStoreConfig => {'storeURL': '', 'lastSyncAt': ''};

  Future<Map<String, dynamic>> _readStoreConfig() async {
    final result = await _invoker.invokeAction(
      _backend,
      'system',
      'getStoreConfig',
      const {},
    );
    if (result['success'] != true) return _emptyStoreConfig;
    final data = result['data'];
    return data is Map<String, dynamic> ? data : _emptyStoreConfig;
  }
}

/// 管理界面静态资源服务（SPA，未配置目录时返回提示）。
class AdminStatic {
  AdminStatic(this.adminDir);

  final String? adminDir;

  Handler get handler => (request) async {
    final dir = adminDir;
    if (dir == null || !await Directory(dir).exists()) {
      return Response.ok(
        'Aboutme Server (Dart) 运行中。管理界面未配置：请将 admin-vue 构建产物'
        '放入该目录或设置 ADMIN_DIR 环境变量。',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }

    final decoded = Uri.decodeComponent(request.url.path);
    if (decoded.split('/').contains('..')) {
      return Response.forbidden('Invalid path');
    }

    final file = File(p.normalize(p.join(dir, decoded)));
    final stat = await file.exists() ? await file.stat() : null;
    if (stat != null && stat.type == FileSystemEntityType.file) {
      return _serveFile(file);
    }
    // SPA 回退到 index.html
    final index = File(p.join(dir, 'index.html'));
    if (await index.exists()) {
      return _serveFile(index);
    }
    return Response.notFound('File not found');
  };

  Response _serveFile(File file) {
    final type = SystemApi._mimeType[p.extension(file.path).toLowerCase()] ??
        'application/octet-stream';
    return Response.ok(
      file.openRead(),
      headers: {'content-type': type, 'cache-control': 'no-cache'},
    );
  }
}
