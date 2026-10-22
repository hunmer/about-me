import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../primitives/haptics.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';

/// 手绘气泡卡：点击触发，内容可交互（区别于 Tooltip 的纯提示）
class DSPopover extends StatefulWidget {
  const DSPopover({
    super.key,
    required this.contentBuilder,
    required this.child,
    this.width = 220,
    this.activateOnLongPress = false,
  });

  /// 气泡内容（按钮、列表等可交互元素均可）；
  /// [close] 供内容主动关闭气泡（如点击菜单项触发跳转/弹窗时）
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final Widget child;
  final double width;

  /// true 时改为长按触发（点击留给 child 外层手势，如列表项选中）
  final bool activateOnLongPress;

  @override
  State<DSPopover> createState() => _DSPopoverState();
}

class _DSPopoverState extends State<DSPopover> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  double _availableHeight = 360;
  bool _openUpward = false;
  double _dx = 0;

  /// 是否正在播退场动画（关闭路径防重入）
  bool _closing = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  void _toggle() {
    _open ? _close() : _insertEntry();
    if (mounted) setState(() {});
  }

  /// 关闭收敛入口：barrier 点击 / 内容主动 close / 触发器再点都走这里；
  /// 先播退场（缩小淡出）再延迟移除浮层，动效减弱时直接移除。
  void _close() {
    if (_closing) return;
    _closing = true;
    if (!mounted) return;
    if (context.dsAnimationsDisabled) {
      _removeEntry();
      setState(() {});
      return;
    }
    // 通知浮层重绘退场帧（tween 目标切到 0）
    _entry?.markNeedsBuild();
    setState(() {});
    Future.delayed(DsMotion.fast, _removeEntry);
  }

  void _insertEntry() {
    _closing = false;
    DsHaptics.popup();
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final topLeft = box.localToGlobal(Offset.zero);
    final viewport = MediaQuery.sizeOf(context);
    final viewportHeight = viewport.height;
    final below = viewportHeight - topLeft.dy - size.height;
    final above = topLeft.dy;
    _openUpward = below < 280 && above > below;
    _availableHeight = (_openUpward ? above : below) - 16;
    // 水平钳制：气泡以锚点居中，超出屏幕时平移回屏内（气泡比屏还宽则居中）
    const hMargin = 8.0;
    final anchorCenterX = topLeft.dx + size.width / 2;
    final overflowLeft = hMargin - (anchorCenterX - widget.width / 2);
    final overflowRight = anchorCenterX + widget.width / 2 - (viewport.width - hMargin);
    if (overflowLeft > 0 && overflowRight > 0) {
      _dx = (viewport.width - widget.width) / 2 - (anchorCenterX - widget.width / 2);
    } else if (overflowLeft > 0) {
      _dx = overflowLeft;
    } else if (overflowRight > 0) {
      _dx = -overflowRight;
    } else {
      _dx = 0;
    }

    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 外部点击关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: _openUpward
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            followerAnchor: _openUpward
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            offset: Offset(_dx, _openUpward ? -10 : 10),
            child: AppTheme(
              data: theme,
              child: IgnorePointer(
                // 退场期间禁用交互，防止重复触发
                ignoring: _closing,
                child: TweenAnimationBuilder<double>(
                  // t=1 为完整态：入场 0→1 放大淡入，退场 1→0 缩小淡出（同一映射双向复用）
                  tween: Tween(begin: 0.0, end: _closing ? 0.0 : 1.0),
                  duration: DsMotion.fast,
                  curve: _closing ? DsMotion.curve : DsMotion.enter,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0, 1),
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * t,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                  child: WiredDraw(
                    // 气泡缩放淡入的同时墨线描画入场（OverlayEntry 每次打开新挂载即播）
                    child: _PopoverCard(
                      width: widget.width,
                      maxHeight: _availableHeight.clamp(120, viewportHeight),
                      openUpward: _openUpward,
                      arrowOffsetX: -_dx,
                      contentBuilder: widget.contentBuilder,
                      close: _close,
                    ),
                  ),
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
    // 延迟回调触发时浮层可能已被外部移除，remove 前确认仍挂载
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      // opaque：child 不参与命中（如被 IgnorePointer 包裹的纯视觉按钮）时触发器自身兜底命中
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.activateOnLongPress ? null : _toggle,
        onLongPress: widget.activateOnLongPress ? _toggle : null,
        child: widget.child,
      ),
    );
  }
}

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.width,
    required this.maxHeight,
    required this.openUpward,
    this.arrowOffsetX = 0,
    required this.contentBuilder,
    required this.close,
  });

  final double width;
  final double maxHeight;
  final bool openUpward;

  /// 气泡被水平平移后，三角相对卡片中心的反向偏移，保持指向锚点
  final double arrowOffsetX;
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // 外层 WiredDraw 注入的描画进度
    final progress = WiredDrawTransition.progressOf(context);
    // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
    final card = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DsSketchPanel(
        theme: theme,
        width: width,
        radius: theme.radii.lg,
        padding: EdgeInsets.all(theme.spacing.md),
        progress: progress,
        child: contentBuilder(context, close),
      ),
    );
    // 小三角（纯色 + 淡墨描边）；钳制在卡片内避免贴边溢出
    final triangle = Transform.translate(
      offset: Offset(
        arrowOffsetX.clamp(-width / 2 + 14, width / 2 - 14),
        openUpward ? 6 : -6,
      ),
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: theme.ink.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: openUpward ? [triangle, card] : [card, triangle],
    );
  }
}
