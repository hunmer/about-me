import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';

/// 频道操作抽屉
///
/// 长按频道弹出：编辑、固定、封存、删除
class ChannelActionSheet extends StatelessWidget {
  final Channel channel;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  const ChannelActionSheet({
    super.key,
    required this.channel,
    required this.onEdit,
    required this.onTogglePin,
    required this.onToggleArchive,
    required this.onDelete,
  });

  /// 显示频道操作抽屉
  static Future<void> show({
    required BuildContext context,
    required Channel channel,
    required VoidCallback onEdit,
    required VoidCallback onTogglePin,
    required VoidCallback onToggleArchive,
    required VoidCallback onDelete,
  }) async {
    await Navigator.of(context).push(
      ModalSheetRoute(
        swipeDismissible: true,
        builder: (context) => Sheet(
          child: ChannelActionSheet(
            channel: channel,
            onEdit: onEdit,
            onTogglePin: onTogglePin,
            onToggleArchive: onToggleArchive,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      // Sheet 路由在主题树之外，先过桥再取令牌
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);

          return Container(
            decoration: BoxDecoration(
              color: theme.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽指示器
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.textSub.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 标题
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      channel.title,
                      style: DsTypography.title.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 编辑选项
                  DSSheetAction(
                    icon: DsIconKind.edit,
                    label: 'chat_editChannel'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),

                  // 固定/取消固定
                  DSSheetAction(
                    icon: DsIconKind.pin,
                    label: channel.isPinned
                        ? 'chat_unpinChannel'.tr
                        : 'chat_pinChannel'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onTogglePin();
                    },
                  ),

                  // 封存/取消封存
                  DSSheetAction(
                    icon: DsIconKind.archive,
                    label: channel.isArchived
                        ? 'chat_unarchiveChannel'.tr
                        : 'chat_archiveChannel'.tr,
                    onTap: () {
                      Navigator.pop(context);
                      onToggleArchive();
                    },
                  ),

                  // 删除选项
                  DSSheetAction(
                    icon: DsIconKind.trash,
                    label: 'chat_deleteChannel'.tr,
                    destructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                  ),

                  // 取消按钮
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DSButton(
                      label: 'chat_cancel'.tr,
                      variant: DSButtonVariant.outline,
                      expand: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
