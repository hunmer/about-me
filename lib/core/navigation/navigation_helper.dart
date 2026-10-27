import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:full_swipe_back_gesture/full_swipe_back_gesture.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:aboutme/widgets/smooth_bottom_sheet.dart';
import 'package:aboutme/screens/route.dart';
import 'package:aboutme/screens/routing/route_helpers.dart';
import 'package:aboutme/core/widgets/app_background.dart';

import 'open_container_route.dart';
export 'open_container_route.dart';

/// 跨平台导航助手
///
/// 提供统一的导航接口，自动根据平台选择合适的路由类型：
/// - iOS: CupertinoPageRoute (支持原生左滑返回)
/// - Android: MaterialPageRoute
///
/// 使用示例：
/// ```dart
/// // 推送到新页面
/// NavigationHelper.push(
///   context,
///   const DetailScreen(),
/// );
///
/// // 替换当前页面
/// NavigationHelper.pushReplacement(
///   context,
///   const HomeScreen(),
/// );
///
/// // 带参数推送
/// NavigationHelper.push(
///   context,
///   DetailScreen(id: '123'),
/// );
/// ```
class NavigationHelper {
  /// 检查是否为 iOS 平台
  static bool get _isIOS => UniversalPlatform.isIOS;

  // ==================== 基础 push 导航 ====================

  /// 推送到新页面
  ///
  /// [context] BuildContext
  /// [page] 要推送的页面
  /// [maintainState] 是否保持状态（默认 true）
  /// [fullscreenDialog] 是否全屏对话框（默认 false）
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? routeName,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    final settings = routeName != null ? RouteSettings(name: routeName) : null;

    if (_isIOS) {
      return Navigator.of(context).push<T>(
        CupertinoPageRoute<T>(
          builder: (context) => page,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
          settings: settings,
        ),
      );
    } else {
      // 零时长路由（MaterialPageRoute 的 300ms 转场会让透明背景页面
      // 透出下层旧页面，造成切换叠影），见 RouteHelpers.createRoute
      return Navigator.of(
        context,
      ).push<T>(RouteHelpers.createRoute<T>(page, settings: settings));
    }
  }

  /// 推送带 Hero 飞行动画的页面
  ///
  /// 零时长路由会让 Hero 瞬移（等同失效），此方法改用带转场时长的
  /// Hero 路由（见 [RouteHelpers.createHeroRoute]），适用于列表 →
  /// 详情有共享元素过渡的场景
  static Future<T?> pushHero<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? routeName,
  }) {
    final settings = routeName != null ? RouteSettings(name: routeName) : null;
    return Navigator.of(
      context,
    ).push<T>(RouteHelpers.createHeroRoute<T>(page, settings: settings));
  }

  /// 推送带转场动画的子页面（常规"打开子页面"入口）
  ///
  /// iOS 用 CupertinoPageRoute（原生左滑返回）；其他平台用 Material
  /// 标准转场（滑动/淡入，见 [RouteHelpers.createAnimatedRoute]），
  /// 代替 [push] 在非 iOS 平台的零时长瞬切
  static Future<T?> pushAnimated<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? routeName,
  }) {
    if (_isIOS) {
      return push<T>(context, page, routeName: routeName);
    }
    final settings = routeName != null ? RouteSettings(name: routeName) : null;
    return Navigator.of(
      context,
    ).push<T>(RouteHelpers.createAnimatedRoute<T>(page, settings: settings));
  }

  /// 推送到新页面（带命名路由）
  ///
  /// [context] BuildContext
  /// [routeName] 路由名称
  /// [arguments] 传递的参数
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// 推送到新页面（带命名路由和参数生成器）
  ///
  /// [context] BuildContext
  /// [routeName] 路由名称
  /// [arguments] 传递的参数
  static Future<T?> pushNamedWithArg<T extends Object?>(
    BuildContext context,
    String routeName,
    Map<String, dynamic> arguments,
  ) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  // ==================== 替换导航 ====================

  /// 替换当前页面
  ///
  /// [context] BuildContext
  /// [newPage] 新页面
  /// [result] 返回给上一个页面的结果
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget newPage, {
    String? routeName,
    TO? result,
    bool maintainState = true,
  }) {
    final settings = routeName != null ? RouteSettings(name: routeName) : null;
    if (_isIOS) {
      return Navigator.of(context).pushReplacement<T, TO>(
        CupertinoPageRoute<T>(
          builder: (context) => newPage,
          maintainState: maintainState,
          settings: settings,
        ),
        result: result,
      );
    } else {
      // 零时长路由，理由同 push
      return Navigator.of(context).pushReplacement<T, TO>(
        RouteHelpers.createRoute<T>(newPage, settings: settings),
        result: result,
      );
    }
  }

  /// 替换当前页面（带命名路由）
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  // ==================== 弹出并推送 ====================

  /// 弹出当前页面并推送新页面
  ///
  /// [context] BuildContext
  /// [newPage] 新页面
  static Future<T?> pushAndPop<T extends Object?>(
    BuildContext context,
    Widget newPage,
  ) {
    return Navigator.of(
      context,
    ).pushAndRemoveUntil<T>(_createRoute(context, newPage), (route) => false);
  }

  /// 弹出当前页面并推送新页面（带命名路由）
  static Future<T?> pushNamedAndPopUntil<T extends Object?>(
    BuildContext context,
    String routeName,
  ) {
    return Navigator.of(
      context,
    ).pushNamedAndRemoveUntil<T>(routeName, (route) => false);
  }

  // ==================== 移除直到导航 ====================

  /// 推送新页面并移除栈中的页面
  ///
  /// [context] BuildContext
  /// [newPage] 新页面
  /// [predicate] 保留页面的条件
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    Widget newPage,
    RoutePredicate predicate, {
    String? routeName,
  }) {
    final settings = routeName != null ? RouteSettings(name: routeName) : null;
    return Navigator.of(context).pushAndRemoveUntil<T>(
      RouteHelpers.createRoute<T>(newPage, settings: settings),
      predicate,
    );
  }

  /// 推送新页面并移除栈中的页面（带命名路由）
  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    return Navigator.of(
      context,
    ).pushNamedAndRemoveUntil<T>(routeName, predicate, arguments: arguments);
  }

  // ==================== 弹出导航 ====================

  /// 弹出页面
  ///
  /// [context] BuildContext
  /// [result] 返回给上一个页面的结果
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }

  /// 弹出直到指定条件
  ///
  /// [context] BuildContext
  /// [predicate] 停止弹出的条件
  static void popUntil(BuildContext context, RoutePredicate predicate) {
    Navigator.of(context).popUntil(predicate);
  }

  /// 弹出到根页面
  ///
  /// [context] BuildContext
  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ==================== 返回路由决策 ====================

  /// 返回目标路由表：当前路由名 → 点返回时应去到的路由名
  ///
  /// 命中表项或前缀规则时不再按 Navigator 栈逐层返回，而是直接清栈
  /// 跳到目标路由；未命中则走默认 maybePop 返回上一页
  static const Map<String, String> _backRouteMap = {
    // 需要固定返回目标的页面在此登记，例如：
    // '/some_screen': AppRoutes.jellyHome,
  };

  /// 插件主界面路由前缀（PluginManager.openPlugin 推入的 `/plugin/<id>`）：
  /// 固定返回首页，避免恢复栈中上一次打开的插件
  static const String _pluginRoutePrefix = '/plugin/';

  /// 解析返回目标；返回 null 表示走默认返回上一页
  static String? resolveBackDestination(String? currentRouteName) {
    if (currentRouteName == null) return null;
    final mapped = _backRouteMap[currentRouteName];
    if (mapped != null) return mapped;
    if (currentRouteName.startsWith(_pluginRoutePrefix)) {
      return AppRoutes.jellyHome;
    }
    return null;
  }

  /// 统一返回入口：根据当前路由名查表决定去向
  static void smartBack(BuildContext context) {
    final currentName = ModalRoute.of(context)?.settings.name;
    final destination = resolveBackDestination(currentName);
    debugPrint('[smartBack] 当前路由: $currentName → ${destination ?? '默认返回上一页'}');
    if (destination == null) {
      Navigator.maybePop(context);
      return;
    }
    if (destination == AppRoutes.jellyHome) {
      returnToHome(context);
    } else {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    }
  }

  /// 返回小屋：优先复用已有页面；启动恢复场景没有小屋栈时重新创建。
  /// 小屋切换页签会把路由名原地改写为 `/jelly_home/<n>`，按前缀一并识别
  static void returnToHome(BuildContext context) {
    final navigator = Navigator.of(context);
    var hasHomeRoute = false;
    navigator.popUntil((route) {
      if (isJellyHomeRoute(route.settings.name)) {
        hasHomeRoute = true;
        return true;
      }
      return route.isFirst;
    });
    if (!hasHomeRoute) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.jellyHome, (route) => false);
    }
  }

  /// 是否小屋主页路由（含页签段 `/jelly_home/<n>`）
  static bool isJellyHomeRoute(String? name) =>
      name == AppRoutes.jellyHome ||
      (name?.startsWith('${AppRoutes.jellyHome}/') ?? false);

  // ==================== 对话框和底部弹窗 ====================

  /// 显示模态对话框
  ///
  /// [context] BuildContext
  /// [dialog] 对话框组件
  /// [barrierDismissible] 是否可点击外部关闭
  /// [barrierColor] 遮罩颜色
  static Future<T?> showCustomDialog<T extends Object?>(
    BuildContext context,
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => dialog,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
    );
  }

  /// 显示底部弹窗
  static Future<T?> showModalBottomSheet<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    bool isScrollControlled = false,
  }) {
    return SmoothBottomSheet.show<T>(context: context, builder: builder);
  }

  // ==================== iOS 专用导航 ====================

  /// iOS 风格的页面转场动画（仅 iOS 有效）
  ///
  /// [context] BuildContext
  /// [page] 页面
  /// [fullscreenDialog] 是否全屏对话框
  static Future<T?> pushIOS<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      CupertinoPageRoute<T>(
        builder: (context) => page,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// 显示 iOS 风格对话框（所有平台）
  static Future<T?> showCupertinoDialog<T extends Object?>(
    BuildContext context,
    Widget dialog, {
    bool barrierDismissible = true,
  }) {
    return showCupertinoDialog<T>(
      context,
      dialog,
      barrierDismissible: barrierDismissible,
    );
  }

  /// 显示 iOS 风格的操作表
  static Future<T?> showCupertinoActionSheet<T extends Object?>(
    BuildContext context,
    Widget actionsSheet,
  ) {
    return showCupertinoActionSheet<T>(context, actionsSheet);
  }

  // ==================== Android 专用导航 ====================

  /// Android 风格的页面转场（仅 Android 有效）
  ///
  /// [context] BuildContext
  /// [page] 页面
  /// [fullscreenDialog] 是否全屏对话框
  static Future<T?> pushAndroid<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (context) => page,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  // ==================== 私有辅助方法 ====================

  /// 创建路由（根据平台自动选择）
  static Route<T> _createRoute<T extends Object?>(
    BuildContext context,
    Widget page,
  ) {
    if (_isIOS) {
      return CupertinoPageRoute<T>(builder: (context) => page);
    } else {
      return NavigationHelper.createRoute(page);
    }
  }

  /// 创建路由（公开方法）
  ///
  /// [page] 页面Widget
  /// [fullscreenDialog] 是否全屏对话框（仅 iOS 生效）
  /// [maintainState] 是否保持状态
  static Route<T> createRoute<T extends Object?>(
    Widget page, {
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) {
    if (UniversalPlatform.isIOS) {
      return CupertinoPageRoute<T>(
        builder: (context) => page,
        fullscreenDialog: fullscreenDialog,
        maintainState: maintainState,
      );
    } else {
      // 零时长路由，理由同 push
      return RouteHelpers.createRoute<T>(page);
    }
  }

  // ==================== 工具方法 ====================

  /// 检查是否可以在当前上下文弹出
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  /// 获取当前路由名称
  static String? getCurrentRouteName(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.settings.name;
  }

  /// 检查是否为根路由
  static bool isFirstRouteInStack(BuildContext context) {
    return !Navigator.of(context).canPop();
  }

  // ==================== OpenContainer 替代方法 ====================

  /// 使用 BackSwipePageRoute 导航到新页面
  ///
  /// @deprecated 请使用 [openContainerWithHero] 替代，支持 OpenContainer 展开动画
  static Future<T?> openContainer<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve pushCurve = Curves.easeInOut,
    Curve popCurve = Curves.easeInOut,
    Color? closedColor,
    double? closedElevation,
    ShapeBorder? closedShape,
    Color? openColor,
    double? openElevation,
  }) {
    return openContainerWithHero<T>(
      context,
      builder,
      transitionDuration: transitionDuration,
      pushCurve: pushCurve,
      popCurve: popCurve,
      closedColor: closedColor,
      openColor: openColor,
      closedShape:
          closedShape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
    );
  }

  /// 使用 OpenContainer 风格导航到新页面
  ///
  /// 从源 widget 位置放大展开到全屏，实现 Material Design 的容器转换效果。
  ///
  /// [context] BuildContext
  /// [builder] 页面构建器
  /// [sourceKey] 源 widget 的 GlobalKey（用于获取位置，启用展开动画）
  /// [heroTag] 可选的标识符，用于路由命名
  /// [transitionDuration] 转场动画时长
  /// [closedBuilder] 关闭状态的构建器（用于过渡动画）
  /// [closedColor] 关闭状态的背景色
  /// [openColor] 打开状态的背景色
  /// [closedShape] 关闭状态的形状（默认圆角 12）
  /// [openShape] 打开状态的形状（默认直角）
  /// [onClosed] 页面关闭时的回调
  static Future<T?> openContainerWithHero<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    String? heroTag,
    GlobalKey? sourceKey,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve pushCurve = Curves.easeInOut,
    Curve popCurve = Curves.easeInOut,
    WidgetBuilder? closedBuilder,
    Color? closedColor,
    Color? openColor,
    ShapeBorder closedShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
    ),
    ShapeBorder openShape = const RoundedRectangleBorder(),
    void Function(T?)? onClosed,
  }) async {
    // 生成默认的 heroTag
    final tag =
        heroTag ?? 'open_container_${DateTime.now().millisecondsSinceEpoch}';

    // 如果提供了 sourceKey，使用 OpenContainer 动画
    if (sourceKey != null) {
      final result = await openContainerFromKey<T>(
        context: context,
        sourceKey: sourceKey,
        openBuilder: builder,
        closedBuilder: closedBuilder,
        closedColor: closedColor,
        openColor: openColor,
        closedShape: closedShape,
        openShape: openShape,
        transitionDuration: transitionDuration,
        routeSettings: RouteSettings(name: 'open_container_$tag'),
      );
      onClosed?.call(result);
      return result;
    }

    // 降级：没有 sourceKey 时使用普通路由
    // BackSwipePageRoute 为 opaque=false（全滑返回需透出下层），全局
    // 背景生效时页面透明会透出下层旧页面；在路由内垫一层 AppBackground
    // （完整全局背景：底色+网格+背景图）替代根层背景。无全局背景时
    // AppBackground 原样透传，行为不变
    final result = await Navigator.of(context).push<T>(
      BackSwipePageRoute<T>(
        builder: (_) => AppBackground(child: builder(context)),
        transitionDuration: transitionDuration,
        pushCurve: pushCurve,
        popCurve: popCurve,
        settings: RouteSettings(name: 'hero_route_$tag'),
      ),
    );
    onClosed?.call(result);
    return result;
  }

  /// 使用 OpenContainer 风格导航（通过 GlobalKey）
  ///
  /// 这是更直接的 API，无需 heroTag 参数。
  ///
  /// [context] BuildContext
  /// [sourceKey] 源 widget 的 GlobalKey（必需）
  /// [openBuilder] 打开状态页面构建器
  /// [closedBuilder] 关闭状态的构建器（可选，用于过渡动画中显示）
  /// [closedColor] 关闭状态的背景色
  /// [openColor] 打开状态的背景色
  /// [closedShape] 关闭状态的形状
  /// [openShape] 打开状态的形状
  /// [transitionDuration] 过渡动画时长
  static Future<T?> openContainerTransition<T extends Object?>(
    BuildContext context, {
    required GlobalKey sourceKey,
    required WidgetBuilder openBuilder,
    WidgetBuilder? closedBuilder,
    Color? closedColor,
    Color? openColor,
    ShapeBorder closedShape = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12.0)),
    ),
    ShapeBorder openShape = const RoundedRectangleBorder(),
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return openContainerFromKey<T>(
      context: context,
      sourceKey: sourceKey,
      openBuilder: openBuilder,
      closedBuilder: closedBuilder,
      closedColor: closedColor,
      openColor: openColor,
      closedShape: closedShape,
      openShape: openShape,
      transitionDuration: transitionDuration,
    );
  }
}

/// 扩展 BuildContext，提供便捷的导航方法
extension NavigationExtensions on BuildContext {
  /// 推送到新页面
  Future<T?> pushPage<T extends Object?>(
    Widget page, {
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return NavigationHelper.push<T>(
      this,
      page,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );
  }

  /// 替换当前页面
  Future<T?> pushReplacementPage<T extends Object?, TO extends Object?>(
    Widget newPage, {
    TO? result,
    bool maintainState = true,
  }) {
    return NavigationHelper.pushReplacement<T, TO>(
      this,
      newPage,
      result: result,
      maintainState: maintainState,
    );
  }

  /// 弹出页面
  void popPage<T extends Object?>([T? result]) {
    NavigationHelper.pop<T>(this, result);
  }

  /// 显示对话框
  Future<T?> showPageDialog<T extends Object?>(
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return NavigationHelper.showCustomDialog<T>(
      this,
      dialog,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
    );
  }

  /// 显示底部弹窗
  Future<T?> showPageBottomSheet<T extends Object?>(
    WidgetBuilder builder, {
    bool isScrollControlled = false,
  }) {
    return SmoothBottomSheet.show<T>(context: this, builder: builder);
  }

  /// 打开容器页面
  ///
  /// @deprecated 请使用 [openContainerWithHero] 替代
  @Deprecated('请使用 openContainerWithHero 替代')
  Future<T?> openContainer<T extends Object?>(
    WidgetBuilder builder, {
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve pushCurve = Curves.easeInOut,
    Curve popCurve = Curves.easeInOut,
    Color? closedColor,
    double? closedElevation,
    ShapeBorder? closedShape,
    Color? openColor,
    double? openElevation,
  }) {
    return openContainerWithHero<T>(
      builder,
      transitionDuration: transitionDuration,
      pushCurve: pushCurve,
      popCurve: popCurve,
      closedColor: closedColor,
      openColor: openColor,
      closedShape: closedShape,
    );
  }

  /// 打开容器页面（支持 OpenContainer 展开动画）
  ///
  /// [sourceKey] 源 widget 的 GlobalKey，提供时启用展开动画
  /// [heroTag] 可选的标识符，用于路由命名
  Future<T?> openContainerWithHero<T extends Object?>(
    WidgetBuilder builder, {
    String? heroTag,
    GlobalKey? sourceKey,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve pushCurve = Curves.easeInOut,
    Curve popCurve = Curves.easeInOut,
    WidgetBuilder? closedBuilder,
    Color? closedColor,
    Color? openColor,
    ShapeBorder? closedShape,
    void Function(T?)? onClosed,
  }) {
    return NavigationHelper.openContainerWithHero<T>(
      this,
      builder,
      heroTag: heroTag,
      sourceKey: sourceKey,
      transitionDuration: transitionDuration,
      pushCurve: pushCurve,
      popCurve: popCurve,
      closedBuilder: closedBuilder,
      closedColor: closedColor,
      openColor: openColor,
      closedShape:
          closedShape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
      onClosed: onClosed,
    );
  }
}
