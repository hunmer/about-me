import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 手绘标签输入：Wrap 流式标签 + 行内输入 + 可选「+」外部添加按钮
///
/// - [onTagsChanged] 为 null 时整组只读（隐藏删除叉/输入/添加按钮）
/// - 标签颜色按名字哈希取主题语义色，同名颜色稳定、增删不跳变
/// - [allowCustom] 开启时行内输入回车 / 逗号确认新增（自动去空白去重）
/// - [onAddPressed] 提供时追加「+」按钮，交由调用方弹标签选择器
class DSTagInput extends StatefulWidget {
  const DSTagInput({
    super.key,
    required this.tags,
    this.onTagsChanged,
    this.allowCustom = true,
    this.hint,
    this.prefix = '#',
    this.addLabel,
    this.onAddPressed,
  });

  final List<String> tags;

  /// 标签集合变更回调（增删后回传完整列表）；null = 只读
  final ValueChanged<List<String>>? onTagsChanged;

  /// 允许行内输入自定义标签
  final bool allowCustom;

  /// 行内输入占位文案
  final String? hint;

  /// 标签文本前缀（如 `#`），空串则不显示
  final String prefix;

  /// 「+」按钮文案（可空，仅图标）
  final String? addLabel;

  /// 「+」按钮回调（如打开标签选择对话框）
  final VoidCallback? onAddPressed;

  @override
  State<DSTagInput> createState() => _DSTagInputState();
}

class _DSTagInputState extends State<DSTagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _editable => widget.onTagsChanged != null;

  /// 名字哈希 → 主题语义色（顺序稳定，同名标签颜色固定）
  Color _accentOf(String tag, AppThemeData theme) {
    final accents = [
      theme.primary,
      theme.secondary,
      theme.success,
      theme.warning,
      theme.danger,
    ];
    var hash = 0;
    for (final code in tag.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return accents[hash % accents.length];
  }

  void _submit([String? raw]) {
    final text = (raw ?? _controller.text).trim();
    if (text.isNotEmpty && !widget.tags.contains(text)) {
      widget.onTagsChanged?.call([...widget.tags, text]);
    }
    _controller.clear();
    // done 动作的提交会失焦，重新聚焦以便连续输入
    if (_editable && widget.allowCustom) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      children: [
        for (final tag in widget.tags) _buildChip(tag, theme),
        if (_editable && widget.onAddPressed != null) _buildAddButton(theme),
        if (_editable && widget.allowCustom) _buildInlineInput(theme),
      ],
    );
  }

  Widget _buildChip(String tag, AppThemeData theme) {
    final accent = _accentOf(tag, theme);
    final dark = theme.isDark;
    final fill = dark ? accent.withValues(alpha: 0.26) : accent.mixWhite(0.9);
    final fg = dark ? accent.mixWhite(0.72) : accent.mixBlack(0.28);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: dsSketchDecoration(
        theme: theme,
        fillColor: fill,
        stroke: accent.withValues(alpha: dark ? 0.65 : 0.5),
        strokeWidth: 1.6,
        radius: theme.radii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.prefix}$tag',
            style: DsTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_editable) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => widget.onTagsChanged!(
                [for (final t in widget.tags) if (t != tag) t],
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: DsIcon(DsIconKind.close, size: 10, color: fg),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddButton(AppThemeData theme) {
    final label = widget.addLabel ?? '';
    return Pressable(
      onPressed: widget.onAddPressed,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: dsSketchDecoration(
          theme: theme,
          stroke: theme.textSub.withValues(alpha: 0.4),
          strokeWidth: 1.4,
          radius: theme.radii.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIcon(DsIconKind.plus, size: 14, color: theme.textSub),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: theme.textSub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 行内输入：与标签同高的隐形输入位（回车 / 中英文逗号确认）
  Widget _buildInlineInput(AppThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, maxWidth: 180),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final showHint = value.text.isEmpty && widget.hint != null;
            return Stack(
              children: [
                if (showHint)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Text(
                      widget.hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(
                        color: theme.textSub.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: EditableText(
                    controller: _controller,
                    focusNode: _focus,
                    style: DsTypography.caption.copyWith(color: theme.text),
                    cursorColor: theme.primary,
                    backgroundCursorColor: DsColors.transparent,
                    autocorrect: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    onChanged: (v) {
                      if (v.endsWith(',') || v.endsWith('，')) {
                        _submit(v.substring(0, v.length - 1));
                      }
                    },
                    onSubmitted: _submit,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
