/// Aboutme 存储服务器（Dart）。
///
/// 基于 aboutme_data_sdk 数据核心，开放与 nodejs server 兼容的 HTTP API：
/// - `/api/v1/auth/*`    注册 / 登录 / Token / API Key / 设备 / 访问控制
/// - `/api/v1/storage/*` 加密文件 CRUD（ETag 并发控制）+ 实时同步 WebSocket
///
/// 数据目录（DATA_DIR）与 nodejs 服务器完全兼容，可直接接管已有数据。
library;

export 'src/auth_middleware.dart';
export 'src/auth_routes.dart';
export 'src/config.dart';
export 'src/server_builder.dart';
export 'src/storage_routes.dart';
export 'src/ws_hub.dart';
