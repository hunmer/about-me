import 'dart:io';

import 'package:aboutme/core/services/toast_service.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../../models/webview_card.dart';
import '../../webview_plugin.dart';
import 'webview_card_actions.dart';
import 'webview_card_form.dart';

/// 弹出卡片长按操作菜单
void showCardOptionsSheet(BuildContext screenContext, WebViewCard card) {
  SmoothBottomSheet.show(
    context: screenContext,
    backgroundColor: DSThemeBridge.resolve(screenContext).surface,
    builder: (context) => DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetActionRow(
                // DS 暂无"新窗口打开"图标,保留 Material
                icon: Icon(Icons.open_in_new, size: 20, color: theme.primary),
                label: 'webview_new_tab'.tr,
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  openCard(screenContext, card);
                },
              ),
              _SheetActionRow(
                icon: DsIcon(DsIconKind.pin, size: 20, color: theme.primary),
                label: card.isPinned ? 'webview_unpin'.tr : 'webview_pin'.tr,
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  WebViewPlugin.instance.cardManager.togglePinned(card.id);
                },
              ),
              _SheetActionRow(
                icon: DsIcon(DsIconKind.copy, size: 20, color: theme.primary),
                label: 'webview_copy_url'.tr,
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: card.url));
                  Toast.success('webview_url_copied'.tr);
                },
              ),
              // 同步复制（仅本地文件且有原始路径）
              if (card.type == CardType.localFile && card.sourcePath != null)
                _SheetActionRow(
                  icon: DsIcon(
                    DsIconKind.refresh,
                    size: 20,
                    color: theme.primary,
                  ),
                  label: '同步复制',
                  subtitle: '从原始路径重新复制文件',
                  theme: theme,
                  onTap: () {
                    Navigator.pop(context);
                    syncCopyCard(screenContext, card);
                  },
                ),
              _SheetActionRow(
                icon: DsIcon(DsIconKind.edit, size: 20, color: theme.primary),
                label: 'webview_edit_card'.tr,
                theme: theme,
                onTap: () {
                  Navigator.pop(context);
                  showEditCardSheet(screenContext, card);
                },
              ),
              _SheetActionRow(
                icon: DsIcon(DsIconKind.trash, size: 20, color: theme.danger),
                label: 'webview_delete_card'.tr,
                theme: theme,
                danger: true,
                onTap: () {
                  Navigator.pop(context);
                  confirmDeleteCard(screenContext, card);
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// 弹出删除卡片确认对话框
void confirmDeleteCard(BuildContext context, WebViewCard card) {
  showDSDialog(
    context: context,
    theme: DSThemeBridge.resolve(context),
    builder: (context) => DSThemeBridge(
      child: Builder(
        builder: (context) => DSDialog(
          title: 'webview_delete_card'.tr,
          message: 'webview_confirm_delete'.tr,
          confirmText: 'app_delete'.tr,
          cancelText: 'app_cancel'.tr,
          confirmVariant: DSButtonVariant.destructive,
          onConfirm: () async {
            await WebViewPlugin.instance.cardManager.deleteCard(card.id);
            Navigator.of(context).pop();
          },
        ),
      ),
    ),
  );
}

/// 同步复制卡片（从原始路径重新复制）
Future<void> syncCopyCard(BuildContext context, WebViewCard card) async {
  if (card.sourcePath == null) {
    Toast.error('错误：未保存原始路径');
    return;
  }

  // 检查原始路径是否存在
  final sourceDir = Directory(card.sourcePath!);
  if (!await sourceDir.exists()) {
    Toast.error('错误：原始路径不存在\n${card.sourcePath}');
    return;
  }

  // 检查是否存在 index.html
  final indexHtmlPath = path.join(card.sourcePath!, 'index.html');
  final indexHtmlFile = File(indexHtmlPath);
  if (!await indexHtmlFile.exists()) {
    Toast.error('错误：原始目录中未找到 index.html');
    return;
  }

  // 显示加载提示
  if (!context.mounted) return;
  Toast.info('正在同步复制...');

  try {
    // 从卡片 URL 中提取项目名称
    // 例如：./projectName/index.html -> projectName
    final uri = Uri.parse(card.url);
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (pathSegments.isEmpty) {
      throw Exception('无法从 URL 中提取项目名称');
    }

    final projectName = pathSegments.first;

    // 重新复制文件到 HTTP 服务器目录
    await WebViewPlugin.instance.copyToHttpServer(
      sourcePath: card.sourcePath!,
      projectName: projectName,
    );

    Toast.success('同步成功！文件已更新');
  } catch (e) {
    Toast.error('同步失败: $e');
  }
}

/// 卡片长按菜单行(果冻风格操作行)
class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final Widget icon;
  final String label;
  final String? subtitle;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: Pressable(
        onPressed: onTap,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return JellyBox(
            radius: theme.radii.lg,
            raised: false,
            color: pressed ? accent.mixWhite(0.9) : theme.surfaceAlt,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.md,
            ),
            child: Row(
              children: [
                icon,
                SizedBox(width: theme.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: DsTypography.body.copyWith(
                          color: danger ? theme.danger : theme.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: DsTypography.caption.copyWith(
                            color: theme.textSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
