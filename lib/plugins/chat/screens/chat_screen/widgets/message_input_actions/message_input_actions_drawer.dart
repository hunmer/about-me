import 'package:flutter/widgets.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'types.dart';

/// 消息输入动作抽屉组件
class MessageInputActionsDrawer extends StatelessWidget {
  final List<MessageInputAction> actions;
  final OnFileSelected? onFileSelected;
  final OnSendMessage? onSendMessage;

  const MessageInputActionsDrawer({
    super.key,
    required this.actions,
    this.onFileSelected,
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    // 计算网格高度:根据 actions 数量动态计算
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(color: theme.surface),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.6, // 最大高度为屏幕的 60%
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics:
                  actions.length > 8
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 24.0,
              ),
              itemCount: actions.length,
              itemBuilder:
                  (context, index) => _buildActionItem(context, actions[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, MessageInputAction action) {
    final theme = DSThemeBridge.resolve(context);
    return Pressable(
      onPressed: () {
        Navigator.pop(context); // 关闭抽屉
        action.onTap();
      },
      onLongPress:
          action.onLongPress != null
              ? () {
                Navigator.pop(context); // 关闭抽屉
                action.onLongPress!();
              }
              : null,
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60.0,
              height: 60.0,
              decoration: BoxDecoration(
                color: pressed ? theme.primary.mixWhite(0.8) : theme.surfaceAlt,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Center(
                child: DsIcon(action.icon, size: 28.0, color: theme.primary),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              action.title,
              style: DsTypography.body.copyWith(color: theme.textSub),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
