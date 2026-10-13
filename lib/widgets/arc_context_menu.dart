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
/// - 菜单项以固定弧度间隔沿半圆弧依次排开，按钮较小；
///   弧形优先朝水平侧边（左/右）展开，空间不足再朝上/下
/// - 支持 iOS 风格滑动选中：长按不松手拖到菜单项上，松手即触发
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
class ArcContextMenu extends StatefulWidget {
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

  @override
  State<ArcContextMenu> createState() => _ArcContextMenuState();
}

class _ArcContextMenuState extends State<ArcContextMenu> {
  /// 长按拖动的全局位置（null = 手指已抬起），驱动浮层滑动选中
  final ValueNotifier<Offset?> _dragPosition = ValueNotifier(null);

  @override
  void dispose() {
    _dragPosition.dispose();
    super.dispose();
  }

  void _show(BuildContext context, Offset startPosition) {
    if (widget.items.isEmpty) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final theme = DSThemeBridge.resolve(context);
    final itemsSnapshot = List<ArcMenuItem>.unmodifiable(widget.items);
    final target = widget.preview ?? widget.child;

    HapticFeedback.mediumImpact();
    _dragPosition.value = startPosition;

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
            dragPosition: _dragPosition,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart:
          widget.items.isEmpty
              ? null
              : (details) => _show(context, details.globalPosition),
      onLongPressMoveUpdate:
          widget.items.isEmpty
              ? null
              : (details) => _dragPosition.value = details.globalPosition,
      onLongPressEnd:
          widget.items.isEmpty ? null : (_) => _dragPosition.value = null,
      onLongPressCancel:
          widget.items.isEmpty ? null : () => _dragPosition.value = null,
      child: widget.child,
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

class _ArcMenuOverlay extends StatefulWidget {
  const _ArcMenuOverlay({
    required this.animation,
    required this.targetRect,
    required this.items,
    required this.target,
    required this.dragPosition,
  });

  final Animation<double> animation;
  final Rect targetRect;
  final List<ArcMenuItem> items;
  final Widget target;
  final ValueNotifier<Offset?> dragPosition;

  @override
  State<_ArcMenuOverlay> createState() => _ArcMenuOverlayState();
}

class _ArcMenuOverlayState extends State<_ArcMenuOverlay> {
  /// 圆形按钮尺寸（小尺寸，弧线更紧凑）
  static const double _buttonSize = 44;

  /// 相邻菜单项的弧度间隔（≈52°），固定间隔保证任意数量都呈弧形
  static const double _angleStep = 0.92;

  /// 滑动选中的命中半径
  static const double _hitRadius = 34;

  /// 当前悬停的菜单项下标
  int? _hovered;

  /// 本帧菜单项的圆心坐标（build 时更新，供滑动命中测试）
  List<Offset> _itemCenters = [];

  /// 防止松手后重复触发
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    widget.dragPosition.addListener(_onDragChanged);
  }

  @override
  void dispose() {
    widget.dragPosition.removeListener(_onDragChanged);
    super.dispose();
  }

  void _onDragChanged() {
    final pos = widget.dragPosition.value;
    if (pos == null) {
      // 手指抬起：有悬停项则选中，否则保持菜单打开等待点按
      final hovered = _hovered;
      if (hovered != null && !_selected) {
        _selected = true;
        final item = widget.items[hovered];
        Navigator.of(context).pop();
        item.onTap();
      }
      return;
    }
    final hit = _hitTest(pos);
    if (hit != _hovered) {
      setState(() => _hovered = hit);
      if (hit != null) HapticFeedback.selectionClick();
    }
  }

  int? _hitTest(Offset pos) {
    for (var i = 0; i < _itemCenters.length; i++) {
      if ((pos - _itemCenters[i]).distance <= _hitRadius) return i;
    }
    return null;
  }

  /// 探测目标四周可用空间，返回弧形朝向的中心角
  ///
  /// 优先水平侧边（左/右，取空间更大的一侧）；水平都放不下再用垂直方向；
  /// 都放不下则退化为空间最大的方向
  double _pickFacingAngle(
    Offset center,
    Size screenSize,
    EdgeInsets padding,
    double radius,
  ) {
    final spaces = <double, double>{
      0.0: screenSize.width - padding.right - center.dx, // 右
      math.pi: center.dx - padding.left, // 左
      -math.pi / 2: center.dy - padding.top, // 上
      math.pi / 2: screenSize.height - padding.bottom - center.dy, // 下
    };
    final need = radius + _buttonSize;

    double? bestFitting(List<double> dirs) {
      double? best;
      var bestSpace = -1.0;
      for (final dir in dirs) {
        final space = spaces[dir]!;
        if (space >= need && space > bestSpace) {
          best = dir;
          bestSpace = space;
        }
      }
      return best;
    }

    return bestFitting([0.0, math.pi]) ?? // 水平侧边优先
        bestFitting([-math.pi / 2, math.pi / 2]) ?? // 空间不够再垂直
        spaces.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final anim = widget.animation.value.clamp(0.0, 1.0);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final center = widget.targetRect.center;
    final radius =
        math.max(widget.targetRect.width, widget.targetRect.height) / 2 + 62;
    final centerAngle = _pickFacingAngle(center, size, padding, radius);
    final n = widget.items.length;

    // 菜单项沿半圆弧按固定弧度间隔排布（以朝向中心角对称展开）
    final centers = <Offset>[];
    for (var i = 0; i < n; i++) {
      final angle = centerAngle - (n - 1) * _angleStep / 2 + i * _angleStep;
      final dx = (center.dx + radius * math.cos(angle)).clamp(
        _buttonSize / 2 + 10,
        size.width - _buttonSize / 2 - 10,
      );
      final dy = (center.dy + radius * math.sin(angle)).clamp(
        padding.top + _buttonSize / 2 + 10,
        size.height - padding.bottom - _buttonSize / 2 - 34,
      );
      centers.add(Offset(dx, dy));
    }
    _itemCenters = centers;

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
            left: widget.targetRect.left,
            top: widget.targetRect.top,
            width: widget.targetRect.width,
            height: widget.targetRect.height,
            child: IgnorePointer(
              child: Transform.scale(
                scale: 1 + 0.07 * anim,
                child: widget.target,
              ),
            ),
          ),

          // 半圆弧菜单项
          for (var i = 0; i < n; i++)
            _buildItem(context, theme, i, n, centers[i], anim),
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
    double anim,
  ) {
    final item = widget.items[index];
    final hovered = _hovered == index;

    // 入场错峰：沿弧度顺序依次弹出带回弹
    final start = (0.10 + index * 0.09).clamp(0.0, 0.6);
    final progress = Interval(
      start,
      math.min(1.0, start + 0.5),
      curve: Curves.easeOutBack,
    ).transform(anim);

    final scale = progress * (hovered ? 1.18 : 1.0);

    return Positioned(
      left: center.dx - _buttonSize / 2,
      top: center.dy - _buttonSize / 2,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_selected) return;
                  _selected = true;
                  Navigator.of(context).pop();
                  item.onTap();
                },
                child: JellyBox(
                  width: _buttonSize,
                  height: _buttonSize,
                  radius: theme.radii.circle,
                  color: hovered ? theme.primary : theme.paper,
                  child: Center(
                    child: DsIcon(
                      item.icon,
                      size: 20,
                      color:
                          hovered
                              ? theme.onPrimary
                              : item.destructive
                              ? theme.danger
                              : theme.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.paper.withValues(alpha: 0.85),
                  borderRadius: theme.radii.pill,
                ),
                child: Text(
                  item.label,
                  style: DsTypography.caption.copyWith(
                    color: theme.text,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
