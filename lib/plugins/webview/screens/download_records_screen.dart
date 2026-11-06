import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/super_cupertino_navigation_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../services/browser_download_manager.dart';
import '../widgets/download_records_list.dart';
import 'components/webview_add_download_form.dart';

/// 下载管理页签：展示 WebView 触发与手动添加的下载记录
///
/// 内嵌于 WebViewMainScreen 宿主页（同一路由嵌套第二个 wrapper，
/// 必须关闭 hero 过渡，避免与卡片页签导航栏的 hero tag 冲突，design.md §1）
class DownloadRecordsScreen extends StatelessWidget {
  const DownloadRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<BrowserDownloadManager>();
    final hasFinished = manager.records.any((r) => !r.isActive);

    return DSThemeBridge(
      child: SuperCupertinoNavigationWrapper(
        title: Text('webview_download_manager_title'.tr),
        transitionBetweenRoutes: false,
        // SuperAppBar 的 actions 经 Overlay 渲染，脱离页面主题桥，
        // DS 按钮需自带 DSThemeBridge 提供 AppTheme
        actions: [
          // 手动添加下载
          DSThemeBridge(
            child: Builder(
              builder: (context) {
                final theme = DSThemeBridge.resolve(context);
                return DSIconButton(
                  icon: DsIconKind.plus,
                  size: 36,
                  color: theme.primary,
                  tooltip: 'webview_download_add'.tr,
                  onPressed: () => showAddDownloadSheet(context),
                );
              },
            ),
          ),
          // 清空已结束记录（无已结束记录时隐藏）
          if (hasFinished)
            DSThemeBridge(
              child: Builder(
                builder: (context) {
                  final theme = DSThemeBridge.resolve(context);
                  return DSIconButton(
                    icon: DsIconKind.trash,
                    size: 36,
                    color: theme.surfaceAlt,
                    iconColor: theme.danger,
                    tooltip: 'webview_download_clear'.tr,
                    onPressed: () => manager.clearFinished(),
                  );
                },
              ),
            ),
        ],
        // 页签主体内容列表：便签化（design.md §11），列表内部自处理
        // 底部避让（宿主页 extendBody）
        body: const DownloadRecordsList(stickyTilt: true),
      ),
    );
  }
}
