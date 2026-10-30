import 'package:dio/dio.dart';

import 'jev_proxy_stub.dart'
    if (dart.library.io) 'jev_proxy_io.dart' as platform;

/// 给 Jev 决策请求的 Dio 应用 http 代理。
/// 传 null/空恢复直连；Web 平台为存根实现（忽略代理）。
/// 格式支持 `host:port` 或 `http://host:port`；SOCKS/带认证代理不支持。
void applyJevProxy(Dio dio, String? proxy) =>
    platform.applyJevProxy(dio, proxy);
