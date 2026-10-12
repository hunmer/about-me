import 'package:flutter/material.dart';
import 'package:skribble/skribble.dart';

import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'button.dart';

/// 手绘对话框：缩放淡入 + 遮罩
///
/// 浮层挂在根导航上，脱离主题树，因此内部预先捕获主题并重建继承树。
/// [theme] 用于调用点不在 AppTheme 树内时显式传入（如独立路由页面）。
Future<T?> showDSDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  AppThemeData? theme,
}) {
  final effectiveTheme = theme ?? AppTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: barrierDismissible,
      barrierColor: effectiveTheme.barrier,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (c, animation, secondaryAnimation) => AppTheme(
        data: effectiveTheme,
        // 透明 Material 仅供 TextField 等需要 Material 祖先的组件使用，不绘制背景
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              // 弹窗打开即触发墨线描画入场（内容里消费
              // WiredDrawTransition.progressOf 的墨线参与绘制）
              child: WiredDraw(child: Builder(builder: builder)),
            ),
          ),
        ),
      ),
      transitionsBuilder: (c, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// 手绘对话框面板：标题 + 内容 + 操作按钮
class DSDialog extends StatelessWidget {
  const DSDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmText = '确定',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.confirmVariant = DSButtonVariant.primary,
  });

  final String title;

  /// 简单消息文本
  final String? message;

  /// 自定义内容（优先于 [message]）
  final Widget? content;
  final String confirmText;

  /// 为 null 时不显示取消按钮
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// 确认按钮变体（危险操作传 [DSButtonVariant.destructive]）
  final DSButtonVariant confirmVariant;

  void _defaultConfirm(BuildContext context) => Navigator.of(context).pop(true);
  void _defaultCancel(BuildContext context) => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // showDSDialog 已在内容外层包 WiredDraw，面板墨线随描画动画入场
    final progress = WiredDrawTransition.progressOf(context);

    // 大容器走手绘面板：纸底 + 淡排线 + 墨线框
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DsSketchPanel(
        theme: theme,
        radius: theme.radii.xxl,
        padding: EdgeInsets.all(theme.spacing.xl),
        progress: progress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SparkleRow(),
            SizedBox(height: theme.spacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
            if (content != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.md),
                child: content!,
              )
            else if (message != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.sm),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: DsTypography.caption.copyWith(color: theme.textSub),
                ),
              ),
            SizedBox(height: theme.spacing.xl),
            Row(
              children: [
                if (cancelText != null) ...[
                  Expanded(
                    child: DSButton(
                      label: cancelText!,
                      variant: DSButtonVariant.outline,
                      onPressed: onCancel ?? () => _defaultCancel(context),
                    ),
                  ),
                  SizedBox(width: theme.spacing.md),
                ],
                Expanded(
                  child: DSButton(
                    label: confirmText,
                    variant: confirmVariant,
                    onPressed: onConfirm ?? () => _defaultConfirm(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 标题上方的三颗小星星装饰（设计稿元素）
class _SparkleRow extends StatelessWidget {
  const _SparkleRow();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    const colors = [Color(0xFFFCD34D), Color(0xFFF5A8D4), Color(0xFF885CF6)];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < colors.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
            child: _Sparkle(color: colors[i], size: 10 + i * 5.0, spin: i == 1),
          ),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size, required this.spin});

  final Color color;
  final double size;
  final bool spin;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: spin ? 0.2 : 0,
      child: CustomPaint(
        size: Size.square(size),
        painter: _SparklePainter(color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..quadraticBezierTo(w * 0.58, h * 0.42, w, h * 0.5)
      ..quadraticBezierTo(w * 0.58, h * 0.58, w * 0.5, h)
      ..quadraticBezierTo(w * 0.42, h * 0.58, 0, h * 0.5)
      ..quadraticBezierTo(w * 0.42, h * 0.42, w * 0.5, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}
