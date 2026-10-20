import 'dart:io' show Process;

import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/image_utils.dart';

/// 输入框上方的待发送内容预览
///
/// 文件区：横向缩略图条（图片显示缩略图，其余类型显示图标卡），
/// 右上 × 逐个移除，点击缩略图用系统程序打开；
/// 智能体区：统一入口 chip（点击弹出自动回复设置弹层，
/// 含总开关 / 指定 agent / 上下文长度，与频道菜单共用）。
class MetadataDisplay extends StatelessWidget {
  /// 待发送文件列表（元素为 {fileInfo, senderInfo}，支持多个）
  final List<Map<String, dynamic>> selectedFiles;

  /// 智能体统一入口的显示文案（空串表示不显示）
  final String agentsEntryLabel;

  /// 点击智能体统一入口：打开自动回复设置弹层
  final Function() onAgentsEntryTap;

  final Function(int) onFileRemoveAt;

  const MetadataDisplay({
    super.key,
    required this.selectedFiles,
    required this.agentsEntryLabel,
    required this.onAgentsEntryTap,
    required this.onFileRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    final showAgentsEntry = agentsEntryLabel.isNotEmpty;
    if (selectedFiles.isEmpty && !showAgentsEntry) {
      // 没有文件和智能体时不显示任何内容
      return const SizedBox();
    }

    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件缩略图条（横滑）
                if (selectedFiles.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) =>
                          _buildFileThumb(context, theme, index),
                    ),
                  ),
                if (selectedFiles.isNotEmpty && showAgentsEntry)
                  const SizedBox(height: 8),

                // 智能体统一入口：点击打开自动回复设置弹层
                if (showAgentsEntry)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onAgentsEntryTap,
                        child: DSChip(
                          icon: DsIconKind.bot,
                          label: agentsEntryLabel,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 单个待发送文件的缩略图：图片显示预览，其余类型显示图标卡；
  /// 点击主体用系统程序打开，右上 × 移除
  Widget _buildFileThumb(
    BuildContext context,
    AppThemeData theme,
    int index,
  ) {
    final fileInfo =
        selectedFiles[index]['fileInfo'] as Map<String, dynamic>? ?? {};
    final path = fileInfo['path'] as String? ?? '';
    final type = fileInfo['type'] as String? ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openFile(path),
          child: ClipRRect(
            borderRadius: theme.radii.sm,
            child: SizedBox(
              width: 52,
              height: 52,
              child: _buildFilePreview(theme, path, type),
            ),
          ),
        ),
        // 右上取消图标
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => onFileRemoveAt(index),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.text,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: DsIcon(DsIconKind.close, size: 10, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 文件预览内容：图片用缩略图（支持 './' 相对路径与 http URL），其余按类型图标
  Widget _buildFilePreview(AppThemeData theme, String path, String type) {
    if (type == 'image' && path.isNotEmpty) {
      return Image(
        image: ImageUtils.createImageProvider(path),
        fit: BoxFit.cover,
        errorBuilder:
            (_, _, _) => _typeFallback(theme, DsIconKind.image),
      );
    }
    final icon = switch (type) {
      'video' => DsIconKind.video,
      'audio' => DsIconKind.mic,
      'image' => DsIconKind.image,
      _ => DsIconKind.copy,
    };
    return _typeFallback(theme, icon);
  }

  Widget _typeFallback(AppThemeData theme, DsIconKind icon) {
    return Container(
      color: theme.primary.mixWhite(0.85),
      child: Center(
        child: DsIcon(icon, size: 20, color: theme.primary),
      ),
    );
  }

  /// 用系统程序打开文件（桌面端）
  void _openFile(String path) {
    if (path.isEmpty) return;
    if (UniversalPlatform.isWindows) {
      Process.run('explorer', [path]);
    } else if (UniversalPlatform.isMacOS) {
      Process.run('open', [path]);
    } else if (UniversalPlatform.isLinux) {
      Process.run('xdg-open', [path]);
    }
  }
}
