import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 面板相对锚点的水平对齐
enum DSMenuAlign { start, end }

/// 依据锚点位置计算菜单浮层的展开方向、可用高度与水平钳制偏移
///
/// 复用 DSPopover 的屏幕边界策略：下方空间不足且上方更宽裕时向上展开；
/// 面板超出屏幕左右边缘时水平平移回屏内（比屏还宽则整体居中）。
({bool openUpward, double maxHeight, double dx}) dsComputeMenuMetrics({
  required RenderBox box,
  required double panelWidth,
  required Size viewport,
  required DSMenuAlign align,
}) {
  final size = box.size;
  final topLeft = box.localToGlobal(Offset.zero);
  final below = viewport.height - topLeft.dy - size.height;
  final above = topLeft.dy;
  final openUpward = below < 280 && above > below;
  final maxHeight = ((openUpward ? above : below) - 16).clamp(
    120.0,
    viewport.height,
  );

  // 面板理想中心：start 锚定锚点左边、end 锚定锚点右边
  final panelCenter =
      align == DSMenuAlign.start
          ? topLeft.dx + panelWidth / 2
          : topLeft.dx + size.width - panelWidth / 2;
  const hMargin = 8.0;
  final overflowLeft = hMargin - (panelCenter - panelWidth / 2);
  final overflowRight =
      panelCenter + panelWidth / 2 - (viewport.width - hMargin);
  double dx;
  if (overflowLeft > 0 && overflowRight > 0) {
    dx = (viewport.width - panelWidth) / 2 - (panelCenter - panelWidth / 2);
  } else if (overflowLeft > 0) {
    dx = overflowLeft;
  } else if (overflowRight > 0) {
    dx = -overflowRight;
  } else {
    dx = 0;
  }
  return (openUpward: openUpward, maxHeight: maxHeight, dx: dx);
}

/// 菜单项：[icon]/[trailing]（右侧快捷键提示）可选，[danger] 红墨样式
///
/// [DSMenuItem.divider] 插入分组分隔线。
class DSMenuItem {
  const DSMenuItem({
    required this.label,
    this.icon,
    this.trailing,
    this.danger = false,
    this.enabled = true,
    this.onTap,
    this.isDivider = false,
  });

  /// 分组分隔线
  const DSMenuItem.divider()
    : label = '',
      icon = null,
      trailing = null,
      danger = false,
      enabled = true,
      onTap = null,
      isDivider = true;

  final String label;
  final DsIconKind? icon;
  final String? trailing;
  final bool danger;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isDivider;
}

/// 手绘动作菜单：任意子组件作为触发器，点击浮出菜单面板
///
/// 区别于 [DSSelect]（取值型下拉）：Menu 的每一项是动作（onTap），
/// 支持图标、快捷键提示、危险项与分隔线。面板为纸底+淡排线（DsSketchPanel）。
class DSMenu extends StatefulWidget {
  const DSMenu({
    super.key,
    required this.child,
    required this.items,
    this.align = DSMenuAlign.start,
    this.width = 200,
  });

  final Widget child;
  final List<DSMenuItem> items;

  /// 面板水平对齐：小图标触发器（···）常用 [DSMenuAlign.end]
  final DSMenuAlign align;
  final double width;

  @override
  State<DSMenu> createState() => _DSMenuState();
}

class _DSMenuState extends State<DSMenu> {
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
    if (mounted) setState(() {});
  }

  void _insertEntry() {
    final box = context.findRenderObject() as RenderBox;
    final metrics = dsComputeMenuMetrics(
      box: box,
      panelWidth: widget.width,
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
                width: widget.width,
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
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(onTap: _toggle, child: widget.child),
    );
  }
}

/// 菜单浮层面板（DSMenu / DSDropdown 共用）：缩放入场 + 可滚动条目
class DSMenuPanel extends StatelessWidget {
  const DSMenuPanel({
    super.key,
    required this.items,
    this.alignTop = false,
    this.maxHeight = 280,
    this.onDismiss,
  });

  final List<DSMenuItem> items;

  /// 是否向上展开（缩放动画的锚点随之翻转）
  final bool alignTop;

  /// 高度上限（锚点到屏幕边缘的可用空间，超出后内部滚动）
  final double maxHeight;

  /// 点击可选项后、回调前的收起钩子
  final VoidCallback? onDismiss;

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
        constraints: BoxConstraints(maxHeight: maxHeight),
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
                  item.isDivider
                      ? _MenuDivider()
                      : _MenuRow(
                        item: item,
                        onTap: () {
                          onDismiss?.call();
                          item.onTap?.call();
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});

  final DSMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final accent = item.danger ? theme.danger : theme.textSub;
    return Pressable(
      onPressed: item.enabled ? onTap : null,
      semanticLabel: item.label,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        final active = item.enabled && (hovered || pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.md,
            vertical: theme.spacing.sm + 2,
          ),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: active ? theme.surfaceAlt : DsColors.transparent,
            stroke: active
                ? theme.ink.withValues(alpha: 0.55)
                : DsColors.transparent,
            radius: theme.radii.md,
          ),
          child: Row(
            children: [
              if (item.icon != null) ...[
                DsIcon(item.icon!, size: 18, color: accent),
                SizedBox(width: theme.spacing.sm),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: DsTypography.body.copyWith(
                    color:
                        item.enabled
                            ? (item.danger ? theme.danger : theme.text)
                            : theme.textSub.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (item.trailing != null) ...[
                SizedBox(width: theme.spacing.sm),
                Text(
                  item.trailing!,
                  style: DsTypography.caption.copyWith(
                    color: theme.textSub.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 手绘虚线分隔线（一顿一顿的小墨点，避免规整直线破坏纸面感）
class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final ink = theme.ink.withValues(alpha: 0.35);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final w in const [14.0, 10.0, 16.0, 8.0, 12.0])
            Container(width: w, height: 2, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(1))),
        ],
      ),
    );
  }
}
