import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';
import 'menu.dart';

/// 手绘下拉菜单按钮：墨盒触发器 + 浮出动作菜单
///
/// 与 [DSSelect]（取值型）不同，[DSDropdown] 的条目是动作（[DSMenuItem.onTap]），
/// 适合「更多操作」「导出为…」等场景。
class DSDropdown extends StatefulWidget {
  const DSDropdown({
    super.key,
    required this.label,
    required this.items,
    this.icon,
    this.width,
    this.align = DSMenuAlign.start,
    this.enabled = true,
  });

  final String label;
  final List<DSMenuItem> items;

  /// 触发器左侧图标
  final DsIconKind? icon;
  final double? width;
  final DSMenuAlign align;
  final bool enabled;

  @override
  State<DSDropdown> createState() => _DSDropdownState();
}

class _DSDropdownState extends State<DSDropdown> {
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
    final box = context.findRenderObject() as RenderBox;
    final panelWidth = widget.width ?? box.size.width;
    final metrics = dsComputeMenuMetrics(
      box: box,
      panelWidth: panelWidth,
      viewport: MediaQuery.sizeOf(context),
      align: widget.align,
    );
    _openUpward = metrics.openUpward;

    // 浮层挂在根 Overlay，脱离主题树，这里提前捕获主题
    final theme = AppTheme.of(context);
    final end = widget.align == DSMenuAlign.end;
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
            targetAnchor:
                _openUpward
                    ? (end ? Alignment.topRight : Alignment.topLeft)
                    : (end ? Alignment.bottomRight : Alignment.bottomLeft),
            followerAnchor:
                _openUpward
                    ? (end ? Alignment.bottomRight : Alignment.bottomLeft)
                    : (end ? Alignment.topRight : Alignment.topLeft),
            offset: Offset(metrics.dx, _openUpward ? -8 : 8),
            child: AppTheme(
              data: theme,
              child: SizedBox(
                width: panelWidth,
                child: DSMenuPanel(
                  items: widget.items,
                  alignTop: _openUpward,
                  maxHeight: metrics.maxHeight,
                  onDismiss: _removeEntry,
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
    return CompositedTransformTarget(
      link: _link,
      child: Pressable(
        onPressed: widget.enabled ? _toggle : null,
        semanticLabel: widget.label,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);
          return SizedBox(
            width: widget.width,
            child: JellyBox(
              height: 46,
              radius: theme.radii.lg,
              raised: !_open && !pressed,
              // 描边对齐 DSInput：静止淡墨线、展开（等同聚焦）主题色
              strokeColor: _open
                  ? theme.primary
                  : theme.textSub.withValues(alpha: 0.45),
              borderWidth: 1.6,
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    DsIcon(widget.icon!, size: 18, color: theme.primary),
                    SizedBox(width: theme.spacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      style: DsTypography.body.copyWith(color: theme.text),
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
