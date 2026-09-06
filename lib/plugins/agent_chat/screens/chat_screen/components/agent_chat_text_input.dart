import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = DSThemeBridge.resolve(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.surfaceAlt,
        borderRadius: borderRadius ?? theme.radii.pill,
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
    );
  }
}
