import 'package:flutter/widgets.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';

/// 手绘气泡卡：点击触发，内容可交互（区别于 Tooltip 的纯提示）
class DSPopover extends StatefulWidget {
  const DSPopover({
    super.key,
    required this.contentBuilder,
    required this.child,
    this.width = 220,
  });

  /// 气泡内容（按钮、列表等可交互元素均可）；
  /// [close] 供内容主动关闭气泡（如点击菜单项触发跳转/弹窗时）
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final Widget child;
  final double width;

  @override
  State<DSPopover> createState() => _DSPopoverState();
}

class _DSPopoverState extends State<DSPopover> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  double _availableHeight = 360;
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

  /// 供气泡内容主动关闭自己
  void _close() {
    _removeEntry();
    if (mounted) setState(() {});
  }

  void _insertEntry() {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final below = viewportHeight - top - size.height;
    final above = top;
    _openUpward = below < 280 && above > below;
    _availableHeight = (_openUpward ? above : below) - 16;

    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 外部点击关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeEntry,
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
            offset: Offset(0, _openUpward ? -10 : 10),
            child: AppTheme(
              data: theme,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0, 1),
                  child: Transform.scale(
                    scale: t,
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
                    contentBuilder: widget.contentBuilder,
                    close: _close,
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

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({
    required this.width,
    required this.maxHeight,
    required this.openUpward,
    required this.contentBuilder,
    required this.close,
  });

  final double width;
  final double maxHeight;
  final bool openUpward;
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
    // 小三角（纯色 + 淡墨描边）
    final triangle = Transform.translate(
      offset: Offset(0, openUpward ? 6 : -6),
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
