import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';

import 'package:aboutme/core/widgets/app_background.dart';

/// 路由辅助工具类
class RouteHelpers {
  /// 创建路由
  ///
  /// iOS: CupertinoPageRoute（支持原生左滑返回，转场可见）
  /// 其他平台: 零时长路由。不能用 MaterialPageRoute——其 300ms 转场
  /// 控制器不随 NoAnimationPageTransitionsBuilder 缩短，动画完成前
  /// 下层路由保持绘制，透明背景页面会透出旧页面造成叠影
  ///
  /// [useAnimation] 仅 iOS 生效（false 时 iOS 也用零时长路由）
  static Route<T> createRoute<T extends Object?>(
    Widget page, {
    RouteSettings? settings,
    bool useAnimation = true,
  }) {
    if (useAnimation && UniversalPlatform.isIOS) {
      return CupertinoPageRoute<T>(
        settings: settings,
        builder: (context) => page,
      );
    }
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
      transitionDuration: const Duration(milliseconds: 0),
      reverseTransitionDuration: const Duration(milliseconds: 0),
    );
  }

  /// 创建无动画路由（便捷方法）
  static Route createRouteWithoutAnimation(Widget page, {RouteSettings? settings}) {
    return createRoute(page, settings: settings, useAnimation: false);
  }

  /// 创建 Hero 飞行动画路由
  ///
  /// Hero 飞行时长取决于路由 [TransitionRoute.transitionDuration]，
  /// 零时长路由的 Hero 会瞬移（等同失效）。本路由保留转场时长供
  /// Hero 飞行，同时规避透明背景页面的叠影问题：
  /// - 进入：页面无视觉转场（瞬时全屏），且垫一层 AppBackground
  ///   （全局背景生效时为不透明背景，无全局背景时透传），转场期间
  ///   下层旧页面保持绘制也不会透出；
  /// - 返回：路由整体淡出，透出下层列表页承接 Hero 落点。
  static Route<T> createHeroRoute<T extends Object?>(
    Widget page, {
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) =>
          AppBackground(child: page),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final opacity =
                animation.status == AnimationStatus.reverse
                ? animation.value
                : 1.0;
            return Opacity(opacity: opacity, child: child);
          },
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: duration,
    );
  }

  /// 创建错误页面路由（无动画）
  static Route createErrorRoute(
    String titleKey,
    String messageKey, {
    String? messageParam,
  }) {
    return PageRouteBuilder(
      settings: RouteSettings(name: '/error'),
      pageBuilder: (context, animation, secondaryAnimation) {
        String title;
        String message;

        // 根据键获取本地化文本
        switch (titleKey) {
          case 'error':
            title = 'screens_error'.tr;
            break;
          default:
            title = titleKey;
        }

        switch (messageKey) {
          case 'errorWidgetIdMissing':
            message = 'screens_errorWidgetIdMissing'.tr;
            break;
          case 'errorHabitIdRequired':
            message = 'screens_errorHabitIdRequired'.tr;
            break;
          case 'errorHabitsPluginNotFound':
            message = 'screens_errorHabitsPluginNotFound'.tr;
            break;
          case 'errorHabitNotFound':
            message = 'screens_errorHabitNotFound'.trParams({
              'id': messageParam ?? '',
            });
            break;
          default:
            message = messageKey;
        }

        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(child: Text(message)),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
      transitionDuration: const Duration(milliseconds: 0),
      reverseTransitionDuration: const Duration(milliseconds: 0),
    );
  }

  /// 解析 int 参数
  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 解析 String 参数
  static String? parseString(dynamic value) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return null;
  }

  /// 解析 bool 参数
  static bool? parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }
}
