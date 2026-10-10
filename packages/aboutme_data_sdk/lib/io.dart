/// Aboutme 数据 SDK —— 服务端（IO）专用部分。
///
/// 依赖 dart:io，供 aboutme_server 等 Dart 服务端/CLI 使用；
/// Flutter 客户端（含 Web 构建）不要 import 此文件。
library;

export 'aboutme_data_sdk.dart';
export 'src/auth_store.dart';
export 'src/jwt_hs256.dart';
export 'src/legacy_encryption.dart';
export 'src/local_file_storage.dart';
export 'src/pbkdf2.dart';
export 'src/plugin_data_store.dart';
