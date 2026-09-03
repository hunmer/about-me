import 'package:flutter/material.dart';
import 'package:aboutme/design_system/design_system.dart';

/// Material → 设计系统主题桥
///
/// 设计系统组件依赖 `AppTheme.of(context)`，而普通 Material 页面没有
/// AppTheme 祖先。此桥读取 Material 亮暗模式，向下提供对应的
/// [AppThemeData]，让 DS 组件可以在任何 Material 页面中直接使用。
///
/// 已存在相同亮暗的 AppTheme 时直接透传，避免重复包裹。
class DSThemeBridge extends StatelessWidget {
  const DSThemeBridge({super.key, required this.child, this.forceDark});

  final Widget child;

  /// 强制指定亮暗（为 null 时跟随 Material 主题）
  final bool? forceDark;

  /// 在任意 Material context 上解析 DS 主题：
  /// 已有 AppTheme 用之，否则按 Material 亮暗派生。永不抛错。
  ///
  /// 适用于向 [showDSDialog] / [showDSToast] 这类在调用点捕获主题的
  /// 函数传参——当调用点可能位于主题树之外（独立路由）时使用。
  static AppThemeData resolve(BuildContext context) {
    final existing = AppTheme.maybeOf(context);
    if (existing != null) return existing;
    return Theme.of(context).brightness == Brightness.dark
        ? AppThemeData.dark()
        : AppThemeData.light();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = forceDark ?? Theme.of(context).brightness == Brightness.dark;
    final existing = AppTheme.maybeOf(context);
    if (existing != null && existing.isDark == isDark) {
      return child;
    }
    return AppTheme(
      data: isDark ? AppThemeData.dark() : AppThemeData.light(),
      child: child,
    );
  }
}
