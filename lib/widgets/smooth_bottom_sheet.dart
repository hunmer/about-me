import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aboutme/core/widgets/ds_theme_bridge.dart';
import 'package:aboutme/design_system/design_system.dart';
import 'package:aboutme/widgets/arc_context_menu.dart';
import 'package:skribble/skribble.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// 使用 smooth_sheets 实现的底部抽屉工具类
///
/// 提供类似于 showModalBottomSheet 的 API，但使用 smooth_sheets 实现
/// 特性：
/// - 流畅的拖拽动画
/// - 支持滑动关闭
/// - 手绘风格面板（DsSketchPanel 纸底排线 + 墨线框 + 描画入场）
/// - 手绘墨点拖拽指示器
/// - 标题栏统一走 DSTopBar 胶囊顶栏
class SmoothBottomSheet {
  /// 显示底部抽屉
  ///
  /// [context] - 上下文
  /// [builder] - 内容构建器
  /// [swipeDismissible] - 是否支持滑动关闭，默认 true
  /// [barrierDismissible] - 是否点击背景关闭，默认 true
  /// [backgroundColor] - 纸底色，默认使用主题 surface
  /// [borderRadius] - 顶部圆角半径，默认 20
  /// [showDragHandle] - 是否显示拖拽指示器，默认 true
  /// [enableDrag] - 是否启用拖拽，默认 true
  /// [minHeight] - 内容最小高度（含拖拽指示器），内容不足时撑开，默认不限制
  ///
  /// 抽屉高度上限为屏幕高度的 80%，超出部分由内容自行滚动。
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool swipeDismissible = true,
    bool barrierDismissible = true,
    Color? backgroundColor,
    double borderRadius = 20,
    bool showDragHandle = true,
    bool enableDrag = true,
    double? minHeight,
  }) {
    DsHaptics.surface();
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
            minHeight: minHeight,
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
  /// [headerActions] - 标题栏尾部操作区（可选）
  /// [showCloseButton] - 标题栏是否显示关闭（返回钮形式），默认 false
  /// 其他参数同 show 方法
  static Future<T?> showWithTitle<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    List<Widget>? headerActions,
    bool showCloseButton = false,
    bool swipeDismissible = true,
    bool barrierDismissible = true,
    Color? backgroundColor,
    double borderRadius = 20,
    bool showDragHandle = true,
    bool enableDrag = true,
    double? minHeight,
  }) {
    return show<T>(
      context: context,
      swipeDismissible: swipeDismissible,
      barrierDismissible: barrierDismissible,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      showDragHandle: showDragHandle,
      enableDrag: enableDrag,
      minHeight: minHeight,
      builder: (context) => _SheetWithTitle(
        title: title,
        showCloseButton: showCloseButton,
        actions: actions,
        headerActions: headerActions,
        child: child,
      ),
    );
  }

  /// 弹出按钮列表底部抽屉（数据与 ArcContextMenu.actions 的圆盘菜单共用）
  ///
  /// [actions] 与长按圆盘菜单用同一份 [ArcMenuItem] 列表，按钮点击自动
  /// 关闭抽屉再执行动作；作为圆盘"更多"的完整版弹层。
  /// [title] 为空时不显示标题栏（与原无标题 sheet 外观一致）。
  static Future<T?> showActionList<T>({
    required BuildContext context,
    required List<ArcMenuItem> actions,
    String? title,
  }) {
    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          SmoothSheetAction(
            icon: action.icon,
            label: action.label,
            destructive: action.destructive,
            onTap: () {
              Navigator.pop(context);
              action.onTap();
            },
          ),
      ],
    );
    return title == null
        ? show<T>(context: context, builder: (_) => list)
        : showWithTitle<T>(
            context: context,
            title: title,
            child: list,
          );
  }

  /// 表单底部弹层：高度贴合内容，超高可滚动
  ///
  /// 标题栏尾部放删除/保存（或关闭）按钮；表单自带标题头时可通过
  /// [showTitleBar] 关闭外壳标题栏避免重复。
  /// [onSave] 为 null 表示表单自动保存，尾部仅提供关闭。
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

  /// 整屏 Scaffold 页面塞进底部抽屉：隐藏拖拽指示条，
  /// 裁剪顶部圆角贴合抽屉外形（页面自带 AppBar）
  static Future<T?> showScreen<T>({
    required BuildContext context,
    required Widget screen,
  }) {
    return show<T>(
      context: context,
      showDragHandle: false,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: screen,
      ),
    );
  }
}

/// 底部抽屉内容容器：手绘面板（纸底 + 淡排线 + 墨线框）
class _SheetContent extends StatelessWidget {
  final Widget Function(BuildContext) builder;
  final Color? backgroundColor;
  final double borderRadius;
  final bool showDragHandle;
  final double? minHeight;

  const _SheetContent({
    required this.builder,
    this.backgroundColor,
    required this.borderRadius,
    required this.showDragHandle,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    // sheet 是新路由可能不在 AppTheme 树内，桥接出 DS 主题
    return DSThemeBridge(
      child: Material(
        type: MaterialType.transparency,
        // 打开即触发墨线描画入场（面板经 progressOf 消费进度）
        child: WiredDraw(
          child: Builder(
            builder: (context) {
              final theme = AppTheme.of(context);
              return DsSketchPanel(
                theme: theme,
                fillColor: backgroundColor,
                radius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
                progress: WiredDrawTransition.progressOf(context),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minHeight ?? 0,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.8,
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
            },
          ),
        ),
      ),
    );
  }

  /// 构建拖拽指示器：五段手绘墨点线
  Widget _buildDragHandle(AppThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        top: theme.spacing.sm,
        bottom: theme.spacing.xs,
      ),
      child: const SizedBox(width: 60, child: DSDivider()),
    );
  }
}

/// 带标题的底部抽屉内容：DSTopBar 胶囊标题栏
class _SheetWithTitle extends StatelessWidget {
  final String title;
  final bool showCloseButton;
  final List<Widget>? actions;
  final List<Widget>? headerActions;
  final Widget child;

  const _SheetWithTitle({
    required this.title,
    required this.showCloseButton,
    this.actions,
    this.headerActions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DSThemeBridge(
      child: Builder(
        builder: (context) {
          final theme = AppTheme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏：手绘胶囊顶栏，返回钮即关闭
              Padding(
                padding: EdgeInsets.fromLTRB(
                  theme.spacing.lg,
                  theme.spacing.xs,
                  theme.spacing.lg,
                  theme.spacing.xs,
                ),
                child: DSTopBar(
                  title: title,
                  onBack:
                      showCloseButton ? () => Navigator.of(context).pop() : null,
                  actions: headerActions,
                ),
              ),

              // 内容 - Flexible 限高，超高时由内容自行滚动
              Flexible(child: child),

              // 底部操作按钮
              if (actions != null && actions!.isNotEmpty) ...[
                DSDivider(),
                Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
              ],
            ],
          );
        },
      ),
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
          final theme = AppTheme.of(context);
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
        theme.spacing.lg,
        theme.spacing.xs,
        theme.spacing.lg,
        theme.spacing.xs,
      ),
      child: DSTopBar(
        title: title,
        // 操作按钮统一放尾部：删除 + 保存/关闭
        actions: [
          if (onDelete != null) ...[
            DSIconButton(
              icon: DsIconKind.trash,
              size: 36,
              color: theme.surfaceAlt,
              iconColor: theme.danger,
              onPressed: onDelete,
            ),
            SizedBox(width: theme.spacing.sm),
          ],
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
