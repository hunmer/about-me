import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// Agent Chat 与轻量聊天入口共用的文本输入区域。
class AgentChatTextInput extends StatelessWidget {
  const AgentChatTextInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.hintText = '输入消息...',
    this.suffixIcon,
    this.onSubmitted,
    this.textInputAction = TextInputAction.newline,
    this.backgroundColor,
    this.borderRadius,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String hintText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  /// 桌面端键盘处理：回车发送，Ctrl+回车换行。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        onSubmitted == null) {
      return KeyEventResult.ignored;
    }
    // 输入法组合中（如拼音未上屏），回车用于确认候选词，不拦截
    if (controller.value.composing != TextRange.empty) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      final selection = controller.selection;
      controller.value = controller.value.copyWith(
        text: controller.text.replaceRange(
          selection.start,
          selection.end,
          '\n',
        ),
        selection: TextSelection.collapsed(offset: selection.start + 1),
      );
    } else if (!HardwareKeyboard.instance.isShiftPressed) {
      onSubmitted!(controller.text);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    final isDesktop =
        UniversalPlatform.isMacOS ||
        UniversalPlatform.isWindows ||
        UniversalPlatform.isLinux;
    return Focus(
      onKeyEvent: isDesktop ? _handleKeyEvent : null,
      child: Container(
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: backgroundColor ?? theme.surfaceAlt,
        radius: borderRadius ?? theme.radii.pill,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: null,
        textInputAction: textInputAction,
        enabled: enabled,
        onSubmitted: onSubmitted,
        style: DsTypography.body.copyWith(color: theme.text),
        cursorColor: theme.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: DsTypography.body.copyWith(
            color: theme.textSub.withValues(alpha: 0.75),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
      ),
    );
  }
}
