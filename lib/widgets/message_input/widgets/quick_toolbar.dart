import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import '../message_input_types.dart';

/// 输入框顶部的图标工具栏：底部抽屉工具栏（完整动作列表）的快捷方式行
///
/// 常用动作（上传图片/视频等）固定于此，点按即用，长按触发附加行为（如多选）。
class MessageInputQuickToolbar extends StatelessWidget {
  final List<MessageInputQuickAction> actions;

  const MessageInputQuickToolbar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox();

    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // 动作较多时窄屏横向滚动，避免溢出
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, action) in actions.indexed) ...[
              if (index > 0) const SizedBox(width: 20),
              _QuickToolbarItem(action: action, theme: theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickToolbarItem extends StatelessWidget {
  final MessageInputQuickAction action;
  final AppThemeData theme;

  const _QuickToolbarItem({required this.action, required this.theme});

  @override
  Widget build(BuildContext context) {
    final disabled = action.onPressed == null;
    return Pressable(
      onPressed: action.onPressed,
      onLongPress: action.onLongPress,
      semanticLabel: action.tooltip,
      builder: (context, states) => DsIcon(
        action.icon,
        size: 20,
        color: action.active
            ? theme.primary
            : disabled
            ? theme.textSub.withValues(alpha: 0.5)
            : theme.primaryText,
      ),
    );
  }
}
