import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/utils/platform_utils.dart';
import 'message_input_types.dart';
import 'widgets/input_field.dart';
import 'widgets/quick_toolbar.dart';
import 'widgets/send_button.dart';

export 'message_input_types.dart';

/// 通用消息输入框（chat / agent_chat 共用）
///
/// 结构：header 附加区 → 顶部图标工具栏（底部抽屉动作的快捷方式，
/// 固定图片/视频等常用项，最右 dots 打开抽屉）→ 输入行（输入框 / 语音位 / 发送）。
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

  /// 工具栏右侧动作组（贴右缘排布）
  final List<MessageInputQuickAction> trailingQuickActions;

  final int thinkingEffortIndex;
  final ValueChanged<int>? onThinkingEffortChanged;

  /// 工具栏最右 dots 按钮回调：打开完整的底部抽屉动作列表（null 隐藏按钮）
  final VoidCallback? onOpenActionsDrawer;

  /// 输入框上方附加内容（待发送文件预览、命令选择器、搜索结果等）
  final Widget? header;

  /// 输入框内嵌后缀（语音、Token 统计等）
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

  /// 素描面板是否画墨线描边（false = 仅纸底/排线，无边框）
  final bool showPanelStroke;

  /// 素描面板描边用虚线（需 [showPanelStroke] 为 true）
  final bool dashedPanelStroke;

  const MessageInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.enabled = true,
    this.onChanged,
    this.quickActions = const [],
    this.trailingQuickActions = const [],
    this.thinkingEffortIndex = 1,
    this.onThinkingEffortChanged,
    this.onOpenActionsDrawer,
    this.header,
    this.inputSuffix,
    this.voiceButton,
    this.sendButton,
    this.onSend,
    this.onKeyEvent,
    this.useSketchPanel = false,
    this.showPanelStroke = true,
    this.dashedPanelStroke = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  late FocusNode _focusNode;
  final FocusNode _keyboardListenerFocusNode = FocusNode();

  /// 移动端键盘是否弹出（以输入框持有焦点为准），控制"收起键盘"按钮显隐
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _keyboardVisible = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant MessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChanged);
      _keyboardVisible = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final visible = _focusNode.hasFocus;
    if (visible != _keyboardVisible) {
      setState(() => _keyboardVisible = visible);
    }
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
          // 移动端键盘弹出时，右组末尾追加"收起键盘"动作；
          // drawer 入口（dots）固定追加在最右
          var trailingActions = widget.trailingQuickActions;
          if (PlatformUtils.isMobile && _keyboardVisible) {
            trailingActions = [
              ...trailingActions,
              MessageInputQuickAction(
                icon: DsIconKind.keyboardHide,
                tooltip: '收起键盘',
                onPressed: () => _focusNode.unfocus(),
              ),
            ];
          }
          if (widget.onOpenActionsDrawer != null) {
            trailingActions = [
              ...trailingActions,
              MessageInputQuickAction(
                icon: DsIconKind.dots,
                tooltip: '更多操作',
                onPressed: widget.onOpenActionsDrawer,
              ),
            ];
          }
          final body = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 输入框上方附加区（待发送预览、命令选择器、搜索结果等）
              if (widget.header != null) widget.header!,

              // 顶部图标工具栏：底部抽屉动作的快捷方式（左组 + 右组）
              MessageInputQuickToolbar(
                actions: widget.quickActions,
                trailingActions: trailingActions,
                thinkingEffortIndex: widget.thinkingEffortIndex,
                onThinkingEffortChanged: widget.onThinkingEffortChanged,
              ),

              // 输入行（素描面板风格带内边距，悬浮卡片风格仅留底部间距）
              Padding(
                padding: widget.useSketchPanel
                    ? const EdgeInsets.all(12)
                    : const EdgeInsets.only(bottom: 8),
                child: Row(
                  // 输入框与两侧图标垂直居中（多行增高时图标随中心线上浮）
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 文本输入框（语音/统计等内嵌为右侧后缀）
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
                      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
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
                stroke: widget.showPanelStroke
                    ? null
                    : DsColors.transparent,
                dashedStroke: widget.showPanelStroke && widget.dashedPanelStroke,
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
