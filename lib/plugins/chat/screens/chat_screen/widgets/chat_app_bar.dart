import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/chat_plugin.dart';
import 'package:aboutme/widgets/picker/image_picker_dialog.dart';

/// 聊天页顶部栏（自绘果冻风，替代 Material AppBar）
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Channel channel;
  final bool isMultiSelectMode;
  final int selectedCount;
  final VoidCallback onShowDatePicker;
  final VoidCallback onCopySelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onShowClearConfirmation;
  final VoidCallback onExitMultiSelect;
  final VoidCallback onEnterMultiSelect;

  const ChatAppBar({
    super.key,
    required this.channel,
    required this.isMultiSelectMode,
    required this.selectedCount,
    required this.onShowDatePicker,
    required this.onCopySelected,
    required this.onDeleteSelected,
    required this.onShowClearConfirmation,
    required this.onExitMultiSelect,
    required this.onEnterMultiSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final canPop = Navigator.of(context).canPop();

          return Material(
            color: theme.surface,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    // 返回 / 退出多选
                    if (isMultiSelectMode)
                      DSIconButton(
                        icon: DsIconKind.close,
                        size: 40,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: onExitMultiSelect,
                      )
                    else if (canPop)
                      DSIconButton(
                        icon: DsIconKind.chevronLeft,
                        size: 40,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    Expanded(
                      child: Text(
                        isMultiSelectMode
                            ? 'chat_selectedMessages'.trParams({
                              'count': selectedCount.toString(),
                            })
                            : channel.title,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.title.copyWith(color: theme.text),
                      ),
                    ),
                    if (isMultiSelectMode) ...[
                      DSIconButton(
                        icon: DsIconKind.copy,
                        size: 40,
                        color: theme.surfaceAlt,
                        iconColor: theme.textSub,
                        onPressed: onCopySelected,
                      ),
                      DSIconButton(
                        icon: DsIconKind.trash,
                        size: 40,
                        color: theme.danger,
                        iconColor: theme.onDanger,
                        onPressed: onDeleteSelected,
                      ),
                    ] else ...[
                      DSIconButton(
                        icon: DsIconKind.calendar,
                        size: 40,
                        onPressed: onShowDatePicker,
                      ),
                      _buildMenu(context, theme),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 更多操作气泡菜单
  Widget _buildMenu(BuildContext context, AppThemeData theme) {
    return DSPopover(
      width: 170,
      contentBuilder: (popoverContext, close) {
        final popoverTheme = DSThemeBridge.resolve(popoverContext);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MenuAction(
              icon: DsIconKind.check,
              label: 'chat_multiSelectMode'.tr,
              theme: popoverTheme,
              onTap: () {
                close();
                onEnterMultiSelect();
              },
            ),
            _MenuAction(
              icon: DsIconKind.trash,
              label: 'chat_clearMessages'.tr,
              theme: popoverTheme,
              danger: true,
              onTap: () {
                close();
                onShowClearConfirmation();
              },
            ),
            _MenuAction(
              icon: DsIconKind.image,
              label: 'chat_setBackground'.tr,
              theme: popoverTheme,
              onTap: () async {
                close();
                final result = await showDialog(
                  context: context,
                  builder:
                      (context) => ImagePickerDialog(
                        saveDirectory: path.join('chat', 'backgrounds'),
                        enableCrop: true,
                        cropAspectRatio: 9 / 16, // 竖屏比例
                      ),
                );
                if (result != null && result is Map<String, dynamic>) {
                  // 直接使用result中返回的url路径
                  if (result.containsKey('url') && result['url'] != null) {
                    // 更新频道背景
                    await ChatPlugin.instance.channelService
                        .updateChannelBackground(
                          channel.id,
                          result['url'], // 直接使用返回的url
                        );
                  }
                }
              },
            ),
          ],
        );
      },
      child: JellyBox(
        width: 40,
        height: 40,
        radius: theme.radii.md,
        color: theme.primary,
        child: Center(
          child: DsIcon(DsIconKind.more, size: 20, color: theme.onPrimary),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// 气泡菜单行
class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
    this.danger = false,
  });

  final DsIconKind icon;
  final String label;
  final AppThemeData theme;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? theme.danger : theme.text;
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: pressed ? theme.surfaceAlt : null,
            borderRadius: theme.radii.sm,
          ),
          child: Row(
            children: [
              DsIcon(icon, size: 16, color: accent),
              SizedBox(width: theme.spacing.sm),
              Text(label, style: DsTypography.caption.copyWith(color: accent)),
            ],
          ),
        );
      },
    );
  }
}
