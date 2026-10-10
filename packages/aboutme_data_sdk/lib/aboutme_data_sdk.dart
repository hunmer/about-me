/// Aboutme 纯数据 SDK —— 可在所有平台（含 Web）使用的核心部分。
///
/// 包含：存储接口、远端 HTTP 存储、后端配置与纯 Dart 数据管理门面。
/// 服务端专用能力（本地文件存储、认证数据）见 `aboutme_data_sdk/io.dart`。
library;

export 'src/data_store.dart';
export 'src/http_storage.dart';
export 'src/storage_config.dart';
export 'src/storage_errors.dart';
export 'src/storage_interface.dart';
