import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/navigation/navigation_helper.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/plugins/chat/models/channel.dart';
import 'package:aboutme/plugins/chat/screens/chat_screen/chat_screen.dart';
import 'package:aboutme/plugins/chat/utils/date_formatter.dart';
import 'package:aboutme/widgets/swipe_action/index.dart';

class ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback? onTap; // 改为可选，因为 OpenContainer 会处理导航
  final VoidCallback? onBeforeOpen; // 在打开页面之前的回调（如设置当前频道）
  final Function(Channel) onEdit;
  final Function(Channel) onDelete;
  final Key? itemKey;

  const ChannelTile({
    super.key,
    required this.channel,
    this.onTap, // 改为可选
    this.onBeforeOpen, // 新增回调
    required this.onEdit,
    required this.onDelete,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    final draft = channel.draft;
    final lastMessage = channel.lastMessage;

    return SwipeActionWrapper(
      key: ValueKey(channel.id),
      leadingActions: [
        SwipeActionPresets.edit(
          onTap: () => onEdit(channel),
        ),
      ],
      trailingActions: [
        SwipeActionPresets.delete(
          onTap: () => onDelete(channel),
        ),
      ],
      child: DSThemeBridge(
        // DS 组件内部取 AppTheme，需包桥
        child: DSListItem(
          key: itemKey,
          title: channel.title,
          subtitle:
              (draft != null && draft.isNotEmpty)
                  ? draft
                  : lastMessage?.content ?? 'chat_enterMessage'.tr,
          leading: DSAvatar(
            color: channel.backgroundColor,
            child: Icon(channel.icon, color: Colors.white, size: 20),
          ),
          trailingText:
              (draft == null || draft.isEmpty) && lastMessage != null
                  ? DateFormatter.formatDateTime(lastMessage.date, context)
                  : null,
          trailing:
              (draft != null && draft.isNotEmpty)
                  ? Text(
                      'chat_draft'.tr,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    )
                  : null,
          onTap: () {
            // 在打开之前执行回调（如设置当前频道）
            onBeforeOpen?.call();
            // 打开聊天页面
            NavigationHelper.openContainerWithHero(
              context,
              (context) => ChatScreen(channel: channel),
              transitionDuration: const Duration(milliseconds: 400),
            );
          },
        ),
      ),
    );
  }
}
