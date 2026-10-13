import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/design_system/design_system.dart';

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode keyboardListenerFocusNode;
  final Function(String) onChanged;
  final Function(KeyEvent) onKeyEvent;
  final Widget? suffix;

  const InputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.keyboardListenerFocusNode,
    required this.onChanged,
    required this.onKeyEvent,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    // 获取屏幕高度，用于计算输入框的最大高度
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight / 2; // 最大高度为屏幕高度的一半

    return KeyboardListener(
      focusNode: keyboardListenerFocusNode,
      onKeyEvent:
          UniversalPlatform.isMacOS ||
                  UniversalPlatform.isWindows ||
                  UniversalPlatform.isLinux
              ? onKeyEvent
              : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight, // 限制最大高度
        ),
        child: DSInput(
          controller: controller,
          focusNode: focusNode,
          hint: 'chat_enterMessage'.tr,
          onChanged: onChanged,
          maxLines: null, // 允许多行
          minLines: 1, // 最少显示1行
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          scrollPhysics: const ClampingScrollPhysics(), // 内容超高时转入内部滚动
          suffix: suffix,
        ),
      ),
    );
  }
}
