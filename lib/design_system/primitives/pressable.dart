import 'package:flutter/widgets.dart';

/// 行为原语：可按压 + 可聚焦 + 可悬停，无任何样式
///
/// - 状态收集进 [WidgetStatesController]，通过 [builder] 暴露给外部换肤
/// - 键盘 Enter/Space 触发 [onPressed]（依赖 WidgetsApp.defaultShortcuts）
/// - 语义层标记为按钮
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    this.child,
    this.onPressed,
    this.onLongPress,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.cursor = SystemMouseCursors.click,
    this.builder,
    this.semanticLabel,
  });

  /// 静态子组件；使用 [builder] 时可不传
  final Widget? child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor cursor;

  /// 根据控件状态自定义外观；为 null 时直接渲染 [child]
  final Widget Function(BuildContext context, Set<WidgetState> states)?
      builder;

  /// 无障碍标签
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  late final WidgetStatesController _controller;
  FocusNode? _internalFocus;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocus ??= FocusNode());

  bool get _enabled => widget.enabled && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _controller = WidgetStatesController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _internalFocus?.dispose();
    super.dispose();
  }

  void _setPressed(bool value) =>
      _controller.update(WidgetState.pressed, value);

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      enabled: _enabled,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      mouseCursor: widget.cursor,
      onShowHoverHighlight: (v) => _controller.update(WidgetState.hovered, v),
      onShowFocusHighlight: (v) => _controller.update(WidgetState.focused, v),
      shortcuts: WidgetsApp.defaultShortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (_enabled) widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final states = {
            if (!_enabled) WidgetState.disabled,
            ..._controller.value,
          };

          Widget child = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => _setPressed(true) : null,
            onTapUp: _enabled ? (_) => _setPressed(false) : null,
            onTapCancel: _enabled ? () => _setPressed(false) : null,
            onTap: _enabled ? widget.onPressed : null,
            onLongPress: _enabled ? widget.onLongPress : null,
            child: widget.builder?.call(context, states) ??
                widget.child ??
                const SizedBox.shrink(),
          );

          if (widget.semanticLabel != null) {
            child = Semantics(
              button: true,
              label: widget.semanticLabel,
              child: child,
            );
          }
          return child;
        },
      ),
    );
  }
}
