import 'package:flutter/widgets.dart';

import '../primitives/pressable.dart';
import '../theme/app_theme.dart';
import '../tokens/typography.dart';
import 'icons.dart';

/// 手绘底部面板：自底部滑入 + 遮罩，点遮罩关闭
Future<T?> showDSBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  bool barrierDismissible = true,
}) {
  final theme = AppTheme.of(context);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: barrierDismissible,
      barrierColor: theme.barrier,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (c, animation, secondaryAnimation) => AppTheme(
        data: theme,
        child: _SheetScaffold(title: title, builder: builder),
      ),
      transitionsBuilder: (c, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.builder, this.title});

  final WidgetBuilder builder;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      // 大容器走手绘面板：纸底 + 淡排线 + 墨线框（顶部大圆角，纸色铺满安全区）
      child: DsSketchPanel(
        theme: theme,
        width: double.infinity,
        radius: BorderRadius.vertical(
          top: Radius.circular(theme.radii.xxlValue + 4),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽把手：纯色小条 + 淡墨描边（过小无法走 rough 引擎）
            Container(
              margin: EdgeInsets.symmetric(vertical: theme.spacing.md),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: theme.surfaceAlt,
                borderRadius: theme.radii.pill,
                border: Border.all(
                  color: theme.ink.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: EdgeInsets.only(
                  left: theme.spacing.xl,
                  right: theme.spacing.xl,
                  bottom: theme.spacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: DsTypography.heading.copyWith(color: theme.text),
                      ),
                    ),
                    Pressable(
                      onPressed: () => Navigator.of(context).pop(),
                      builder: (context, states) => DsIcon(
                        DsIconKind.close,
                        size: 20,
                        color: theme.textSub,
                      ),
                    ),
                  ],
                ),
              ),
            Flexible(child: builder(context)),
            SizedBox(height: theme.spacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 底部面板操作行：图标 + 文字 + 尾部控件（配合 [showDSBottomSheet]）
class DSSheetAction extends StatelessWidget {
  const DSSheetAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final DsIconKind icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// 危险操作（红色调）
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final tint = destructive ? theme.danger : theme.primary;

    return Pressable(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        final pressed = states.contains(WidgetState.pressed);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.xl,
            vertical: theme.spacing.md + 2,
          ),
          color: pressed
              ? theme.surfaceAlt
              : hovered
              ? theme.surfaceAlt.withValues(alpha: 0.55)
              : DsColors.transparent,
          child: Row(
            children: [
              DsIcon(icon, size: 20, color: tint),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.body.copyWith(
                    color: destructive ? theme.danger : theme.text,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        );
      },
    );
  }
}
