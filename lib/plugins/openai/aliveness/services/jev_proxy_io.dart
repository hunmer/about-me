import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// 给 Dio 配置 http 代理（dart:io HttpClient.findProxy）。
/// 传 null/空字符串恢复直连；返回解析后的 host:port（失败返回 null）。
void applyJevProxy(Dio dio, String? proxy) {
  final target = _parseProxy(proxy);
  if (target == null) {
    // 恢复默认直连 adapter（可能此前被设置了代理）
    dio.httpClientAdapter = IOHttpClientAdapter();
    return;
  }
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) => 'PROXY $target';
      return client;
    },
  );
}

/// 解析代理地址为 `host:port`；非法/不支持时打印原因并返回 null（直连）。
String? _parseProxy(String? input) {
  final text = input?.trim() ?? '';
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.startsWith('socks')) {
    debugPrint('[Live2D][Jev] 不支持 SOCKS 代理（dart:io 限制），已忽略：$text');
    return null;
  }
  if (lower.startsWith('https://')) {
    debugPrint(
      '[Live2D][Jev] 不支持 HTTPS 代理，请填写 http 代理端口'
      '（如 http://127.0.0.1:7890），已忽略：$text',
    );
    return null;
  }
  var hostPort = lower.startsWith('http://') ? text.substring(7) : text;
  if (hostPort.contains('@')) {
    debugPrint('[Live2D][Jev] 代理认证暂不支持，请使用免认证本地代理：$text');
    return null;
  }
  final uri = Uri.tryParse('http://$hostPort');
  if (uri == null || uri.host.isEmpty || !hostPort.contains(':')) {
    debugPrint('[Live2D][Jev] 代理地址格式应为 host:port，已忽略：$text');
    return null;
  }
  return '${uri.host}:${uri.port}';
}
