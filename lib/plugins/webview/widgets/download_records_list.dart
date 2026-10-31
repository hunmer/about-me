import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../services/browser_download_manager.dart';

/// 下载记录列表（供下载管理页签与底部弹层共用）
class DownloadRecordsList extends StatelessWidget {
  const DownloadRecordsList({super.key});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _statusText(BrowserDownloadRecord record) {
    switch (record.status) {
      case BrowserDownloadStatus.downloading:
        return 'webview_download_downloading'.tr;
      case BrowserDownloadStatus.completed:
        return 'webview_download_success'.tr;
      case BrowserDownloadStatus.failed:
        return 'webview_download_failed'.tr;
      case BrowserDownloadStatus.cancelled:
        return 'webview_download_cancelled'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<BrowserDownloadManager>();
    final records = manager.records;

    if (records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('webview_download_empty'.tr)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(
          leading: const Icon(Icons.download),
          title: Text(
            record.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_statusText(record)} · ${_formatBytes(record.receivedBytes)}'
                '${record.totalBytes != null ? ' / ${_formatBytes(record.totalBytes!)}' : ''}',
              ),
              if (record.isActive)
                LinearProgressIndicator(
                  value: record.progress >= 0 ? record.progress : null,
                  minHeight: 3,
                ),
            ],
          ),
          trailing: record.isActive
              ? TextButton(
                  onPressed: () => manager.cancel(record.id),
                  child: Text('webview_download_cancel'.tr),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => manager.removeRecord(record.id),
                ),
        );
      },
    );
  }
}
