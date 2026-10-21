import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/motion.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// 回到顶部：包裹可滚动区域，滚动超过阈值后右下角浮出回顶按钮
///
/// 监听 [controller]（须与被包裹的滚动视图共用）；点击后平滑滚回顶部
/// （[DsMotion.slow] + [DsMotion.curve]），先回调 [onPressed] 再滚动。
///
/// ```dart
/// final controller = ScrollController();
/// DsBackTop(
///   controller: controller,
///   child: ListView.builder(
///     controller: controller,
///     itemBuilder: (_, i) => ...,
///   ),
/// )
/// ```
class DsBackTop extends StatefulWidget {
  const DsBackTop({
    super.key,
    required this.controller,
    required this.child,
    this.visibleAfterOffset = 400,
    this.iconChild,
    this.onPressed,
  });

  /// 被包裹的滚动区域
  final ScrollController controller;

  /// 被包裹的内容（浮钮叠在其右下角）
  final Widget child;

  /// 滚动超过该偏移量后显示浮钮
  final double visibleAfterOffset;

  /// 自定义浮钮内容（默认向上 chevron 手绘图标）
  final Widget? iconChild;

  /// 点击回调（触发后仍会执行回顶滚动）
  final VoidCallback? onPressed;

  @override
  State<DsBackTop> createState() => _DsBackTopState();
}

class _DsBackTopState extends State<DsBackTop> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // controller 可能尚未 attach 到滚动视图：首帧后再取初值
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(DsBackTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final visible =
        widget.controller.position.pixels > widget.visibleAfterOffset;
    if (visible != _visible) setState(() => _visible = visible);
  }

  void _backToTop() {
    widget.onPressed?.call();
    if (widget.controller.hasClients) {
      widget.controller.animateTo(
        0,
        duration: DsMotion.slow,
        curve: DsMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: theme.spacing.xl,
          bottom: theme.spacing.xl,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedScale(
              scale: _visible ? 1 : 0.6,
              duration: DsMotion.base,
              curve: DsMotion.enter,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: DsMotion.base,
                curve: DsMotion.enter,
                child: Pressable(
                  onPressed: _backToTop,
                  child: JellyBox(
                    width: 44,
                    height: 44,
                    radius: theme.radii.circle,
                    color: theme.surface,
                    shadow: true,
                    child: Center(
                      child:
                          widget.iconChild ??
                          DsIcon(DsIconKind.chevronUp, color: theme.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
