import 'dart:async';

import 'package:flutter/services.dart';

/// iOS 有限后台执行时间的轻量封装。
///
/// 每个 taskId 对应一个独立的 UIApplication background task。系统过期后
/// 会先释放原生任务，再通过 [addExpirationListener] 通知 Dart；过期通知只
/// 适合尽力保存 checkpoint，不能承诺任务恢复或无限续期。
class FiniteBackgroundTask {
  FiniteBackgroundTask._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final FiniteBackgroundTask instance = FiniteBackgroundTask._();

  static const String _channelName =
      'aboutme_foreground_service/background_task';
  static const String beginMethod = 'beginBackgroundTask';
  static const String endMethod = 'endBackgroundTask';
  static const String expirationMethod = 'backgroundTaskExpired';

  final MethodChannel _channel = const MethodChannel(_channelName);
  final Set<void Function(String taskId)> _expirationListeners = {};

  /// 请求一个由 [taskId] 标识的有限后台执行时间。
  ///
  /// 重复 begin 同一个 taskId 是幂等的；返回 false 表示系统未能创建任务
  /// 或通道调用失败。Android、桌面和 Web 返回 false。
  Future<bool> begin(String taskId) async {
    _validateTaskId(taskId);
    try {
      final result = await _channel.invokeMethod<bool>(beginMethod, taskId);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 释放 [taskId] 对应的原生有限后台任务。重复 end 是幂等的。
  Future<void> end(String taskId) async {
    _validateTaskId(taskId);
    try {
      await _channel.invokeMethod<void>(endMethod, taskId);
    } on MissingPluginException {
      // 非 iOS 平台没有对应实现。
    } on PlatformException {
      // 释放路径保持幂等，不让原生清理错误覆盖业务结果。
    }
  }

  /// 注册后台时间过期监听器。可同时注册多个控制器监听器。
  void addExpirationListener(void Function(String taskId) listener) {
    _expirationListeners.add(listener);
  }

  /// 移除后台时间过期监听器。
  void removeExpirationListener(void Function(String taskId) listener) {
    _expirationListeners.remove(listener);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != expirationMethod || call.arguments is! String) return;
    final taskId = call.arguments as String;
    for (final listener in List<void Function(String)>.of(
      _expirationListeners,
    )) {
      try {
        listener(taskId);
      } catch (_) {
        // 单个控制器的 checkpoint 失败不应阻断其他控制器收到过期通知。
      }
    }
  }

  static void _validateTaskId(String taskId) {
    if (taskId.trim().isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', '不能为空');
    }
  }
}
