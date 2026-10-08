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

  /// 是否卡片视图（果冻卡片布局），否则为列表视图
  final bool isCardView;

  const ChannelTile({
    super.key,
    required this.channel,
    this.onTap, // 改为可选
    this.onBeforeOpen, // 新增回调
    required this.onEdit,
    required this.onDelete,
    this.itemKey,
    this.isCardView = false,
  });

  String? get _draft => (channel.draft != null && channel.draft!.isNotEmpty)
      ? channel.draft
      : null;

  String get _subtitle =>
      _draft ?? channel.lastMessage?.content ?? 'chat_enterMessage'.tr;

  @override
  Widget build(BuildContext context) {
    return SwipeActionWrapper(
      key: ValueKey(channel.id),
      leadingActions: [SwipeActionPresets.edit(onTap: () => onEdit(channel))],
      trailingActions: [
        SwipeActionPresets.delete(onTap: () => onDelete(channel)),
      ],
      child: DSThemeBridge(
        // DS 组件内部取 AppTheme，需包桥
        child: isCardView ? _buildCard(context) : _buildListItem(context),
      ),
    );
  }

  /// 列表视图：果冻列表项
  Widget _buildListItem(BuildContext context) {
    final lastMessage = channel.lastMessage;
    return DSListItem(
      key: itemKey,
      title: channel.title,
      subtitle: _subtitle,
      leading: DSAvatar(
        color: channel.backgroundColor,
        child: Icon(channel.icon, color: Colors.white, size: 20),
      ),
      trailingText: _draft == null && lastMessage != null
          ? DateFormatter.formatDateTime(lastMessage.date, context)
          : null,
      trailing: _buildDraftBadge(context),
      onTap: () => _openChat(context),
    );
  }

  /// 卡片视图：半透明描边卡片，左上角半圆标志
  Widget _buildCard(BuildContext context) {
    final lastMessage = channel.lastMessage;
    return DSListItemCard(
      key: itemKey,
      title: channel.title,
      subtitle: _subtitle,
      iconColor: channel.backgroundColor,
      leading: Icon(channel.icon, color: Colors.white, size: 22),
      trailingText: _draft == null && lastMessage != null
          ? DateFormatter.formatDateTime(lastMessage.date, context)
          : null,
      trailing: _buildDraftBadge(context),
      onTap: () => _openChat(context),
    );
  }

  /// 草稿标记（红色文字）
  Widget? _buildDraftBadge(BuildContext context) {
    if (_draft == null) return null;
    return Text(
      'chat_draft'.tr,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontSize: 12,
      ),
    );
  }

  void _openChat(BuildContext context) {
    // 在打开之前执行回调（如设置当前频道）
    onBeforeOpen?.call();
    // 打开聊天页面
    NavigationHelper.openContainerWithHero(
      context,
      (context) => ChatScreen(channel: channel),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}
