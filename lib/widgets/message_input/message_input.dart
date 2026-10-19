import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'message_input_types.dart';
import 'widgets/input_field.dart';
import 'widgets/quick_toolbar.dart';
import 'widgets/send_button.dart';

export 'message_input_types.dart';

/// 通用消息输入框（chat / agent_chat 共用）
///
/// 结构：header 附加区 → 顶部图标工具栏（底部抽屉动作的快捷方式，
/// 固定图片/视频等常用项）→ 输入行（"+"抽屉入口 / 输入框 / 语音位 / 发送）。
/// 业务差异（发送编排、文件管理、命令模式等）由调用方通过回调和插槽注入。
class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool enabled;

  /// 文本变化回调（保存草稿、命令检测等）
  final ValueChanged<String>? onChanged;

  /// 顶部图标工具栏快捷动作（空列表则隐藏该行）
  final List<MessageInputQuickAction> quickActions;

  /// "+"按钮回调：打开完整的底部抽屉动作列表（null 隐藏按钮）
  final VoidCallback? onOpenActionsDrawer;

  /// 输入框上方附加内容（待发送文件预览、命令选择器、搜索结果等）
  final Widget? header;

  /// 输入框内嵌后缀（表情、语音、Token 统计等）
  final Widget? inputSuffix;

  /// 输入行中位于输入框之后的按钮（长按录音等）
  final Widget? voiceButton;

  /// 自定义发送按钮（null 时用默认发送按钮）
  final Widget? sendButton;

  /// 发送回调：发送按钮与桌面端回车触发；null 时禁用发送
  final VoidCallback? onSend;

  /// 自定义键盘事件处理（覆盖默认的回车发送 / Ctrl+回车换行）
  final Function(KeyEvent)? onKeyEvent;

  /// 容器风格：false 悬浮圆角卡片（chat 列表浮层）；true 素描面板 + 底部安全区
  final bool useSketchPanel;

  const MessageInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.enabled = true,
    this.onChanged,
    this.quickActions = const [],
    this.onOpenActionsDrawer,
    this.header,
    this.inputSuffix,
    this.voiceButton,
    this.sendButton,
    this.onSend,
    this.onKeyEvent,
    this.useSketchPanel = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late FocusNode _focusNode;
  final FocusNode _keyboardListenerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  /// 默认桌面键盘处理：回车发送、Ctrl+回车换行；输入法组合中（如拼音未上屏）不拦截
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.enter ||
        widget.onSend == null) {
      return KeyEventResult.ignored;
    }
    if (widget.controller.value.composing != TextRange.empty) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      final controller = widget.controller;
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
      widget.onSend!();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          final body = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 输入框上方附加区（待发送预览、命令选择器、搜索结果等）
              if (widget.header != null) widget.header!,

              // 顶部图标工具栏：底部抽屉动作的快捷方式
              MessageInputQuickToolbar(actions: widget.quickActions),

              // 输入行（素描面板风格带内边距，悬浮卡片风格紧贴内容区）
              Padding(
                padding: widget.useSketchPanel
                    ? const EdgeInsets.all(12)
                    : EdgeInsets.zero,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // "+"按钮：打开完整底部抽屉动作列表
                    if (widget.onOpenActionsDrawer != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                        child: DSIconButton(
                          icon: DsIconKind.plus,
                          color: theme.surfaceAlt,
                          iconColor: theme.textSub,
                          onPressed: widget.onOpenActionsDrawer,
                        ),
                      ),

                    // 文本输入框（表情/语音/统计等内嵌为右侧后缀）
                    Expanded(
                      child: InputField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardListenerFocusNode: _keyboardListenerFocusNode,
                        hintText: widget.hintText,
                        enabled: widget.enabled,
                        suffix: widget.inputSuffix,
                        onChanged: widget.onChanged ?? (_) {},
                        onKeyEvent: widget.onKeyEvent ?? _handleKeyEvent,
                      ),
                    ),

                    // 语音位（长按录音等）
                    if (widget.voiceButton != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: widget.voiceButton,
                      ),

                    // 发送按钮
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8.0,
                        right: 8.0,
                        bottom: 4.0,
                      ),
                      child:
                          widget.sendButton ??
                          SendButton(onPressed: widget.onSend),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (widget.useSketchPanel) {
            // 素描面板风格：纸底 + 排线 + 墨线框（design.md §9.1，去柔影）
            return SafeArea(
              top: false,
              left: false,
              right: false,
              child: DsSketchPanel(
                theme: theme,
                radius: theme.radii.xl,
                child: body,
              ),
            );
          }

          // 悬浮输入框风格：与屏幕底部保持间距（含底部安全边距），
          // 圆角卡片浮于列表之上
          return Container(
            margin: EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              bottom: 8.0 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: theme.shadows.soft,
            ),
            child: body,
          );
        },
      ),
    );
  }
}
