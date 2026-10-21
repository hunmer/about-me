import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// Toast 类型
enum DSToastType { info, success, warning, danger }

/// Toast 入场方向：[bottom] 为现状默认，其余按方向横移/纵移 24px 滑入
enum DSToastFrom { bottom, top, left, right }

/// 当前展示中的 Toast 队列（用于纵向堆叠，避免互相遮挡）
final List<OverlayEntry> _toastQueue = [];

/// 单条 Toast 占用的纵向高度估算
const double _toastSlotHeight = 64;

/// 顶部滑入的手绘 Toast，自动消失；多条时纵向堆叠
void showDSToast(
  BuildContext context, {
  required String message,
  DSToastType type = DSToastType.success,
  Duration duration = const Duration(milliseconds: 2000),
  DSToastFrom from = DSToastFrom.bottom,
}) {
  final theme = AppTheme.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final index = _toastQueue.length;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AppTheme(
      data: theme,
      child: _ToastView(
        message: message,
        type: type,
        duration: duration,
        from: from,
        slotTop:
            MediaQuery.paddingOf(context).top + 16 + index * _toastSlotHeight,
        onDismiss: () {
          _toastQueue.remove(entry);
          if (entry.mounted) entry.remove();
        },
      ),
    ),
  );
  _toastQueue.add(entry);
  overlay.insert(entry);
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.from,
    required this.slotTop,
    required this.onDismiss,
  });

  final String message;
  final DSToastType type;
  final Duration duration;

  /// 入场位移方向（默认 bottom 保持现状）
  final DSToastFrom from;

  /// 距屏幕顶部的起始位置（含安全区与堆叠偏移）
  final double slotTop;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    _controller.reverse().whenComplete(widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final Color color;
    final DsIconKind icon;
    switch (widget.type) {
      case DSToastType.info:
        color = theme.primary;
        icon = DsIconKind.star;
      case DSToastType.success:
        color = theme.success;
        icon = DsIconKind.check;
      case DSToastType.warning:
        color = theme.warning;
        icon = DsIconKind.bell;
      case DSToastType.danger:
        color = theme.danger;
        icon = DsIconKind.close;
    }

    return Positioned(
      top: widget.slotTop,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeOutBack.transform(_controller.value);
            // 入场位移：随 from 方向滑入 24px（bottom 为现状默认），退场按原路 reverse 回去
            final d = 24 * (1 - t);
            final offset = switch (widget.from) {
              DSToastFrom.bottom => Offset(0, -d),
              DSToastFrom.top => Offset(0, d),
              DSToastFrom.left => Offset(d, 0),
              DSToastFrom.right => Offset(-d, 0),
            };
            return Opacity(
              opacity: _controller.value.clamp(0, 1),
              child: Transform.translate(
                offset: offset,
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: _dismiss,
            child: JellyBox(
              radius: theme.radii.pill,
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.lg,
                vertical: theme.spacing.md,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 类型色圆底（纯色实底，无彩影）
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: DsIcon(icon, size: 13, color: theme.onPrimary),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: DsTypography.body.copyWith(color: theme.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
