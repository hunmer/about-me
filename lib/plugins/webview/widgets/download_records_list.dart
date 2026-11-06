import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/hand_drawn_list_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../services/browser_download_manager.dart';

/// 下载记录列表（供下载管理页签与浏览器底部弹层共用）
///
/// [stickyTilt] 为 true（页签主体内容列表）时用手绘便签列表并做
/// 底部导航避让（design.md §11，倾斜 key 取记录 id）；弹层内的
/// 列表禁止便签化（§11.4），保持默认 false。
class DownloadRecordsList extends StatelessWidget {
  const DownloadRecordsList({super.key, this.stickyTilt = false});

  /// 是否启用便签化（仅页面主体列表开启）
  final bool stickyTilt;

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

  /// 状态着色（全部走主题色，禁止硬编码）：
  /// 下载中主色 / 完成成功色 / 失败危险色 / 取消弱化色
  Color _statusColor(AppThemeData theme, BrowserDownloadStatus status) {
    switch (status) {
      case BrowserDownloadStatus.downloading:
        return theme.primary;
      case BrowserDownloadStatus.completed:
        return theme.success;
      case BrowserDownloadStatus.failed:
        return theme.danger;
      case BrowserDownloadStatus.cancelled:
        return theme.textSub;
    }
  }

  /// 副标题：状态 · 已收字节[/总字节]
  String _subtitleOf(BrowserDownloadRecord record) {
    final total = record.totalBytes;
    return '${_statusText(record)} · ${_formatBytes(record.receivedBytes)}'
        '${total != null ? ' / ${_formatBytes(total)}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    // 自包主题桥：弹层等无 AppTheme 祖先的环境也能安全使用 DS 组件
    // （已存在相同亮暗 AppTheme 时直接透传，零开销）
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final manager = context.watch<BrowserDownloadManager>();
          final records = manager.records;

          if (records.isEmpty) {
            return DSEmptyState(
              icon: DsIconKind.download,
              title: 'webview_download_empty'.tr,
            );
          }

          Widget itemBuilder(BuildContext context, int index) =>
              _buildRecordItem(context, theme, manager, records[index]);

          // 页签主体列表：便签化 + 底部导航避让（宿主页 extendBody）
          if (stickyTilt) {
            return HandDrawnListView(
              itemCount: records.length,
              // 倾斜 key 用数据稳定 id，禁止 index（design.md §11）
              tiltKeyOf: (index) => records[index].id,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.lg,
                vertical: theme.spacing.sm,
              ).copyWith(bottom: MediaQuery.paddingOf(context).bottom + 16),
              separatorBuilder: (_, _) => SizedBox(height: theme.spacing.lg),
              itemBuilder: itemBuilder,
            );
          }

          // 弹层共用路径：不倾斜，shrinkWrap 适应内容由 sheet 滚动
          return ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.lg,
              vertical: theme.spacing.sm,
            ),
            itemCount: records.length,
            separatorBuilder: (_, _) => SizedBox(height: theme.spacing.md),
            itemBuilder: itemBuilder,
          );
        },
      ),
    );
  }

  /// 单条记录：手绘列表卡片 + 进行中条目下方附手绘进度条
  Widget _buildRecordItem(
    BuildContext context,
    AppThemeData theme,
    BrowserDownloadManager manager,
    BrowserDownloadRecord record,
  ) {
    final statusColor = _statusColor(theme, record.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DSListItemCard(
          title: record.fileName,
          icon: DsIconKind.download,
          // 卡片底色与墨线描边随状态走主题色
          iconColor: statusColor,
          subtitle: _subtitleOf(record),
          trailing: record.isActive
              ? DSButton(
                  label: 'webview_download_cancel'.tr,
                  size: DSButtonSize.sm,
                  onPressed: () => manager.cancel(record.id),
                )
              : DSIconButton(
                  icon: DsIconKind.trash,
                  size: 32,
                  color: theme.surfaceAlt,
                  iconColor: theme.danger,
                  tooltip: 'webview_download_delete'.tr,
                  onPressed: () => manager.removeRecord(record.id),
                ),
        ),
        // 进行中的条目：卡片正下方手绘进度条（未知总大小显示空轨道）
        if (record.isActive) ...[
          SizedBox(height: theme.spacing.xs),
          DSLinearProgress(
            value: record.progress >= 0 ? record.progress : 0,
            height: 6,
            color: statusColor,
          ),
        ],
      ],
    );
  }
}
