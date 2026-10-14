import 'package:flutter/material.dart';

import 'package:aboutme/core/services/app_background_controller.dart';
import 'package:aboutme/core/services/ds_ink_style_controller.dart';
import 'package:aboutme/core/services/ds_theme_color_controller.dart';
import 'package:aboutme/design_system/design_system.dart';

/// 全局自定义背景（背景图/纯色/网格）生效时返回透明以透出根部全局
/// 背景层，否则返回 [fallback]
Color dsTransparentWhenGlobalBackground(Color fallback) =>
    AppBackgroundController().hasCustomBackground
        ? DsColors.transparent
        : fallback;

/// 页面 Scaffold 背景色：设置了全局自定义背景（背景图/纯色/网格）时
/// 返回透明以透出根部全局背景层，否则用 DS 主题背景色。
/// 仅用于页面级 Scaffold/AppBar；弹窗、底部弹层等浮层不要使用
/// （浮层透明会与底下内容穿叠）
Color dsScaffoldBackground(AppThemeData theme) =>
    dsTransparentWhenGlobalBackground(theme.background);

/// Material → 设计系统主题桥
///
/// 设计系统组件依赖 `AppTheme.of(context)`，而普通 Material 页面没有
/// AppTheme 祖先。此桥读取 Material 亮暗模式，向下提供对应的
/// [AppThemeData]，让 DS 组件可以在任何 Material 页面中直接使用。
///
/// 已存在相同亮暗的 AppTheme 时直接透传，避免重复包裹。
///
/// 主题数据由 [DsThemeColorController] 当前色板派生：根部桥监听
/// 控制器，切换色板后重建主题树全局生效；下层桥因透传逻辑零开销。
class DSThemeBridge extends StatelessWidget {
  const DSThemeBridge({super.key, required this.child, this.forceDark});

  final Widget child;

  /// 强制指定亮暗（为 null 时跟随 Material 主题）
  final bool? forceDark;

  /// 在任意 Material context 上解析 DS 主题：
  /// 已有 AppTheme 用之，否则按 Material 亮暗 + 当前色板派生。永不抛错。
  ///
  /// 适用于向 [showDSDialog] / [showDSToast] 这类在调用点捕获主题的
  /// 函数传参——当调用点可能位于主题树之外（独立路由）时使用。
  static AppThemeData resolve(BuildContext context) {
    final existing = AppTheme.maybeOf(context);
    if (existing != null) return existing;
    final controller = DsThemeColorController();
    return AppThemeData.fromPalette(
      controller.palette,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // 合并监听：色板与墨线档位任一变化都重建主题树
      listenable: Listenable.merge([
        DsThemeColorController(),
        DsInkStyleController(),
      ]),
      builder: (context, _) {
        final isDark =
            forceDark ?? Theme.of(context).brightness == Brightness.dark;
        final existing = AppTheme.maybeOf(context);
        if (existing != null && existing.isDark == isDark) {
          return child;
        }
        return AppTheme(
          data: AppThemeData.fromPalette(
            DsThemeColorController().palette,
            isDark: isDark,
          ),
          child: child,
        );
      },
    );
  }
}
