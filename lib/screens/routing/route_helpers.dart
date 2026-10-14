import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_platform/universal_platform.dart';

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
