import 'package:flutter/material.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/effort_slider.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import '../message_input_types.dart';

/// 输入框顶部的图标工具栏：底部抽屉工具栏（完整动作列表）的快捷方式行
///
/// 常用动作（上传图片/视频等）固定于此，点按即用，长按触发附加行为（如多选）。
class MessageInputQuickToolbar extends StatelessWidget {
  final List<MessageInputQuickAction> actions;

  /// 附加动作组（dots 与收起键盘贴右缘，其余并入左组显示）
  final List<MessageInputQuickAction> trailingActions;
  final int thinkingEffortIndex;
  final ValueChanged<int>? onThinkingEffortChanged;

  const MessageInputQuickToolbar({
    super.key,
    required this.actions,
    this.trailingActions = const [],
    this.thinkingEffortIndex = 1,
    this.onThinkingEffortChanged,
  });

  Future<void> _showThinkingEffort(BuildContext context) async {
    var selected = thinkingEffortIndex;
    await SmoothBottomSheet.showWithTitle<void>(
      context: context,
      title: '思考等级',
      showCloseButton: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: EffortSlider(
          initialIndex: selected,
          onChanged: (index) => selected = index,
        ),
      ),
    );
    if (selected != thinkingEffortIndex) {
      onThinkingEffortChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 仅 dots（更多操作）与收起键盘贴右缘，其余动作全部并入左组
    bool keepTrailing(MessageInputQuickAction action) =>
        action.icon == DsIconKind.dots ||
        action.icon == DsIconKind.keyboardHide;
    final actions = [
      ...this.actions,
      if (onThinkingEffortChanged != null)
        MessageInputQuickAction(
          icon: DsIconKind.speed,
          tooltip: '思考等级',
          onPressed: () => _showThinkingEffort(context),
        ),
      ...trailingActions.where((action) => !keepTrailing(action)),
    ];
    final trailingActions = [
      for (final action in this.trailingActions)
        if (keepTrailing(action)) action,
    ];
    if (actions.isEmpty && trailingActions.isEmpty) return const SizedBox();

    final theme = DSThemeBridge.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // 左右两组各自独立横向滚动：左组从左缘排布，右组贴右缘
      child: Row(
        children: [
          Expanded(
            child: actions.isEmpty
                ? const SizedBox()
                : SingleChildScrollView(
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
          ),
          if (actions.isNotEmpty && trailingActions.isNotEmpty)
            const SizedBox(width: 20),
          if (trailingActions.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, action) in trailingActions.indexed) ...[
                    if (index > 0) const SizedBox(width: 20),
                    _QuickToolbarItem(action: action, theme: theme),
                  ],
                ],
              ),
            ),
        ],
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
      builder: (context, states) {
        final pressed = states.contains(WidgetState.pressed);
        return AnimatedScale(
          scale: pressed && !disabled ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: JellyBox(
            width: 36,
            height: 36,
            radius: theme.radii.sm,
            color: pressed && !disabled
                ? theme.surfaceAlt.mixBlack(0.08)
                : theme.surfaceAlt,
            strokeColor: DsColors.transparent,
            alignment: Alignment.center,
            child: DsIcon(
              action.icon,
              size: 20,
              color: action.active
                  ? theme.primary
                  : disabled
                  ? theme.textSub.withValues(alpha: 0.5)
                  : theme.primaryText,
            ),
          ),
        );
      },
    );
  }
}
