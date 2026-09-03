import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 果冻输入框：基于 widgets 层 EditableText，样式完全自绘
///
/// 说明：未接入系统文本选择手柄（那部分实现属于 Material/Cupertino），
/// 桌面/Web 端键盘选择、光标、复制粘贴快捷键均可正常使用。
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
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
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
  })  : maxLines = 1,
        minLines = 1,
        obscureText = false,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
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
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;

  /// 胶囊形（搜索框）
  final bool pill;

  @override
  State<DSInput> createState() => _DSInputState();
}

class _DSInputState extends State<DSInput> {
  TextEditingController? _internalController;
  FocusNode? _internalFocus;

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

    return Column(
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: widget.maxLines == 1 ? 0 : theme.spacing.sm,
          ),
          constraints: BoxConstraints(minHeight: widget.maxLines == 1 ? 44 : 0),
          decoration: BoxDecoration(
            color: widget.enabled
                ? (hasError
                    ? theme.danger.mixWhite(0.92)
                    : _focused
                        ? theme.primary.mixWhite(0.94)
                        : theme.surface)
                : theme.disabled,
            borderRadius: widget.pill ? theme.radii.pill : theme.radii.lg,
            border: Border.all(
              color: !widget.enabled
                  ? DsColors.transparent
                  : hasError
                      ? theme.danger
                      : _focused
                          ? theme.primary
                          : theme.textSub.withValues(alpha: 0.45),
              width: 1.6,
            ),
            boxShadow: widget.enabled ? theme.shadows.soft : null,
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
                                color:
                                    theme.textSub.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        IgnorePointer(
                          ignoring: !widget.enabled,
                          child: EditableText(
                            controller: _effectiveController,
                            focusNode: _effectiveFocus,
                            readOnly: !widget.enabled,
                            maxLines: widget.maxLines,
                            minLines: widget.minLines,
                            obscureText: widget.obscureText,
                            keyboardType: widget.keyboardType,
                            textInputAction: widget.textInputAction,
                            onChanged: widget.onChanged,
                            onSubmitted: widget.onSubmitted,
                            cursorColor: theme.primary,
                            backgroundCursorColor: DsColors.transparent,
                            cursorWidth: 2,
                            cursorRadius: const Radius.circular(2),
                            autocorrect: false,
                            style: DsTypography.body.copyWith(
                              color: widget.enabled
                                  ? theme.text
                                  : theme.textSub,
                            ),
                            strutStyle: const StrutStyle(
                                fontSize: 14, forceStrutHeight: true),
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
        if (hasError) ...[
          SizedBox(height: theme.spacing.xs),
          Text(
            widget.errorText!,
            style: DsTypography.caption.copyWith(color: theme.danger),
          ),
        ],
      ],
    );
  }

  bool get _focused => _effectiveFocus.hasFocus;

  @override
  void initState() {
    super.initState();
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
    return DsIcon(
      DsIconKind.search,
      size: 20,
      color: theme.textSub,
    );
  }
}
