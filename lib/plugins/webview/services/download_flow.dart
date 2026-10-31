import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:aboutme/core/services/toast_service.dart';
import '../webview_plugin.dart';
import 'browser_download_manager.dart';

/// 从下载请求中提取默认文件名
///
/// 优先级：suggestedFilename > Content-Disposition（RFC 5987 filename* 优先，
/// 其次 quoted filename）> URL 最后一段路径 > "download"
String extractDownloadFileName({
  required String url,
  String? suggestedFilename,
  String? contentDisposition,
}) {
  // 1. WebView 自带建议文件名
  final suggested = suggestedFilename?.trim();
  if (suggested != null && suggested.isNotEmpty) return suggested;

  // 2. 解析 Content-Disposition
  final cd = contentDisposition;
  if (cd != null && cd.isNotEmpty) {
    // filename*=UTF-8''%E6%96%87%E4%BB%B6.zip（RFC 5987）
    final star = RegExp(
      r"filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)",
    ).firstMatch(cd);
    if (star != null) {
      String? decoded;
      try {
        decoded = Uri.decodeComponent(star.group(1)!.trim());
      } catch (_) {}
      if (decoded != null && decoded.isNotEmpty) return decoded;
    }
    // filename="xxx" 或 filename=xxx
    final plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
    ).firstMatch(cd);
    if (plain != null) {
      final name = plain.group(1)!.trim();
      if (name.isNotEmpty) return name;
    }
  }

  // 3. URL 最后一段路径
  try {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return Uri.decodeComponent(segments.last);
    }
  } catch (_) {}

  return 'download';
}

/// 弹出文件名编辑对话框，返回用户输入的文件名（取消返回 null）
Future<String?> showDownloadNameDialog(
  BuildContext context,
  String defaultName,
) {
  final nameController = TextEditingController(text: defaultName);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('webview_download_title'.tr),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'webview_download_file_name'.tr,
          hintText: defaultName,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('webview_download_cancel'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, nameController.text),
          child: Text('webview_download_save'.tr),
        ),
      ],
    ),
  );
}

/// 完整下载流程（浏览器页与嵌入式 WebView 共用）：
/// 文件名对话框 → 选目录 → 经 BrowserDownloadManager 下载并弹进度框 → toast 结果
Future<void> runBrowserDownloadFlow(
  BuildContext context, {
  required String url,
  String? suggestedFilename,
  String? contentDisposition,
}) async {
  final defaultName = extractDownloadFileName(
    url: url,
    suggestedFilename: suggestedFilename,
    contentDisposition: contentDisposition,
  );

  final fileName = await showDownloadNameDialog(context, defaultName);
  if (fileName == null || fileName.trim().isEmpty) return;

  // 选择保存目录
  final directory = await FilePicker.platform.getDirectoryPath(
    lockParentWindow: true,
  );
  if (directory == null) return;

  final savePath = '$directory${io.Platform.pathSeparator}${fileName.trim()}';
  if (!context.mounted) return;

  final manager = WebViewPlugin.instance.browserDownloadManager;
  final record = manager.startDownload(
    url: url,
    fileName: fileName.trim(),
    savePath: savePath,
  );

  // 显示进度对话框，并记录其路由以便精确关闭
  final dialogRoute = DialogRoute(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final current = manager.getRecord(record.id);
        final progress =
            current == null || current.progress < 0 ? null : current.progress;
        return AlertDialog(
          title: Text('webview_download_downloading'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fileName.trim(),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => manager.cancel(record.id),
              child: Text('webview_download_cancel'.tr),
            ),
          ],
        );
      },
    ),
  );
  Navigator.of(context).push(dialogRoute);

  // 等待下载结束并提示结果
  await manager.waitForDone(record.id);
  final status = manager.getRecord(record.id)?.status;
  if (status == BrowserDownloadStatus.completed) {
    ToastService.instance.showToast(
      'webview_download_success'.tr,
      type: ToastType.success,
    );
  } else if (status == BrowserDownloadStatus.failed) {
    ToastService.instance.showToast(
      'webview_download_failed'.tr,
      type: ToastType.error,
    );
  }
  if (dialogRoute.isActive) {
    Navigator.of(context).removeRoute(dialogRoute);
  }
}
