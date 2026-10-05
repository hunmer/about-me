import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 系统代理探测缓存（应用内代理开关变化不频繁，短 TTL 缓存避免每次请求都调 scutil）
String? _cachedProxyUrl;
DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

/// 探测系统代理地址（返回 host:port）
///
/// 优先级：环境变量(HTTP_PROXY/HTTPS_PROXY) > macOS 系统代理设置(scutil)。
/// 桌面 App 从 Finder 启动时没有代理环境变量，必须读系统设置；
/// Dart 无内置 API，macOS 上通过 scutil 子进程获取。
Future<String?> detectSystemProxyUrl() async {
  // 1. 环境变量（终端启动 / CI 场景）
  final envProxy =
      Platform.environment['HTTPS_PROXY'] ??
      Platform.environment['https_proxy'] ??
      Platform.environment['HTTP_PROXY'] ??
      Platform.environment['http_proxy'];
  if (envProxy != null && envProxy.isNotEmpty) {
    return _normalizeProxy(envProxy);
  }

  // 2. macOS 系统代理（缓存 30 秒）
  if (Platform.isMacOS) {
    final fresh = DateTime.now().difference(_cachedAt) < const Duration(seconds: 30);
    if (fresh) return _cachedProxyUrl;
    try {
      final result = await Process.run('scutil', ['--proxy']);
      _cachedProxyUrl = _parseScutilProxy(result.stdout.toString());
      _cachedAt = DateTime.now();
      return _cachedProxyUrl;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// 归一化代理地址为 host:port
String? _normalizeProxy(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final uri = trimmed.contains('://')
      ? Uri.tryParse(trimmed)
      : Uri.tryParse('http://$trimmed');
  if (uri == null || uri.host.isEmpty) return null;
  return '${uri.host}:${uri.port}';
}

/// 解析 scutil --proxy 输出，返回 HTTPS(优先)/HTTP 代理的 host:port
String? _parseScutilProxy(String output) {
  String? readBool(String key) =>
      RegExp('$key\\s*:\\s*(\\d)').firstMatch(output)?.group(1);

  // 注意 key 拼写：HTTPSProxy 不包含 HTTPProxy 子串，正则互不误匹配
  final useHttps = readBool('HTTPSEnable') == '1';
  final prefix = useHttps ? 'HTTPS' : (readBool('HTTPEnable') == '1' ? 'HTTP' : null);
  if (prefix == null) return null;

  final host =
      RegExp('$prefix' 'Proxy\\s*:\\s*(\\S+)').firstMatch(output)?.group(1);
  final port =
      RegExp('$prefix' 'Port\\s*:\\s*(\\d+)').firstMatch(output)?.group(1);
  if (host == null || host.isEmpty || port == null) return null;
  return '$host:$port';
}

/// 创建 http.Client，支持系统代理
///
/// [proxyUrl] 显式代理地址（host:port 或 http://host:port），
/// 为空时自动探测（环境变量 → macOS 系统设置）
Future<http.Client> createClientWithSystemProxy({String? proxyUrl}) async {
  // 创建一个自定义的 HttpClient 来明确应用代理设置
  final httpClient = HttpClient();

  final effective =
      (proxyUrl != null && proxyUrl.isNotEmpty)
          ? _normalizeProxy(proxyUrl)
          : await detectSystemProxyUrl();

  if (effective != null) {
    try {
      final parts = effective.split(':');
      final host = parts[0];
      final port = int.tryParse(parts.length > 1 ? parts[1] : '80') ?? 80;

      httpClient.findProxy = (uri) {
        return 'PROXY $host:$port';
      };
      debugPrint('[Network] 使用代理: $host:$port');
    } catch (e) {
      debugPrint('Error setting proxy: $e');
    }
  }

  // 允许自签名证书，如果代理使用自签名证书
  httpClient.badCertificateCallback = (cert, host, port) => true;

  // 创建一个基于自定义HttpClient的http客户端
  return IOClient(httpClient);
}
