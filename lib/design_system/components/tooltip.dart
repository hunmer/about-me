import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';

/// 果冻气泡提示：桌面悬停 / 移动端长按触发
class DSTooltip extends StatefulWidget {
  const DSTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<DSTooltip> createState() => _DSTooltipState();
}

class _DSTooltipState extends State<DSTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _autoHide;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _autoHide?.cancel();
    _removeEntry();
    super.dispose();
  }

  void _show() {
    if (_open) return;
    final theme = AppTheme.of(context);
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 拦截层：点击任意处关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hide,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -10),
            child: AppTheme(
              data: theme,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0, 1),
                  child: Transform.scale(
                    scale: t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
                child: _Bubble(message: widget.message),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _autoHide = Timer(const Duration(seconds: 3), _hide);
    setState(() {});
  }

  void _hide() {
    _autoHide?.cancel();
    _removeEntry();
    if (mounted) setState(() {});
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: GestureDetector(
          onLongPress: _show,
          onTap: _open ? _hide : null,
          child: widget.child,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 气泡主体（深果冻色）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: theme.jellyGradient(theme.primaryText),
            ),
            borderRadius: theme.radii.md,
            boxShadow: theme.jellyShadow(theme.primaryText, height: 4),
          ),
          child: Text(
            message,
            style: DsTypography.caption.copyWith(color: theme.surface),
          ),
        ),
        // 小三角（叠在气泡下缘）
        Transform.translate(
          offset: const Offset(0, -5),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.primaryText,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
