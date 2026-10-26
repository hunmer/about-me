import 'package:flutter/material.dart';

import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 展开式 FAB 菜单项（图标 + 文案 + 点击回调）
class ExpandableFabAction {
  const ExpandableFabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final DsIconKind icon;
  final String label;
  final VoidCallback onPressed;
}

/// 可展开菜单的悬浮按钮（自 notes 插件的 NotesFab 抽离的公共组件）
///
/// 点击主按钮原地旋转并向上展开菜单项（右对齐）。菜单项默认为 DSButton
/// 描边小按钮，[ExpandableFab.circularActions] 为真时渲染为圆形小 FAB
/// 加文字标签气泡。菜单经 Overlay + LayerLink 锚定在主按钮上方，因此组件
/// 可嵌于紧凑或带变换的父级（如底部导航 dock 的 35px 缩放槽位），菜单仍按
/// 原始尺寸渲染；点击菜单外任意处收起（不拦截下层正常响应）。
class ExpandableFab extends StatefulWidget {
  const ExpandableFab({
    super.key,
    required this.actions,
    this.icon = DsIconKind.plus,
    this.color,
    this.iconColor,
    this.circularActions = false,
  });

  /// 主按钮图标
  final DsIconKind icon;

  /// 主按钮基色（默认主题主色）
  final Color? color;

  /// 主按钮图标颜色
  final Color? iconColor;

  /// 菜单项渲染为圆形小 FAB + 文字标签（默认 DSButton 描边长条）
  final bool circularActions;

  /// 展开的菜单项（自上而下排列）
  final List<ExpandableFabAction> actions;

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  bool get _expanded => _menuEntry != null;

  void _toggle() => _expanded ? _collapse() : _expand();

  void _expand() {
    final entry = OverlayEntry(
      builder: (_) => DSThemeBridge(
        child: Stack(
          children: [
            // 全屏透明点击层：点击菜单外任意处收起，事件透传给下层
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _collapse,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.topRight,
              followerAnchor: Alignment.bottomRight,
              offset: const Offset(0, -16),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                builder: (context, opacity, child) =>
                    Opacity(opacity: opacity, child: child),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < widget.actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _buildActionItem(widget.actions[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    setState(() => _menuEntry = entry);
  }

  void _collapse() {
    _menuEntry?.remove();
    _menuEntry = null;
    if (mounted) setState(() {});
  }

  /// 单个菜单项：默认 DSButton 描边按钮，circularActions 时为圆形小 FAB
  Widget _buildActionItem(ExpandableFabAction action) {
    void onPressed() {
      _collapse();
      action.onPressed();
    }

    if (!widget.circularActions) {
      return DSButton(
        label: action.label,
        icon: action.icon,
        variant: DSButtonVariant.outline,
        size: DSButtonSize.sm,
        onPressed: onPressed,
      );
    }
    return _CircularFabAction(
      action: action,
      color: widget.color,
      iconColor: widget.iconColor,
      onPressed: onPressed,
    );
  }

  @override
  void dispose() {
    _menuEntry?.remove();
    _menuEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 自包桥：DSFab/DSButton 依赖 AppTheme，宿主（如底部导航外壳）不保证提供
    return DSThemeBridge(
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedRotation(
          turns: _expanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: DSFab(
            icon: widget.icon,
            color: widget.color,
            iconColor: widget.iconColor,
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}

/// 圆形 FAB 风格菜单项：小圆形 DSFab + 左侧文字标签气泡
class _CircularFabAction extends StatelessWidget {
  const _CircularFabAction({
    required this.action,
    this.color,
    this.iconColor,
    required this.onPressed,
  });

  final ExpandableFabAction action;
  final Color? color;
  final Color? iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.radii.pill,
            boxShadow: theme.shadows.soft,
          ),
          child: Text(
            action.label,
            style: DsTypography.button.copyWith(
              fontSize: 14,
              color: theme.text,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DSFab(
          icon: action.icon,
          size: 56,
          color: color,
          iconColor: iconColor,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
