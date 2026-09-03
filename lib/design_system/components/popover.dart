import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// 果冻气泡卡：点击触发，内容可交互（区别于 Tooltip 的纯提示）
class DSPopover extends StatefulWidget {
  const DSPopover({
    super.key,
    required this.contentBuilder,
    required this.child,
    this.width = 220,
  });

  /// 气泡内容（按钮、列表等可交互元素均可）
  final WidgetBuilder contentBuilder;
  final Widget child;
  final double width;

  @override
  State<DSPopover> createState() => _DSPopoverState();
}

class _DSPopoverState extends State<DSPopover> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

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
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 10),
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
                child: _PopoverCard(
                  width: widget.width,
                  contentBuilder: widget.contentBuilder,
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
      child: GestureDetector(
        onTap: _toggle,
        child: widget.child,
      ),
    );
  }
}

class _PopoverCard extends StatelessWidget {
  const _PopoverCard({required this.width, required this.contentBuilder});

  final double width;
  final WidgetBuilder contentBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 气泡卡主体
        Container(
          width: width,
          padding: EdgeInsets.all(theme.spacing.md),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: theme.radii.lg,
            border: Border.all(color: theme.stroke, width: 1.4),
            boxShadow: theme.shadows.float,
          ),
          child: contentBuilder(context),
        ),
        // 小三角
        Transform.translate(
          offset: const Offset(0, -6),
          child: Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
