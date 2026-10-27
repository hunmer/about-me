import 'dart:convert';

import 'package:aboutme/core/utils/network.dart';

/// 图源共享上下文：配置读取 + 走代理的 GET + 错误体提取
///
/// 由 ImageSearchService 在每次搜索时创建，传给各 provider。
class ImageSearchContext {
  ImageSearchContext(this.config);

  final Map<String, dynamic> config;

  /// 读字符串配置（trim，空值返回 ''）
  String cfg(String key) => ((config[key] ?? '').toString()).trim();

  /// 读数值配置（容错解析，失败回退 fallback）
  int configNum(String key, int fallback) {
    final v = config[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  /// 发送 GET 请求（走系统代理或显式代理），body 自动 JSON 解析
  Future<Map<String, dynamic>> getText(
    String url, {
    Map<String, String>? headers,
  }) async {
    final proxy = cfg('proxy');
    final client = await createClientWithSystemProxy(
      proxyUrl: proxy.isEmpty ? null : proxy,
    );
    try {
      final resp = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));
      dynamic body;
      try {
        body = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
      } catch (_) {
        body = utf8.decode(resp.bodyBytes, allowMalformed: true);
      }
      return {
        'statusCode': resp.statusCode,
        'body': body,
        'headers': resp.headers,
      };
    } finally {
      client.close();
    }
  }

  /// 提取错误详情（兼容 JSON 与纯文本错误体），截断到 200 字符
  String errorDetail(dynamic body) {
    String raw;
    if (body is Map) {
      final errors = body['errors'];
      raw = (errors is List && errors.isNotEmpty)
          ? errors.first.toString()
          : (body['error'] ?? jsonEncode(body)).toString();
    } else {
      raw = body?.toString() ?? '';
    }
    return raw.length > 200 ? raw.substring(0, 200) : raw;
  }
}
