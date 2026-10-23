/// Aboutme 纯数据 SDK —— 可在所有平台（含 Web）使用的核心部分。
///
/// - 文件层：`StorageInterface` / `HttpStorage`（明文 + 条件写）/
///   `DataStore` / `AboutmeData`（本机直处理或远程 REST 自动路由）
/// - 业务层：统一插件服务（REST / MCP / 客户端同一套处理器）
/// - 服务端能力见 `aboutme_data_sdk/io.dart`。
library;

export 'src/data_store.dart';
export 'src/http_storage.dart';
export 'src/services/aboutme_data.dart';
export 'src/services/crud.dart';
export 'src/services/handler_factory.dart';
export 'src/services/invoker.dart';
export 'src/services/plugin_data.dart';
export 'src/services/persistent_plugin_backend.dart';
export 'src/services/query_store.dart';
export 'src/services/chat_facade.dart';
export 'src/services/diary_facade.dart';
export 'src/services/assets_facade.dart';
export 'src/services/asset_media_type.dart';
export 'src/services/asset_materialization.dart' show MaterializedAsset;
export 'package:shared_models/shared_models.dart' show AssetDto;
export 'src/services/data_config.dart';
export 'src/services/capabilities.dart';
export 'src/services/route_config.dart';
export 'src/services/types.dart';
export 'src/services/utils.dart';
export 'src/storage_config.dart';
export 'src/storage_errors.dart';
export 'src/legacy_write_policy.dart';
export 'src/storage_interface.dart';
