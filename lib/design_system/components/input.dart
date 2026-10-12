import 'package:flutter/cupertino.dart'
    show cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, materialTextSelectionHandleControls;
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 手绘输入框：基于 widgets 层 EditableText，样式完全自绘
///
/// 容器为 skribble 墨线描边 + 纯色实底（无阴影/渐变/高光）。
/// 文本选择手柄和上下文菜单会根据当前平台自适应。
class DSInput extends StatefulWidget {
  const DSInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.errorText,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.scrollPhysics,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.pill = false,
  });

  /// 单行搜索框便捷构造（胶囊形 + 放大镜前缀）
  const DSInput.search({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  }) : maxLines = 1,
       minLines = 1,
       maxLength = null,
       obscureText = false,
       keyboardType = TextInputType.text,
       textInputAction = TextInputAction.search,
       scrollPhysics = null,
       prefix = const _SearchPrefix(),
       suffix = null,
       pill = true;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final String? errorText;
  final bool enabled;
  final int? maxLines;
  final int? minLines;

  /// 最大字符数（超出截断，不显示计数）
  final int? maxLength;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// 透传给 EditableText 的滚动物理效果（多行内容超高转入内部滚动时生效）
  final ScrollPhysics? scrollPhysics;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;

  /// 胶囊形（搜索框）
  final bool pill;

  @override
  State<DSInput> createState() => _DSInputState();
}

class _DSInputState extends State<DSInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  TextEditingController? _internalController;
  FocusNode? _internalFocus;
  late final TextSelectionGestureDetectorBuilder _selectionGestureBuilder;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _effectiveFocus =>
      widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void dispose() {
    _internalController?.dispose();
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return LayoutBuilder(
      // 外部（如聊天输入框）用 ConstrainedBox 限定最大高度时，Column 会给
      // 子级无限高度导致溢出而非滚动；这里把有限的 max 高度转发给输入框
      // 本体，让 EditableText 像原生 TextField 一样转入内部滚动
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: DsTypography.caption.copyWith(color: theme.textSub),
            ),
            SizedBox(height: theme.spacing.xs),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: widget.maxLines == 1 ? 0 : theme.spacing.sm,
              ),
              constraints: BoxConstraints(
                minHeight: widget.maxLines == 1 ? 44 : 0,
              ),
              // 手绘装饰间无补间（RoughBoxDecoration 不支持 lerp），
              // 聚焦/失焦时描边与底色直接切换
              decoration: dsSketchDecoration(
                theme: theme,
                radius: widget.pill ? theme.radii.pill : theme.radii.lg,
                fillColor: widget.enabled
                    ? (hasError
                          ? theme.danger.mixWhite(0.92)
                          : _focused
                          ? theme.surfaceAlt
                          : theme.surface)
                    : theme.disabled,
                stroke: !widget.enabled
                    ? DsColors.transparent
                    : hasError
                    ? theme.danger
                    : _focused
                    ? theme.primary
                    : theme.textSub.withValues(alpha: 0.45),
                strokeWidth: 1.6,
              ),
              child: Row(
                crossAxisAlignment: widget.maxLines == 1
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.prefix != null)
                    Padding(
                      padding: EdgeInsets.only(right: theme.spacing.sm),
                      child: widget.prefix!,
                    ),
                  Expanded(
                    // 用 ValueListenable 驱动占位提示，避免每次输入都整树重建
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _effectiveController,
                      builder: (context, value, _) {
                        final showHint =
                            value.text.isEmpty && widget.hint != null;
                        return Stack(
                          children: [
                            // 占位提示（widgets 层的 EditableText 没有 decoration）
                            if (showHint)
                              Positioned(
                                left: 0,
                                top: 0,
                                child: Text(
                                  widget.hint!,
                                  maxLines: 1,
                                  style: DsTypography.body.copyWith(
                                    color: theme.textSub.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ),
                            IgnorePointer(
                              ignoring: !widget.enabled,
                              child: _selectionGestureBuilder
                                  .buildGestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    child: EditableText(
                                      key: editableTextKey,
                                      controller: _effectiveController,
                                      focusNode: _effectiveFocus,
                                      readOnly: !widget.enabled,
                                      showSelectionHandles: widget.enabled,
                                      selectionColor: theme.primary.withValues(
                                        alpha: 0.32,
                                      ),
                                      selectionControls: _selectionControls,
                                      contextMenuBuilder: _buildContextMenu,
                                      maxLines: widget.maxLines,
                                      minLines: widget.minLines,
                                      inputFormatters: widget.maxLength == null
                                          ? null
                                          : [
                                              LengthLimitingTextInputFormatter(
                                                widget.maxLength,
                                              ),
                                            ],
                                      obscureText: widget.obscureText,
                                      keyboardType: widget.keyboardType,
                                      textInputAction: widget.textInputAction,
                                      scrollPhysics: widget.scrollPhysics,
                                      onChanged: widget.onChanged,
                                      onSubmitted: widget.onSubmitted,
                                      cursorColor: theme.primary,
                                      backgroundCursorColor:
                                          DsColors.transparent,
                                      cursorWidth: 2,
                                      cursorRadius: const Radius.circular(2),
                                      autocorrect: false,
                                      style: DsTypography.body.copyWith(
                                        color: widget.enabled
                                            ? theme.text
                                            : theme.textSub,
                                      ),
                                      strutStyle: const StrutStyle(
                                        fontSize: 14,
                                        forceStrutHeight: true,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (widget.suffix != null)
                    Padding(
                      padding: EdgeInsets.only(left: theme.spacing.sm),
                      child: widget.suffix!,
                    ),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            SizedBox(height: theme.spacing.xs),
            Text(
              widget.errorText!,
              style: DsTypography.caption.copyWith(color: theme.danger),
            ),
          ],
        ],
      ),
    );
  }

  bool get _focused => _effectiveFocus.hasFocus;

  TextSelectionControls get _selectionControls {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? cupertinoTextSelectionHandleControls
        : materialTextSelectionHandleControls;
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    if (SystemContextMenu.isSupportedByField(editableTextState)) {
      return SystemContextMenu.editableText(
        editableTextState: editableTextState,
      );
    }
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectionGestureBuilder = TextSelectionGestureDetectorBuilder(
      delegate: this,
    );
    _effectiveFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }
}

/// 搜索框放大镜前缀
class _SearchPrefix extends StatelessWidget {
  const _SearchPrefix();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DsIcon(DsIconKind.search, size: 20, color: theme.textSub);
  }
}
