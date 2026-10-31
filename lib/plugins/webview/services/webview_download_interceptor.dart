import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'download_flow.dart';

/// Windows 下载事件拦截器
///
/// flutter_inappwebview_windows 0.6.0 原生端没有实现 onDownloadStartRequest 事件，
/// WebView2 会直接弹出默认下载 UI。此拦截器通过 Chrome DevTools 协议接管：
/// 1. 在 Response 阶段暂停 Document 请求（Fetch.enable + requestStage: Response）；
/// 2. 若响应头 Content-Disposition 带 attachment（或 Content-Type 非 HTML 文档），
///    调 Fetch.failRequest 阻断 WebView2 默认下载，转走应用内下载流程；
/// 3. 其余请求调 Fetch.continueRequest 放行。
///
/// 插件自身的 shouldOverrideUrlLoading 使用 Request 阶段暂停，与本拦截器（Response
/// 阶段）互补不冲突；Request 阶段事件直接忽略（由原生 delegate 处理）。
class WebviewDownloadInterceptor {
  static const _eventName = 'Fetch.requestPaused';

  /// 附加到控制器（仅 Windows 生效），重复调用安全
  static Future<void> attach(
    InAppWebViewController controller,
    BuildContext Function() contextGetter,
  ) async {
    if (!Platform.isWindows) return;
    try {
      await controller.addDevToolsProtocolEventListener(
        eventName: _eventName,
        callback: (data) => _onRequestPaused(controller, data, contextGetter),
      );
      await controller.callDevToolsProtocolMethod(
        methodName: 'Fetch.enable',
        parameters: {
          'patterns': [
            {'resourceType': 'Document', 'requestStage': 'Response'},
          ],
        },
      );
      debugPrint('[WebviewDownloadInterceptor] Fetch Response 阶段拦截已启用');
    } catch (e) {
      debugPrint('[WebviewDownloadInterceptor] 启用失败: $e');
    }
  }

  static Future<void> _onRequestPaused(
    InAppWebViewController controller,
    dynamic data,
    BuildContext Function() contextGetter,
  ) async {
    try {
      if (data is! Map) return;
      final requestId = data['requestId'];
      if (requestId is! String || requestId.isEmpty) return;

      // Request 阶段事件由插件自身（shouldOverrideUrlLoading）或原生流程处理
      if ((data['responseStatusCode'] as num?) == null) return;

      final isDownload = _detectDownload(data);
      if (!isDownload) {
        await _continueRequest(controller, requestId);
        return;
      }

      // 阻断 WebView2 默认下载，转走应用内下载流程
      await controller.callDevToolsProtocolMethod(
        methodName: 'Fetch.failRequest',
        parameters: {'requestId': requestId, 'errorReason': 'Aborted'},
      );

      final url = _requestUrl(data);
      final cd = _headerValue(data, 'content-disposition');
      if (url == null) return;
      final context = contextGetter();
      unawaited(runBrowserDownloadFlow(
        context,
        url: url,
        contentDisposition: cd,
      ));
    } catch (e) {
      debugPrint('[WebviewDownloadInterceptor] 处理暂停请求失败: $e');
    }
  }

  /// 判断响应是否为文件下载：优先 Content-Disposition attachment，其次非 HTML 文档类型
  static bool _detectDownload(Map data) {
    final cd = _headerValue(data, 'content-disposition');
    if (cd != null && cd.toLowerCase().contains('attachment')) return true;

    final mime = _headerValue(data, 'content-type')?.toLowerCase() ?? '';
    if (mime.isEmpty) return false;
    // 常见可直接渲染的文档类型之外视为下载
    const renderable = ['text/html', 'text/plain', 'application/xhtml+xml'];
    return !renderable.any((t) => mime.startsWith(t));
  }

  static Future<void> _continueRequest(
    InAppWebViewController controller,
    String requestId,
  ) async {
    try {
      await controller.callDevToolsProtocolMethod(
        methodName: 'Fetch.continueRequest',
        parameters: {'requestId': requestId},
      );
    } catch (e) {
      // 请求可能已被其他流程处理，忽略
      debugPrint('[WebviewDownloadInterceptor] continueRequest: $e');
    }
  }

  static String? _headerValue(Map data, String name) {
    final headers = data['responseHeaders'];
    if (headers is! List) return null;
    for (final h in headers) {
      if (h is Map &&
          (h['name'] as String?)?.toLowerCase() == name) {
        return h['value'] as String?;
      }
    }
    return null;
  }

  static String? _requestUrl(Map data) {
    final request = data['request'];
    if (request is Map) return request['url'] as String?;
    return null;
  }
}
