import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// 气泡样式：[solid] 主色实底（默认），[paper] 纸底 + 墨线描边 + 主题文字色
enum DsTooltipVariant { solid, paper }

/// 手绘气泡提示：桌面悬停 / 移动端长按触发
class DSTooltip extends StatefulWidget {
  const DSTooltip({
    super.key,
    required this.message,
    required this.child,
    this.variant = DsTooltipVariant.solid,
  });

  final String message;
  final Widget child;

  /// 气泡样式，默认主色实底（与旧版一致）
  final DsTooltipVariant variant;

  @override
  State<DSTooltip> createState() => _DSTooltipState();
}

class _DSTooltipState extends State<DSTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _autoHide;

  /// 是否正在播退场动画（关闭路径防重入）
  bool _closing = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _autoHide?.cancel();
    _removeEntry();
    super.dispose();
  }

  void _show() {
    if (_open) return;
    _closing = false;
    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      // 不放全屏 opaque 拦截层：它会截断鼠标命中测试，令锚点的
      // MouseRegion 立刻 onExit → 隐藏 → 再 onEnter → 再显示，循环闪烁。
      // 「点击任意处关闭」改由 TapRegion 全局监听（不参与命中测试）。
      builder: (context) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -10),
        child: TapRegion(
          onTapOutside: (_) => _hide(),
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
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
                child: _Bubble(
                  message: widget.message,
                  variant: widget.variant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _autoHide = Timer(const Duration(seconds: 3), _hide);
    setState(() {});
  }

  /// 关闭收敛入口：点击气泡外 / 自动隐藏 / 鼠标移出 / 再次点击都走这里。
  /// 先播退场（缩小淡出）再延迟移除浮层；动效减弱时跳过退场直接移除。
  void _hide() {
    _autoHide?.cancel();
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
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        // 点击锚点收起提示：走原始指针事件，不进手势竞技场，
        // 否则会抢在外层触发器（DSMenu/DSPopover 的 onTap）之前胜出
        child: Listener(
          onPointerDown: (_) => _hide(),
          child: GestureDetector(onLongPress: _show, child: widget.child),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.variant});

  final String message;
  final DsTooltipVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // paper：纸底 + 墨线描边 + 主题文字色；solid：主色实底 + 主色文字（默认）
    final paper = variant == DsTooltipVariant.paper;
    final fillColor = paper ? theme.surface : theme.primary;
    final textColor = paper ? theme.text : theme.onPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 气泡主体：按样式取实底 + 墨线描边（手绘）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: dsSketchDecoration(
            theme: theme,
            fillColor: fillColor,
            radius: theme.radii.md,
            strokeWidth: 1.6,
          ),
          child: Text(
            message,
            style: DsTypography.caption.copyWith(color: textColor),
          ),
        ),
        // 小三角（叠在气泡下缘）：与气泡同底色 + 淡墨描边
        Transform.translate(
          offset: const Offset(0, -5),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: theme.ink.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
