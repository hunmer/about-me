import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 长按半圆形上下文菜单（通用组件）
///
/// 长按 [child] 时：
/// - 目标组件在原位置稍微放大
/// - 背景高斯模糊 + 轻微变暗
/// - 围绕目标以半圆弧展开一组圆形按钮（目标在屏幕上半部则弧线朝下，反之朝上）
///
/// 用法：
/// ```dart
/// ArcContextMenu(
///   onTap: () => open(),
///   items: [
///     ArcMenuItem(icon: DsIconKind.edit, label: '编辑', onTap: () => edit()),
///   ],
///   child: MyCard(),
/// )
/// ```
class ArcContextMenu extends StatelessWidget {
  const ArcContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.onTap,
    this.preview,
  });

  /// 菜单项（沿半圆弧依次排开）
  final List<ArcMenuItem> items;

  /// 被长按/点击的组件
  final Widget child;

  /// 普通点击回调（可选）
  final VoidCallback? onTap;

  /// 浮层中放大展示的组件（可选）
  ///
  /// 默认复用 [child]；当 [child] 内包含 Hero 等不能同时在两棵子树中
  /// 存在的组件时，传入一个不含这些组件的等价预览。
  final Widget? preview;

  void _show(BuildContext context) {
    if (items.isEmpty) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final theme = DSThemeBridge.resolve(context);
    final itemsSnapshot = List<ArcMenuItem>.unmodifiable(items);
    final target = preview ?? child;

    HapticFeedback.mediumImpact();

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'arc_context_menu',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, _) {
        return AppTheme(
          data: theme,
          child: _ArcMenuOverlay(
            animation: animation,
            targetRect: rect,
            items: itemsSnapshot,
            target: target,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: items.isEmpty ? null : () => _show(context),
      child: child,
    );
  }
}

/// 半圆菜单项
class ArcMenuItem {
  const ArcMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final DsIconKind icon;
  final String label;
  final VoidCallback onTap;

  /// 危险操作（图标用主题 danger 色）
  final bool destructive;
}

class _ArcMenuOverlay extends StatelessWidget {
  const _ArcMenuOverlay({
    required this.animation,
    required this.targetRect,
    required this.items,
    required this.target,
  });

  final Animation<double> animation;
  final Rect targetRect;
  final List<ArcMenuItem> items;
  final Widget target;

  static const double _buttonSize = 56;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final anim = animation.value.clamp(0.0, 1.0);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final center = targetRect.center;
    final above = center.dy > size.height * 0.52;
    final radius = math.max(targetRect.width, targetRect.height) / 2 + 78;
    final n = items.length;

    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景模糊 + 轻遮罩，点击关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12 * anim, sigmaY: 12 * anim),
                child: Container(
                  color: theme.barrier.withValues(alpha: 0.25 * anim),
                ),
              ),
            ),
          ),

          // 目标组件原位放大
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: IgnorePointer(
              child: Transform.scale(
                scale: 1 + 0.07 * anim,
                child: target,
              ),
            ),
          ),

          // 半圆弧菜单项
          for (var i = 0; i < n; i++)
            _buildItem(context, theme, i, n, center, radius, above, size, padding, anim),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    AppThemeData theme,
    int index,
    int count,
    Offset center,
    double radius,
    bool above,
    Size screenSize,
    EdgeInsets padding,
    double anim,
  ) {
    final item = items[index];

    // 入场错峰：依次弹出带回弹
    final start = (0.10 + index * 0.09).clamp(0.0, 0.6);
    final progress = Interval(
      start,
      math.min(1.0, start + 0.5),
      curve: Curves.easeOutBack,
    ).transform(anim);

    // 半圆弧角度：0=右，pi/2=下，pi=左，3pi/2=上
    final double angle;
    if (count == 1) {
      angle = above ? -math.pi / 2 : math.pi / 2;
    } else if (above) {
      angle = math.pi + math.pi * index / (count - 1); // 左 → 上 → 右
    } else {
      angle = math.pi - math.pi * index / (count - 1); // 左 → 下 → 右
    }

    final rawDx = center.dx + radius * math.cos(angle);
    final rawDy = center.dy + radius * math.sin(angle);
    final dx = rawDx.clamp(_buttonSize / 2 + 12, screenSize.width - _buttonSize / 2 - 12);
    final dy = rawDy.clamp(
      padding.top + _buttonSize / 2 + 12,
      screenSize.height - padding.bottom - _buttonSize / 2 - 40,
    );

    return Positioned(
      left: dx - _buttonSize / 2,
      top: dy - _buttonSize / 2,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: progress,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  item.onTap();
                },
                child: JellyBox(
                  width: _buttonSize,
                  height: _buttonSize,
                  radius: theme.radii.circle,
                  color: theme.paper,
                  child: Center(
                    child: DsIcon(
                      item.icon,
                      size: 24,
                      color: item.destructive ? theme.danger : theme.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.paper.withValues(alpha: 0.85),
                  borderRadius: theme.radii.pill,
                ),
                child: Text(
                  item.label,
                  style: DsTypography.caption.copyWith(color: theme.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
