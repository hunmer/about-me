import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// 使用 smooth_sheets 实现的底部抽屉工具类
///
/// 提供类似于 showModalBottomSheet 的 API，但使用 smooth_sheets 实现
/// 特性：
/// - 流畅的拖拽动画
/// - 支持滑动关闭
/// - 自动适配主题
/// - 统一的拖拽指示器
class SmoothBottomSheet {
  /// 显示底部抽屉
  ///
  /// [context] - 上下文
  /// [builder] - 内容构建器
  /// [swipeDismissible] - 是否支持滑动关闭，默认 true
  /// [barrierDismissible] - 是否点击背景关闭，默认 true
  /// [backgroundColor] - 背景色，默认使用主题背景色
  /// [borderRadius] - 圆角半径，默认 20
  /// [showDragHandle] - 是否显示拖拽指示器，默认 true
  /// [enableDrag] - 是否启用拖拽，默认 true
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool swipeDismissible = true,
    bool barrierDismissible = true,
    Color? backgroundColor,
    double borderRadius = 20,
    bool showDragHandle = true,
    bool enableDrag = true,
  }) {
    return Navigator.of(context).push<T>(
      ModalSheetRoute(
        swipeDismissible: swipeDismissible,
        barrierDismissible: barrierDismissible,
        builder: (context) => Sheet(
          child: _SheetContent(
            builder: builder,
            backgroundColor: backgroundColor,
            borderRadius: borderRadius,
            showDragHandle: showDragHandle,
          ),
        ),
      ),
    );
  }

  /// 显示带标题的底部抽屉
  ///
  /// [context] - 上下文
  /// [title] - 标题文本
  /// [child] - 内容组件
  /// [actions] - 底部操作按钮列表（可选）
  /// [showCloseButton] - 是否显示关闭按钮，默认 false
  /// 其他参数同 show 方法
  static Future<T?> showWithTitle<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    bool showCloseButton = false,
    bool swipeDismissible = true,
    bool barrierDismissible = true,
    Color? backgroundColor,
    double borderRadius = 20,
    bool showDragHandle = true,
    bool enableDrag = true,
  }) {
    return show<T>(
      context: context,
      swipeDismissible: swipeDismissible,
      barrierDismissible: barrierDismissible,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      showDragHandle: showDragHandle,
      enableDrag: enableDrag,
      builder: (context) => _SheetWithTitle(
        title: title,
        showCloseButton: showCloseButton,
        actions: actions,
        child: child,
      ),
    );
  }

  /// 表单底部弹层：高度贴合内容，超高可滚动
  ///
  /// 标题栏左侧可选删除按钮；右上角为提交按钮（[onSave]）或关闭按钮。
  /// [onSave] 为 null 表示表单自动保存，右上角仅提供关闭。
  /// 表单自带标题头时可通过 [showTitleBar] 关闭外壳标题栏避免重复。
  static Future<T?> showForm<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    VoidCallback? onSave,
    VoidCallback? onDelete,
    bool showTitleBar = true,
    bool swipeDismissible = true,
    bool barrierDismissible = true,
  }) {
    return show<T>(
      context: context,
      swipeDismissible: swipeDismissible,
      barrierDismissible: barrierDismissible,
      builder: (context) => _FormSheetContent(
        title: title,
        onSave: onSave,
        onDelete: onDelete,
        showTitleBar: showTitleBar,
        child: child,
      ),
    );
  }
}

/// 底部抽屉内容容器
class _SheetContent extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showDragHandle;

  const _SheetContent({
    required this.builder,
    this.backgroundColor,
    required this.borderRadius,
    required this.showDragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // scaffold 色在全局背景生效时被透明化，sheet 作为浮层不能透明，
    // 回退全局背景底色保持不透明
    final bgColor =
        backgroundColor ?? dsNonOpaqueRouteBackdrop(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(borderRadius),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            if (showDragHandle) _buildDragHandle(theme),

            // 内容 - 使用 Flexible 包裹以允许动态高度
            Flexible(
              child: builder(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建拖拽指示器
  Widget _buildDragHandle(ThemeData theme) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// 带标题的底部抽屉内容
class _SheetWithTitle extends StatelessWidget {
  final String title;
  final bool showCloseButton;
  final List<Widget>? actions;
  final Widget child;

  const _SheetWithTitle({
    required this.title,
    required this.showCloseButton,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              // 标题
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 关闭按钮
              if (showCloseButton)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 内容
        child,

        // 底部操作按钮
        if (actions != null && actions!.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions!,
            ),
          ),
        ],
      ],
    );
  }
}

/// 表单弹层内容：固定标题栏 + 可滚动内容 + 底部安全区
///
/// 内容用 shrinkWrap ListView 包裹：短表单贴合内容高度，
/// 超出可用高度时恰好撑满并内部滚动。
class _FormSheetContent extends StatelessWidget {
  final String title;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final bool showTitleBar;
  final Widget child;

  const _FormSheetContent({
    required this.title,
    this.onSave,
    this.onDelete,
    required this.showTitleBar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = DSThemeBridge.resolve(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTitleBar) _buildTitleBar(context, theme),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [child],
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        theme.spacing.sm,
        theme.spacing.md,
        theme.spacing.sm,
      ),
      child: Row(
        children: [
          // 标题靠左
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: DsTypography.title.copyWith(color: theme.text),
            ),
          ),
          // 操作按钮统一靠右
          if (onDelete != null) ...[
            SizedBox(width: theme.spacing.sm),
            DSIconButton(
              icon: DsIconKind.trash,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: onDelete,
            ),
          ],
          SizedBox(width: theme.spacing.sm),
          if (onSave != null)
            DSButton(
              label: 'app_save'.tr,
              size: DSButtonSize.sm,
              icon: DsIconKind.check,
              onPressed: onSave,
            )
          else
            DSIconButton(
              icon: DsIconKind.close,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.textSub,
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

/// 底部面板操作行：图标 + 文字 + 尾部控件（配合 [SmoothBottomSheet]）
class SmoothSheetAction extends StatelessWidget {
  const SmoothSheetAction({
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
    final theme = DSThemeBridge.resolve(context);
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
