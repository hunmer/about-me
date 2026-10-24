import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'config.dart';

/// 插件 API 调试页（纯静态 HTML 文件），挂载于 `GET /debug`。
///
/// 每次请求现读磁盘：编辑 `debug/index.html` 后刷新浏览器即生效，
/// 无需重启服务器。目录解析与 admin 一致：`DATA_DIR/debug` → 当前目录 `debug`。
Response serveDebugPage(ServerConfig config) {
  final candidates = [
    p.join(config.dataDir, 'debug', 'index.html'),
    p.join(Directory.current.path, 'debug', 'index.html'),
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return Response.ok(
        file.readAsStringSync(),
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }
  }
  return Response(404, body: '调试页文件不存在: ${candidates.join(' | ')}');
}
