import 'dart:io';

import 'package:aboutme_server/src/config.dart';
import 'package:aboutme_server/src/server_builder.dart';
import 'package:shelf/shelf_io.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment();

  print('====================================');
  print('  Aboutme HTTP Storage Server (Dart)');
  print('====================================');
  print('');
  print('服务器配置:');
  print('  - 端口: ${config.port}');
  print('  - 数据目录: ${config.dataDir}');
  print('  - JWT 密钥: ${config.jwtSecret.substring(0, 8)}...');
  print('  - Token 有效期: ${config.tokenExpiryDays} 天');
  print('  - CORS: ${config.enableCors}');
  print('  - 管理员账号: ${config.adminUsername}');
  print('  - 允许注册: ${config.allowRegister}');
  print('');

  final handler = await buildServer(config);
  final server = await serve(handler, InternetAddress.anyIPv4, config.port);

  print('服务器启动成功!');
  print('  http://127.0.0.1:${server.port}');
  print('');
  print('可用端点:');
  print('  GET  /                      - 服务信息');
  print('  GET  /health                - 健康检查');
  print('  GET  /version               - 版本信息');
  print('  POST /api/v1/auth/register  - 用户注册');
  print('  POST /api/v1/auth/login     - 用户登录');
  print('  POST /api/v1/auth/api-keys  - 创建 API Key (需 Bearer Token)');
  print('  GET  /api/v1/storage/health - 存储连接检查 (需认证)');
  print('  *    /api/v1/storage/files  - 加密文件存储 (需认证)');
  print('  WS   /api/v1/storage/ws     - 文件实时同步 (需认证)');

  ProcessSignal.sigint.watch().listen((_) async {
    print('收到关闭信号，正在停止服务器...');
    await server.close();
    print('服务器已停止');
    exit(0);
  });
  // Windows 不支持 SIGTERM（SignalException errno=50），仅非 Windows 注册
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.close();
      exit(0);
    });
  }
}
