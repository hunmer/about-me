import 'package:flutter/widgets.dart';

import 'package:aboutme/core/services/toast_service.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';
import 'jelly_box.dart';

/// Toast 类型
enum DSToastType { info, success, warning, danger }

/// Toast 入场方向，映射到 ToastService 的 slide 入场动画
enum DSToastFrom { bottom, top, left, right }

/// 顶部滑入的手绘 Toast，自动消失；展示与动画由 ToastService 统一管理
void showDSToast(
  BuildContext context, {
  required String message,
  DSToastType type = DSToastType.success,
  Duration duration = const Duration(milliseconds: 2000),
  DSToastFrom from = DSToastFrom.bottom,
}) {
  ToastAnimation animationFor(DSToastFrom from) => switch (from) {
    DSToastFrom.bottom => ToastAnimation.slideFromBottom,
    DSToastFrom.top => ToastAnimation.slideFromTop,
    DSToastFrom.left => ToastAnimation.slideFromLeft,
    DSToastFrom.right => ToastAnimation.slideFromRight,
  };

  // 包一层 AppTheme，让 overlay 中的 _ToastView 仍能取到调用方的主题
  toastService.showCustomWidget(
    AppTheme(
      data: AppTheme.of(context),
      child: _ToastView(message: message, type: type),
    ),
    context: context,
    duration: duration,
    position: ToastGravity.TOP,
    animation: animationFor(from),
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.message, required this.type});

  final String message;
  final DSToastType type;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    final Color color;
    final DsIconKind icon;
    switch (type) {
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

    return GestureDetector(
      // 点击提前关闭（ToastManager 会清掉当前显示的 toast）
      onTap: toastService.cancel,
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: DsIcon(icon, size: 13, color: theme.onPrimary),
            ),
            SizedBox(width: theme.spacing.sm),
            Flexible(
              child: Text(
                message,
                style: DsTypography.body.copyWith(color: theme.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
