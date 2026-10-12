import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 下拉选项
class DSSelectItem<T> {
  const DSSelectItem({required this.label, required this.value});

  final String label;
  final T value;
}

/// 手绘下拉选择器：Overlay + LayerLink 锚定展开
///
/// 触发器与选中行为手绘墨盒（JellyBox），浮层面板为纸底+淡排线（DsSketchPanel）。
class DSSelect<T> extends StatefulWidget {
  const DSSelect({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint = '请选择',
    this.enabled = true,
    this.width,
  });

  final List<DSSelectItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String hint;
  final bool enabled;
  final double? width;

  @override
  State<DSSelect<T>> createState() => _DSSelectState<T>();
}

class _DSSelectState<T> extends State<DSSelect<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  /// 展开方向（屏幕下方空间不足时向上）
  bool _openUpward = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _toggle() {
    _open ? _removeEntry() : _insertEntry();
    setState(() {});
  }

  void _insertEntry() {
    // 依据触发框在屏幕中的位置决定展开方向，并让面板宽度跟随触发框
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final top = box.localToGlobal(Offset.zero).dy;
    final below = MediaQuery.sizeOf(context).height - top - size.height;
    _openUpward = below < 280 && top > 280;

    // 浮层挂在根 Overlay，脱离主题树，这里提前捕获主题
    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 全屏点击关闭层
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeEntry,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: _openUpward
                ? Alignment.topLeft
                : Alignment.bottomLeft,
            followerAnchor: _openUpward
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            offset: Offset(0, _openUpward ? -8 : 8),
            child: AppTheme(
              data: theme,
              child: SizedBox(
                width: size.width,
                child: _SelectPanel<T>(
                  items: widget.items,
                  value: widget.value,
                  alignTop: _openUpward,
                  onSelect: (item) {
                    _removeEntry();
                    setState(() {});
                    widget.onChanged?.call(item.value);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final selected = widget.items
        .where((e) => e.value == widget.value)
        .firstOrNull;

    return CompositedTransformTarget(
      link: _link,
      child: Pressable(
        onPressed: widget.enabled ? _toggle : null,
        semanticLabel: selected?.label ?? widget.hint,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return SizedBox(
            width: widget.width,
            child: JellyBox(
              height: 46,
              radius: theme.radii.lg,
              raised: !_open && !pressed,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected?.label ?? widget.hint,
                      style: DsTypography.body.copyWith(
                        color: selected != null
                            ? theme.text
                            : theme.textSub.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _open ? 0.5 : 0,
                    child: DsIcon(
                      DsIconKind.chevronDown,
                      size: 18,
                      color: theme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectPanel<T> extends StatelessWidget {
  const _SelectPanel({
    required this.items,
    required this.value,
    required this.onSelect,
    this.alignTop = false,
  });

  final List<DSSelectItem<T>> items;
  final T? value;
  final ValueChanged<DSSelectItem<T>> onSelect;

  /// 是否向上展开（缩放动画的锚点随之翻转）
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(
          scale: t,
          alignment: alignTop ? Alignment.bottomCenter : Alignment.topCenter,
          child: child,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 320),
        child: DsSketchPanel(
          theme: theme,
          radius: theme.radii.lg,
          padding: EdgeInsets.all(theme.spacing.sm),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  _SelectRow(
                    item: item,
                    selected: item.value == value,
                    onTap: () => onSelect(item),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DSSelectItem<dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        if (selected) {
          return JellyBox(
            radius: theme.radii.md,
            color: theme.primary,
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm + 2,
            ),
            child: Text(
              item.label,
              style: DsTypography.body.copyWith(color: theme.onPrimary),
            ),
          );
        }
        // 悬停/按压：淡紫实底高亮（无描边，保持行内轻量）
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: pressed || hovered ? theme.surfaceAlt : DsColors.transparent,
            borderRadius: theme.radii.md,
          ),
          child: Text(
            item.label,
            style: DsTypography.body.copyWith(color: theme.text),
          ),
        );
      },
    );
  }
}
