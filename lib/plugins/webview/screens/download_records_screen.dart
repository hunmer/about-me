import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../services/browser_download_manager.dart';
import '../widgets/download_records_list.dart';

/// 下载管理页签：展示 WebView 触发的下载记录
class DownloadRecordsScreen extends StatelessWidget {
  const DownloadRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<BrowserDownloadManager>();
    final hasFinished = manager.records.any((r) => !r.isActive);

    return Scaffold(
      appBar: AppBar(
        title: Text('webview_download_manager_title'.tr),
        actions: [
          if (hasFinished)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'webview_download_clear'.tr,
              onPressed: () => manager.clearFinished(),
            ),
        ],
      ),
      body: const DownloadRecordsList(),
    );
  }
}
